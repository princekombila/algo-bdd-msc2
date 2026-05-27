"""
app.py
Dashboard Plotly Dash : visualisation des segments RFM et indicateurs marketing.

Lancement :
    python dashboard/app.py
    -> http://127.0.0.1:8050
"""

import os
import sys
from pathlib import Path

import dash
import pandas as pd
import plotly.express as px
from dash import Input, Output, dcc, html
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError

# Rendre le module python/ importable (connect_db, etc.) si besoin
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR / "python"))

# Charge le .env de la racine du projet (fallback sur les valeurs XAMPP par defaut)
load_dotenv(dotenv_path=ROOT_DIR / ".env")

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "marketing_db")


def get_engine():
    """Cree un engine SQLAlchemy pour MariaDB/MySQL (XAMPP)."""
    url = (
        f"mysql+mysqlconnector://{DB_USER}:{DB_PASSWORD}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
    )
    return create_engine(url, pool_pre_ping=True)


def load_data():
    """
    Charge les scores RFM depuis MySQL.
    Si la table n'existe pas encore, renvoie un DataFrame vide avec les bonnes colonnes
    pour que le dashboard demarre quand meme (utile au premier lancement).
    """
    cols = ["client_id", "recency", "frequency", "monetary",
            "R", "F", "M", "rfm_score", "segment", "snapshot_date"]
    try:
        engine = get_engine()
        query = """
            SELECT client_id, recency, frequency, monetary,
                   R, F, M, rfm_score, segment, snapshot_date
            FROM rfm_results
        """
        df = pd.read_sql(query, engine)
    except SQLAlchemyError as exc:
        print(f"[app] Impossible de charger rfm_results : {exc}")
        return pd.DataFrame(columns=cols)

    if df.empty:
        return pd.DataFrame(columns=cols)

    df["snapshot_date"] = pd.to_datetime(df["snapshot_date"])
    df["monetary"] = df["monetary"].astype(float)
    return df


DATA = load_data()

app = dash.Dash(__name__)
app.title = "Dashboard Marketing RFM"

segments = sorted(DATA["segment"].dropna().unique().tolist()) if not DATA.empty else []

app.layout = html.Div(
    style={"fontFamily": "Arial, sans-serif", "padding": "20px"},
    children=[
        html.H1("Dashboard Marketing - Segmentation RFM"),
        html.P(
            f"Source : {DB_NAME}@{DB_HOST}:{DB_PORT} - "
            f"{len(DATA)} clients charges."
        ),
        html.Div(
            style={"maxWidth": "400px", "marginBottom": "20px"},
            children=[
                html.Label("Filtrer par segment :"),
                dcc.Dropdown(
                    id="segment-filter",
                    options=[{"label": s, "value": s} for s in segments],
                    value=segments,
                    multi=True,
                ),
            ],
        ),
        dcc.Graph(id="rfm-scatter"),
        dcc.Graph(id="segment-bar"),
        dcc.Graph(id="monetary-hist"),
    ],
)


@app.callback(
    Output("rfm-scatter", "figure"),
    Output("segment-bar", "figure"),
    Output("monetary-hist", "figure"),
    Input("segment-filter", "value"),
)
def update_charts(selected_segments):
    df = DATA.copy()
    if selected_segments:
        df = df[df["segment"].isin(selected_segments)]

    if df.empty:
        empty = px.scatter(title="Aucune donnee a afficher")
        return empty, empty, empty

    fig_scatter = px.scatter(
        df,
        x="recency",
        y="monetary",
        color="segment",
        size="frequency",
        hover_data=["client_id", "rfm_score"],
        title="Recence vs Montant (taille = frequence)",
    )

    seg_counts = (
        df.groupby("segment").size().reset_index(name="clients").sort_values("clients")
    )
    fig_bar = px.bar(
        seg_counts,
        x="segment",
        y="clients",
        color="segment",
        title="Nombre de clients par segment",
    )

    fig_hist = px.histogram(
        df,
        x="monetary",
        color="segment",
        nbins=30,
        title="Distribution du chiffre d'affaires par client",
    )

    return fig_scatter, fig_bar, fig_hist


if __name__ == "__main__":
    app.run(debug=True)
