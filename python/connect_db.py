"""
connect_db.py
Connexion a la base MySQL marketing_db (MariaDB / XAMPP).
Les credentials sont charges depuis le fichier .env.
"""

import os
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv
from mysql.connector import Error

# Chargement des variables d'environnement (.env a la racine du projet)
ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(dotenv_path=ENV_PATH)


def get_connection():
    """
    Retourne une connexion MySQL active a partir des variables .env.

    Variables attendues :
        DB_HOST, DB_USER, DB_PASSWORD, DB_NAME
    """
    try:
        conn = mysql.connector.connect(
            host=os.getenv("DB_HOST", "localhost"),
            user=os.getenv("DB_USER", "root"),
            password=os.getenv("DB_PASSWORD", ""),
            database=os.getenv("DB_NAME", "marketing_db"),
            port=int(os.getenv("DB_PORT", "3306")),
            charset="utf8mb4",
            use_unicode=True,
        )
        if conn.is_connected():
            return conn
        raise Error("La connexion n'est pas active.")
    except Error as e:
        print(f"[connect_db] Erreur de connexion : {e}")
        raise


def close_connection(conn):
    """Ferme proprement la connexion MySQL si elle est encore ouverte."""
    if conn is not None and conn.is_connected():
        conn.close()


def test_connection():
    """Petit utilitaire de diagnostic : affiche la version du serveur."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT VERSION();")
        version = cursor.fetchone()
        print(f"Connexion OK - MySQL/MariaDB version : {version[0]}")
        cursor.close()
    finally:
        close_connection(conn)


if __name__ == "__main__":
    test_connection()
