# CLAUDE.md

## Contexte projet

Projet data marketing combinant MySQL, Python et un dashboard Plotly Dash.

## Objectifs

- Modéliser une base de données marketing (clients, commandes, produits, campagnes).
- Enrichir les donnees via un pipeline Python.
- Implementer un algorithme de segmentation RFM (Recency, Frequency, Monetary).
- Visualiser les resultats dans un dashboard interactif.

## Arborescence

- `sql/schema.sql` : CREATE TABLE + contraintes.
- `sql/queries.sql` : requetes SELECT (5+).
- `python/connect_db.py` : connexion MySQL.
- `python/pipeline.py` : enrichissement + algorithme RFM.
- `python/utils.py` : fonctions utilitaires.
- `dashboard/app.py` : dashboard Plotly Dash.

## Conventions

- Variables sensibles : `.env` (jamais commite). Modele dans `.env.example`.
- Dependances Python : `requirements.txt`.
- Style : PEP 8, fonctions courtes, docstrings sur les fonctions publiques.

## Workflow

1. Charger les variables d'environnement depuis `.env`.
2. Se connecter a MySQL via `connect_db.py`.
3. Executer le pipeline d'enrichissement et de scoring RFM.
4. Lancer le dashboard pour explorer les segments.
