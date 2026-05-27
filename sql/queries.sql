-- =====================================================
-- queries.sql
-- Requetes d'analyse marketing + vue RFM + fonction de segmentation
-- A executer apres schema.sql
-- =====================================================

USE marketing_db;


-- =====================================================
-- Requete 0 : Commandes livrees > 50 EUR, triees par date DESC
-- Filtrage simple sur statut et montant
-- =====================================================
SELECT
    c.commande_id,
    c.client_id,
    cl.nom,
    cl.prenom,
    c.date_commande,
    c.montant_total,
    c.statut
FROM commandes c
JOIN clients cl ON cl.client_id = c.client_id
WHERE c.statut = 'livre'
  AND c.montant_total > 50
ORDER BY c.date_commande DESC;


-- =====================================================
-- Requete 1 : Top 10 clients par chiffre d'affaires total
-- GROUP BY + ORDER BY + LIMIT
-- =====================================================
SELECT
    cl.client_id,
    cl.nom,
    cl.prenom,
    cl.ville,
    COUNT(c.commande_id)        AS nb_commandes,
    SUM(c.montant_total)        AS ca_total
FROM clients cl
JOIN commandes c ON c.client_id = cl.client_id
WHERE c.statut <> 'annule'                              -- on exclut les commandes annulees du CA
GROUP BY cl.client_id, cl.nom, cl.prenom, cl.ville
ORDER BY ca_total DESC
LIMIT 10;


-- =====================================================
-- Requete 2 : Clients avec plus de 3 commandes + panier moyen
-- GROUP BY + HAVING
-- =====================================================
SELECT
    cl.client_id,
    cl.nom,
    cl.prenom,
    COUNT(c.commande_id)            AS nb_commandes,
    ROUND(AVG(c.montant_total), 2)  AS panier_moyen,
    SUM(c.montant_total)            AS ca_total
FROM clients cl
JOIN commandes c ON c.client_id = cl.client_id
WHERE c.statut <> 'annule'
GROUP BY cl.client_id, cl.nom, cl.prenom
HAVING COUNT(c.commande_id) > 3
ORDER BY panier_moyen DESC;


-- =====================================================
-- Requete 3 : Produits achetes par ville (jointure multi-tables)
-- clients + commandes + lignes_commande + produits
-- =====================================================
SELECT
    cl.ville,
    p.nom                                       AS produit,
    cat.nom                                     AS categorie,
    SUM(lc.quantite)                            AS unites_vendues,
    SUM(lc.quantite * lc.prix_unitaire)         AS ca_par_produit
FROM clients cl
JOIN commandes c        ON c.client_id   = cl.client_id
JOIN lignes_commande lc ON lc.commande_id = c.commande_id
JOIN produits p         ON p.produit_id  = lc.produit_id
JOIN categories cat     ON cat.categorie_id = p.categorie_id
WHERE c.statut <> 'annule'
GROUP BY cl.ville, p.produit_id, p.nom, cat.nom
ORDER BY cl.ville, ca_par_produit DESC;


-- =====================================================
-- Requete 4 : Scoring RFM via CTE
-- Recency (jours depuis derniere commande), Frequency (nb commandes), Monetary (CA)
-- =====================================================
WITH rfm AS (
    SELECT
        cl.client_id,
        cl.nom,
        cl.prenom,
        cl.email,
        DATEDIFF(CURDATE(), MAX(c.date_commande)) AS recence,
        COUNT(c.commande_id)                       AS frequence,
        COALESCE(SUM(c.montant_total), 0)          AS monetaire
    FROM clients cl
    LEFT JOIN commandes c
           ON c.client_id = cl.client_id
          AND c.statut <> 'annule'
    GROUP BY cl.client_id, cl.nom, cl.prenom, cl.email
)
SELECT
    client_id,
    nom,
    prenom,
    email,
    recence,
    frequence,
    monetaire
FROM rfm
ORDER BY monetaire DESC;


-- =====================================================
-- Requete 5 : Clients dont le CA est superieur a la moyenne (sous-requete)
-- =====================================================
SELECT
    cl.client_id,
    cl.nom,
    cl.prenom,
    cl.ville,
    SUM(c.montant_total) AS ca_client
FROM clients cl
JOIN commandes c ON c.client_id = cl.client_id
WHERE c.statut <> 'annule'
GROUP BY cl.client_id, cl.nom, cl.prenom, cl.ville
HAVING SUM(c.montant_total) > (
    SELECT AVG(ca_par_client)
    FROM (
        SELECT SUM(montant_total) AS ca_par_client
        FROM commandes
        WHERE statut <> 'annule'
        GROUP BY client_id
    ) AS sub
)
ORDER BY ca_client DESC;


-- =====================================================
-- FONCTION : get_segment_rfm(score)
-- Mappe un score RFM total (3..15) a un libelle de segment
-- =====================================================
DROP FUNCTION IF EXISTS get_segment_rfm;

DELIMITER $$

CREATE FUNCTION get_segment_rfm(score INT)
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE segment VARCHAR(50);
    IF score >= 13 THEN
        SET segment = 'Champions';
    ELSEIF score >= 10 THEN
        SET segment = 'Loyaux';
    ELSEIF score >= 7 THEN
        SET segment = 'Potentiels';
    ELSEIF score >= 5 THEN
        SET segment = 'A risque';
    ELSE
        SET segment = 'Inactifs';
    END IF;
    RETURN segment;
END$$

DELIMITER ;


-- =====================================================
-- VUE : v_rfm_clients
-- Scoring RFM en quintiles (NTILE) + segment via la fonction
-- =====================================================
DROP VIEW IF EXISTS v_rfm_clients;

CREATE VIEW v_rfm_clients AS
WITH rfm_brut AS (
    SELECT
        cl.client_id,
        cl.nom,
        cl.prenom,
        cl.email,
        cl.ville,
        DATEDIFF(CURDATE(), MAX(c.date_commande)) AS recence,
        COUNT(c.commande_id)                       AS frequence,
        COALESCE(SUM(c.montant_total), 0)          AS monetaire
    FROM clients cl
    JOIN commandes c
      ON c.client_id = cl.client_id
     AND c.statut <> 'annule'
    GROUP BY cl.client_id, cl.nom, cl.prenom, cl.email, cl.ville
),
rfm_scores AS (
    SELECT
        client_id, nom, prenom, email, ville,
        recence, frequence, monetaire,
        -- Recency : plus c'est petit, mieux c'est -> inversion via (6 - NTILE)
        (6 - NTILE(5) OVER (ORDER BY recence ASC))   AS R,
        NTILE(5) OVER (ORDER BY frequence ASC)        AS F,
        NTILE(5) OVER (ORDER BY monetaire ASC)        AS M
    FROM rfm_brut
)
SELECT
    client_id,
    nom,
    prenom,
    email,
    ville,
    recence,
    frequence,
    monetaire,
    R, F, M,
    (R + F + M)                       AS score_rfm,
    get_segment_rfm(R + F + M)        AS segment
FROM rfm_scores;


-- =====================================================
-- Exemples d'utilisation de la vue
-- =====================================================
-- SELECT * FROM v_rfm_clients ORDER BY score_rfm DESC;
-- SELECT segment, COUNT(*) AS nb_clients FROM v_rfm_clients GROUP BY segment;
