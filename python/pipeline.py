"""
pipeline.py
Pipeline d'enrichissement + algorithme de scoring RFM.

Etapes :
    1. Extraire les commandes / produits depuis MySQL.
    2. Enrichir les produits avec l'API Open Food Facts.
    3. Calculer les scores R, F, M (quintiles) par client.
    4. Determiner le segment client.
    5. Reinjecter le resultat dans la table rfm_results.
"""

import time
from datetime import datetime

import pandas as pd
import requests

from connect_db import close_connection, get_connection

OFF_SEARCH_URL = "https://world.openfoodfacts.org/cgi/search.pl"
OFF_TIMEOUT = 5
OFF_SLEEP = 0.2  # politesse envers l'API publique


# =====================================================
# 1. EXTRACTION
# =====================================================
def extract_orders():
    """Charge les commandes valides (non annulees) depuis MySQL."""
    conn = get_connection()
    try:
        query = """
            SELECT c.client_id,
                   c.date_commande,
                   c.montant_total,
                   c.statut
            FROM commandes c
            WHERE c.statut <> 'annule'
        """
        df = pd.read_sql(query, conn)
    finally:
        close_connection(conn)

    df["date_commande"] = pd.to_datetime(df["date_commande"])
    df["montant_total"] = df["montant_total"].astype(float)
    return df


def extract_products():
    """Charge les produits et leur categorie depuis MySQL."""
    conn = get_connection()
    try:
        query = """
            SELECT p.produit_id,
                   p.nom,
                   p.marque,
                   p.prix,
                   cat.nom AS categorie
            FROM produits p
            JOIN categories cat ON cat.categorie_id = p.categorie_id
        """
        df = pd.read_sql(query, conn)
    finally:
        close_connection(conn)
    return df


# =====================================================
# 2. ENRICHISSEMENT OPEN FOOD FACTS
# =====================================================
def fetch_off_product(query_term):
    """
    Interroge l'API Open Food Facts pour un terme donne.
    Retourne un dict {nutriscore, ecoscore, nb_produits} ou des None si introuvable.
    """
    params = {
        "search_terms": query_term,
        "search_simple": 1,
        "action": "process",
        "json": 1,
        "page_size": 1,
    }
    try:
        response = requests.get(OFF_SEARCH_URL, params=params, timeout=OFF_TIMEOUT)
        response.raise_for_status()
        data = response.json()
    except (requests.RequestException, ValueError):
        return {"off_nutriscore": None, "off_ecoscore": None, "off_count": 0}

    products = data.get("products", []) or []
    count = data.get("count", 0)
    if not products:
        return {"off_nutriscore": None, "off_ecoscore": None, "off_count": count}

    first = products[0]
    return {
        "off_nutriscore": first.get("nutriscore_grade"),
        "off_ecoscore": first.get("ecoscore_grade"),
        "off_count": count,
    }


def enrich_products(df_products):
    """
    Enrichit chaque produit avec des informations Open Food Facts.
    Le matching se fait sur le couple marque + nom du produit.
    """
    enriched_rows = []
    for _, row in df_products.iterrows():
        term = f"{row['marque']} {row['nom']}".strip()
        off_data = fetch_off_product(term)
        enriched_rows.append({**row.to_dict(), **off_data})
        time.sleep(OFF_SLEEP)

    return pd.DataFrame(enriched_rows)


# =====================================================
# 3. CALCUL RFM
# =====================================================
def label_segment(score):
    """Mappe un score RFM total (3-15) a un libelle de segment."""
    if score >= 13:
        return "Champions"
    if score >= 10:
        return "Loyaux"
    if score >= 7:
        return "Potentiels"
    if score >= 5:
        return "A risque"
    return "Inactifs"


def _safe_qcut(series, ascending=True):
    """
    Decoupe une serie en quintiles 1-5.
    ascending=True  : valeur basse -> note basse.
    ascending=False : valeur basse -> note haute (utile pour la recence).
    Robuste aux duplicates et aux petits echantillons.
    """
    labels = [1, 2, 3, 4, 5] if ascending else [5, 4, 3, 2, 1]
    try:
        return pd.qcut(series.rank(method="first"), 5, labels=labels).astype(int)
    except ValueError:
        # Trop peu de valeurs distinctes -> fallback sur un rang lineaire
        ranked = series.rank(method="first", ascending=ascending)
        n = len(series)
        bins = pd.cut(ranked, bins=min(5, n), labels=list(range(1, min(5, n) + 1)))
        return bins.astype(int)


