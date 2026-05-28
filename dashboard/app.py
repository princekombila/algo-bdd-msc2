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
import plotly.graph_objects as go
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
if not DATA.empty:
    RECENCY_MIN = int(DATA["recency"].min())
    RECENCY_MAX = int(DATA["recency"].max())
else:
    RECENCY_MIN, RECENCY_MAX = 0, 365

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
        html.Div(
            style={"maxWidth": "600px", "marginBottom": "30px"},
            children=[
                html.Label("Filtrer par recence (jours) :"),
                dcc.RangeSlider(
                    id="recency-filter",
                    min=RECENCY_MIN,
                    max=RECENCY_MAX,
                    value=[RECENCY_MIN, RECENCY_MAX],
                    step=1,
                    marks=None,
                    tooltip={"placement": "bottom", "always_visible": True},
                ),
            ],
        ),
        dcc.Graph(id="rfm-scatter"),
        dcc.Graph(id="segment-bar"),
        dcc.Graph(id="monetary-hist"),
        dcc.Graph(id="rfm-heatmap"),
    ],
)


@app.callback(
    Output("rfm-scatter", "figure"),
    Output("segment-bar", "figure"),
    Output("monetary-hist", "figure"),
    Output("rfm-heatmap", "figure"),
    Input("segment-filter", "value"),
    Input("recency-filter", "value"),
)
def update_charts(selected_segments, recency_range):
    df = DATA.copy()
    if selected_segments:
        df = df[df["segment"].isin(selected_segments)]
    if recency_range and len(recency_range) == 2:
        r_min, r_max = recency_range
        df = df[(df["recency"] >= r_min) & (df["recency"] <= r_max)]

    if df.empty:
        empty = px.scatter(title="Aucune donnee a afficher", template="plotly_dark")
        return empty, empty, empty, empty

    fig_scatter = px.scatter(
        df,
        x="recency",
        y="monetary",
        color="segment",
        size="frequency",
        hover_data=["client_id", "rfm_score"],
        title="Recence vs Montant (taille = frequence)",
        template="plotly_dark",
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
        template="plotly_dark",
    )

    fig_hist = px.histogram(
        df,
        x="monetary",
        color="segment",
        nbins=30,
        title="Distribution du chiffre d'affaires par client",
        template="plotly_dark",
    )

    pivot = (
        df.pivot_table(index="R", columns="F", values="M", aggfunc="mean")
        .reindex(index=[1, 2, 3, 4, 5], columns=[1, 2, 3, 4, 5])
    )
    fig_heatmap = go.Figure(
        data=go.Heatmap(
            z=pivot.values,
            x=pivot.columns,
            y=pivot.index,
            colorscale="RdYlGn",
            zmin=1,
            zmax=5,
            colorbar=dict(title="Score M moyen"),
            hovertemplate="R=%{y}<br>F=%{x}<br>M moyen=%{z:.2f}<extra></extra>",
        )
    )
    fig_heatmap.update_layout(
        title="Heatmap RFM - Intensite Monetary par Score R x F",
        xaxis_title="Score F (Frequence)",
        yaxis_title="Score R (Recence)",
        xaxis=dict(dtick=1),
        yaxis=dict(dtick=1, autorange="reversed"),
        template="plotly_dark",
    )

    return fig_scatter, fig_bar, fig_hist, fig_heatmap


if __name__ == "__main__":
    app.run(debug=True)
