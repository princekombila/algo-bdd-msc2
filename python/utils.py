"""
utils.py
Fonctions utilitaires partagees (logging, dates, validations, ...).
"""

# import logging
# from datetime import datetime


# def setup_logger(name="marketing", level=logging.INFO):
#     """Configure un logger basique."""
#     logger = logging.getLogger(name)
#     logger.setLevel(level)
#     if not logger.handlers:
#         handler = logging.StreamHandler()
#         handler.setFormatter(logging.Formatter(
#             "%(asctime)s [%(levelname)s] %(name)s - %(message)s"
#         ))
#         logger.addHandler(handler)
#     return logger


# def parse_date(value, fmt="%Y-%m-%d"):
#     """Parse une chaine de date en datetime, retourne None si invalide."""
#     try:
#         return datetime.strptime(value, fmt)
#     except (TypeError, ValueError):
#         return None


# def safe_divide(a, b):
#     """Division robuste : retourne 0 si denominateur nul."""
#     return a / b if b else 0
