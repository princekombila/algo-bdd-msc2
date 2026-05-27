# algo-bdd-projet

Projet data marketing : base de donnees MySQL, pipeline Python d'enrichissement et de scoring RFM, dashboard Plotly Dash.

## Stack

- **MySQL** : stockage relationnel des donnees marketing.
- **Python 3.10+** : pipeline ETL et algorithme RFM.
- **Plotly Dash** : dashboard interactif.

## Installation

```bash
# 1. Cloner le repo puis se placer dans le dossier
cd algo-bdd-projet

# 2. Creer et activer un environnement virtuel
python -m venv venv
# Windows
venv\Scripts\activate
# macOS / Linux
source venv/bin/activate

# 3. Installer les dependances
pip install -r requirements.txt

# 4. Copier le modele d'environnement et le completer
cp .env.example .env
# Editer .env avec les vraies valeurs (DB_PASSWORD, API_KEY, ...)
```

## Base de donnees

```bash
# Creer le schema
mysql -u root -p marketing_db < sql/schema.sql

# Executer les requetes d'analyse
mysql -u root -p marketing_db < sql/queries.sql
```

## Pipeline

```bash
python python/pipeline.py
```

## Dashboard

```bash
python dashboard/app.py
# Ouvre http://127.0.0.1:8050
```

## Structure

```
algo-bdd-projet/
├── .env                    # secrets (non commite)
├── .env.example            # modele
├── .gitignore
├── CLAUDE.md
├── README.md
├── requirements.txt
├── sql/
│   ├── schema.sql
│   └── queries.sql
├── python/
│   ├── connect_db.py
│   ├── pipeline.py
│   └── utils.py
└── dashboard/
    └── app.py
```