def compute_rfm(df_orders, snapshot_date=None):
    """
    Calcule les scores RFM par client.

    R : recence (jours depuis derniere commande) - plus c'est petit, mieux c'est.
    F : frequence (nombre de commandes).
    M : montant total cumule.

    Chaque dimension est notee de 1 a 5 (quintiles).
    """
    if snapshot_date is None:
        snapshot_date = pd.Timestamp(datetime.now().date())
    else:
        snapshot_date = pd.Timestamp(snapshot_date)

    rfm = (
        df_orders.groupby("client_id")
        .agg(
            recency=("date_commande", lambda x: (snapshot_date - x.max()).days),
            frequency=("date_commande", "count"),
            monetary=("montant_total", "sum"),
        )
        .reset_index()
    )

    rfm["R"] = _safe_qcut(rfm["recency"], ascending=False)
    rfm["F"] = _safe_qcut(rfm["frequency"], ascending=True)
    rfm["M"] = _safe_qcut(rfm["monetary"], ascending=True)
    rfm["RFM_score"] = rfm["R"] + rfm["F"] + rfm["M"]
    rfm["segment"] = rfm["RFM_score"].apply(label_segment)
    rfm["snapshot_date"] = snapshot_date.date()

    return rfm


# =====================================================
# 4. ECRITURE DANS rfm_results
# =====================================================
DDL_RFM = """
CREATE TABLE IF NOT EXISTS rfm_results (
    rfm_id        INT AUTO_INCREMENT PRIMARY KEY,
    client_id     INT           NOT NULL,
    snapshot_date DATE          NOT NULL,
    recency       INT           NOT NULL,
    frequency     INT           NOT NULL,
    monetary      DECIMAL(10,2) NOT NULL,
    R             TINYINT       NOT NULL,
    F             TINYINT       NOT NULL,
    M             TINYINT       NOT NULL,
    rfm_score     TINYINT       NOT NULL,
    segment       VARCHAR(30)   NOT NULL,
    CONSTRAINT fk_rfm_client FOREIGN KEY (client_id) REFERENCES clients(client_id),
    UNIQUE KEY uq_client_snapshot (client_id, snapshot_date),
    INDEX idx_rfm_segment (segment)
) ENGINE=InnoDB;
"""

INSERT_RFM = """
INSERT INTO rfm_results
    (client_id, snapshot_date, recency, frequency, monetary, R, F, M, rfm_score, segment)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
    recency=VALUES(recency),
    frequency=VALUES(frequency),
    monetary=VALUES(monetary),
    R=VALUES(R),
    F=VALUES(F),
    M=VALUES(M),
    rfm_score=VALUES(rfm_score),
    segment=VALUES(segment);
"""


def load_rfm(df_rfm):
    """Cree la table rfm_results si besoin puis y insere/met a jour les scores."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(DDL_RFM)

        rows = [
            (
                int(r.client_id),
                r.snapshot_date,
                int(r.recency),
                int(r.frequency),
                float(r.monetary),
                int(r.R),
                int(r.F),
                int(r.M),
                int(r.RFM_score),
                r.segment,
            )
            for r in df_rfm.itertuples(index=False)
        ]
        cursor.executemany(INSERT_RFM, rows)
        conn.commit()
        print(f"[pipeline] {cursor.rowcount} lignes ecrites dans rfm_results.")
        cursor.close()
    finally:
        close_connection(conn)


# =====================================================
# 5. ORCHESTRATION
# =====================================================
def run(enrich_off=True):
    """Point d'entree du pipeline complet."""
    print("[pipeline] 1/4 - Extraction des commandes...")
    orders = extract_orders()
    print(f"           {len(orders)} commandes chargees.")

    if enrich_off:
        print("[pipeline] 2/4 - Enrichissement Open Food Facts...")
        products = extract_products()
        enriched = enrich_products(products)
        print(f"           {len(enriched)} produits enrichis "
              f"({enriched['off_nutriscore'].notna().sum()} avec nutriscore).")

    print("[pipeline] 3/4 - Calcul des scores RFM...")
    rfm = compute_rfm(orders)
    print(f"           {len(rfm)} clients notes.")
    print(rfm[["client_id", "recency", "frequency", "monetary",
               "R", "F", "M", "RFM_score", "segment"]].head(10).to_string(index=False))

    print("[pipeline] 4/4 - Ecriture en base...")
    load_rfm(rfm)
    print("[pipeline] Termine.")
    return rfm


if __name__ == "__main__":
    run()
