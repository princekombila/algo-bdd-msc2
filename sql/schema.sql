-- =====================================================
-- schema.sql
-- Boutique e-commerce cosmetiques : schema + jeu de donnees
-- 5 tables : clients, categories, produits, commandes, lignes_commande
-- =====================================================

/*!40101 SET NAMES utf8mb4 */;

-- ---------- Creation de la base ----------
CREATE DATABASE IF NOT EXISTS marketing_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE marketing_db;

-- ---------- Reset (ordre inverse a cause des FK) ----------
DROP TABLE IF EXISTS lignes_commande;
DROP TABLE IF EXISTS commandes;
DROP TABLE IF EXISTS produits;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS clients;


-- =====================================================
-- 1. TABLE clients
-- =====================================================
CREATE TABLE clients (
  client_id        INT AUTO_INCREMENT PRIMARY KEY,
  nom              VARCHAR(50)  NOT NULL,
  prenom           VARCHAR(50)  NOT NULL,
  email            VARCHAR(100) NOT NULL UNIQUE,           -- contrainte unique sur l'email
  telephone        VARCHAR(20),
  ville            VARCHAR(50)  NOT NULL,
  code_postal      VARCHAR(10),
  date_inscription DATE         NOT NULL,
  INDEX idx_clients_ville (ville)
) ENGINE=InnoDB;


-- =====================================================
-- 2. TABLE categories
-- =====================================================
CREATE TABLE categories (
  categorie_id INT AUTO_INCREMENT PRIMARY KEY,
  nom          VARCHAR(50) NOT NULL UNIQUE,
  description  VARCHAR(255)
) ENGINE=InnoDB;


-- =====================================================
-- 3. TABLE produits
-- =====================================================
CREATE TABLE produits (
  produit_id   INT AUTO_INCREMENT PRIMARY KEY,
  nom          VARCHAR(100)  NOT NULL,
  categorie_id INT           NOT NULL,
  prix         DECIMAL(10,2) NOT NULL CHECK (prix >= 0),
  stock        INT           NOT NULL DEFAULT 0 CHECK (stock >= 0),
  marque       VARCHAR(50),
  CONSTRAINT fk_produits_categorie
    FOREIGN KEY (categorie_id) REFERENCES categories(categorie_id),
  INDEX idx_produits_categorie (categorie_id)
) ENGINE=InnoDB;


-- =====================================================
-- 4. TABLE commandes
-- =====================================================
CREATE TABLE commandes (
  commande_id    INT AUTO_INCREMENT PRIMARY KEY,
  client_id      INT          NOT NULL,
  date_commande  DATE         NOT NULL,
  montant_total  DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (montant_total >= 0),
  statut         ENUM('en_attente','expedie','livre','annule') NOT NULL DEFAULT 'en_attente',
  CONSTRAINT fk_commandes_client
    FOREIGN KEY (client_id) REFERENCES clients(client_id),
  INDEX idx_commandes_client (client_id),
  INDEX idx_commandes_date   (date_commande),
  INDEX idx_commandes_statut (statut)
) ENGINE=InnoDB;


-- =====================================================
-- 5. TABLE lignes_commande (table de liaison N-N)
-- =====================================================
CREATE TABLE lignes_commande (
  ligne_id      INT AUTO_INCREMENT PRIMARY KEY,
  commande_id   INT NOT NULL,
  produit_id    INT NOT NULL,
  quantite      INT NOT NULL CHECK (quantite > 0),
  prix_unitaire DECIMAL(10,2) NOT NULL CHECK (prix_unitaire >= 0),
  CONSTRAINT fk_lignes_commande
    FOREIGN KEY (commande_id) REFERENCES commandes(commande_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_lignes_produit
    FOREIGN KEY (produit_id) REFERENCES produits(produit_id),
  INDEX idx_lignes_commande (commande_id),
  INDEX idx_lignes_produit  (produit_id)
) ENGINE=InnoDB;


-- =====================================================
-- JEU DE DONNEES
-- =====================================================

-- ---------- Categories (6) ----------
INSERT INTO categories (nom, description) VALUES
  ('Maquillage',     'Produits de maquillage du visage et des yeux'),
  ('Soin du visage', 'Cremes, serums et soins du visage'),
  ('Soin du corps',  'Hydratation et exfoliation du corps'),
  ('Parfum',         'Eaux de toilette, eaux de parfum, brumes'),
  ('Cheveux',        'Shampooings, masques et soins capillaires'),
  ('Bio Naturel',    'Cosmetiques bio et naturels');


-- ---------- Produits (20) ----------
INSERT INTO produits (nom, categorie_id, prix, stock, marque) VALUES
  ('Rouge a levres mat',           1, 18.90, 120, 'GlamLine'),
  ('Mascara volume',               1, 22.50,  95, 'GlamLine'),
  ('Fond de teint fluide',         1, 29.90,  80, 'PureSkin'),
  ('Palette fards a paupieres',    1, 39.90,  60, 'GlamLine'),
  ('Creme hydratante visage',      2, 34.50, 150, 'PureSkin'),
  ('Serum vitamine C',             2, 45.00,  70, 'DermaCare'),
  ('Masque purifiant',             2, 24.90, 100, 'PureSkin'),
  ('Contour des yeux',             2, 38.00,  85, 'DermaCare'),
  ('Gel douche bio',               3, 12.50, 200, 'NatureBio'),
  ('Lait corps hydratant',         3, 19.90, 130, 'PureSkin'),
  ('Gommage exfoliant',            3, 16.50, 110, 'NatureBio'),
  ('Huile seche parfumee',         3, 28.00,  75, 'GlamLine'),
  ('Parfum Eau de toilette',       4, 55.00,  50, 'AromaParis'),
  ('Parfum Eau de parfum',         4, 89.00,  40, 'AromaParis'),
  ('Brume parfumee',               4, 24.90,  90, 'AromaParis'),
  ('Shampooing nourrissant',       5, 14.90, 160, 'HairLab'),
  ('Apres-shampooing',             5, 13.90, 155, 'HairLab'),
  ('Masque capillaire',            5, 21.00,  80, 'HairLab'),
  ('Huile cheveux',                5, 26.50,  65, 'HairLab'),
  ('Creme solaire bio',            6, 32.00, 100, 'NatureBio');


-- ---------- Clients (30) ----------
INSERT INTO clients (nom, prenom, email, telephone, ville, code_postal, date_inscription) VALUES
  ('Dupont',   'Marie',   'marie.dupont@email.com',     '0612345678', 'Paris',       '75001', '2024-03-15'),
  ('Martin',   'Jean',    'jean.martin@email.com',      '0623456789', 'Lyon',        '69001', '2024-05-22'),
  ('Bernard',  'Sophie',  'sophie.bernard@email.com',   '0634567890', 'Marseille',   '13001', '2024-01-10'),
  ('Petit',    'Pierre',  'pierre.petit@email.com',     '0645678901', 'Toulouse',    '31000', '2024-07-08'),
  ('Robert',   'Camille', 'camille.robert@email.com',   '0656789012', 'Bordeaux',    '33000', '2024-02-28'),
  ('Richard',  'Lucas',   'lucas.richard@email.com',    '0667890123', 'Nantes',      '44000', '2024-09-12'),
  ('Durand',   'Emma',    'emma.durand@email.com',      '0678901234', 'Strasbourg',  '67000', '2024-06-04'),
  ('Dubois',   'Lea',     'lea.dubois@email.com',       '0689012345', 'Nice',        '06000', '2024-04-19'),
  ('Moreau',   'Hugo',    'hugo.moreau@email.com',      '0690123456', 'Lille',       '59000', '2024-08-25'),
  ('Laurent',  'Chloe',   'chloe.laurent@email.com',    '0611223344', 'Rennes',      '35000', '2024-10-03'),
  ('Simon',    'Louis',   'louis.simon@email.com',      '0622334455', 'Montpellier', '34000', '2024-11-17'),
  ('Michel',   'Sarah',   'sarah.michel@email.com',     '0633445566', 'Grenoble',    '38000', '2025-01-22'),
  ('Lefebvre', 'Nathan',  'nathan.lefebvre@email.com',  '0644556677', 'Paris',       '75011', '2025-02-14'),
  ('Leroy',    'Alice',   'alice.leroy@email.com',      '0655667788', 'Lyon',        '69003', '2025-03-08'),
  ('Roux',     'Theo',    'theo.roux@email.com',        '0666778899', 'Marseille',   '13008', '2024-12-19'),
  ('David',    'Jade',    'jade.david@email.com',       '0677889900', 'Toulouse',    '31200', '2025-04-25'),
  ('Bertrand', 'Leo',     'leo.bertrand@email.com',     '0688990011', 'Bordeaux',    '33200', '2024-11-30'),
  ('Morel',    'Manon',   'manon.morel@email.com',      '0699001122', 'Nantes',      '44100', '2025-05-16'),
  ('Fournier', 'Tom',     'tom.fournier@email.com',     '0610111213', 'Strasbourg',  '67100', '2024-09-28'),
  ('Girard',   'Lola',    'lola.girard@email.com',      '0621222324', 'Nice',        '06200', '2025-01-09'),
  ('Bonnet',   'Maxime',  'maxime.bonnet@email.com',    '0632333435', 'Lille',       '59800', '2025-02-21'),
  ('Dupuis',   'Clara',   'clara.dupuis@email.com',     '0643444546', 'Rennes',      '35200', '2025-06-04'),
  ('Lambert',  'Adam',    'adam.lambert@email.com',     '0654555657', 'Montpellier', '34080', '2024-10-15'),
  ('Fontaine', 'Ines',    'ines.fontaine@email.com',    '0665666768', 'Grenoble',    '38100', '2025-07-12'),
  ('Rousseau', 'Gabriel', 'gabriel.rousseau@email.com', '0676777879', 'Paris',       '75015', '2024-08-08'),
  ('Vincent',  'Eva',     'eva.vincent@email.com',      '0687888990', 'Lyon',        '69007', '2025-03-30'),
  ('Muller',   'Raphael', 'raphael.muller@email.com',   '0698999001', 'Marseille',   '13002', '2024-12-02'),
  ('Lefevre',  'Mila',    'mila.lefevre@email.com',     '0619000112', 'Toulouse',    '31100', '2025-08-20'),
  ('Faure',    'Sacha',   'sacha.faure@email.com',      '0620111223', 'Bordeaux',    '33800', '2024-07-18'),
  ('Andre',    'Romane',  'romane.andre@email.com',     '0631222334', 'Nantes',      '44200', '2025-09-05');


-- ---------- Commandes (50) ----------
-- montant_total est mis a 0 puis recalcule via UPDATE en fin de script
INSERT INTO commandes (commande_id, client_id, date_commande, montant_total, statut) VALUES
  ( 1,  1, '2026-05-20', 0, 'expedie'),
  ( 2,  1, '2026-04-15', 0, 'livre'),
  ( 3,  1, '2026-03-08', 0, 'livre'),
  ( 4,  1, '2026-02-12', 0, 'livre'),
  ( 5,  2, '2026-05-22', 0, 'expedie'),
  ( 6,  2, '2026-05-01', 0, 'livre'),
  ( 7,  2, '2026-04-10', 0, 'livre'),
  ( 8,  2, '2026-03-20', 0, 'livre'),
  ( 9,  2, '2026-02-05', 0, 'livre'),
  (10,  3, '2026-05-15', 0, 'en_attente'),
  (11,  3, '2026-04-22', 0, 'livre'),
  (12,  3, '2026-03-10', 0, 'expedie'),
  (13,  3, '2026-02-18', 0, 'livre'),
  (14,  4, '2026-05-25', 0, 'en_attente'),
  (15,  4, '2026-03-12', 0, 'livre'),
  (16,  4, '2025-12-08', 0, 'livre'),
  (17,  5, '2026-05-18', 0, 'en_attente'),
  (18,  5, '2026-02-22', 0, 'livre'),
  (19,  5, '2025-11-15', 0, 'livre'),
  (20,  6, '2026-05-10', 0, 'expedie'),
  (21,  6, '2026-03-25', 0, 'livre'),
  (22,  6, '2025-10-20', 0, 'livre'),
  (23,  7, '2026-04-30', 0, 'livre'),
  (24,  7, '2026-01-15', 0, 'livre'),
  (25,  7, '2025-09-10', 0, 'livre'),
  (26,  8, '2026-05-05', 0, 'expedie'),
  (27,  8, '2026-02-28', 0, 'livre'),
  (28,  8, '2025-08-22', 0, 'livre'),
  (29,  9, '2026-04-18', 0, 'livre'),
  (30,  9, '2025-07-15', 0, 'annule'),
  (31, 10, '2026-03-05', 0, 'livre'),
  (32, 10, '2025-09-25', 0, 'livre'),
  (33, 11, '2026-04-02', 0, 'livre'),
  (34, 11, '2025-12-15', 0, 'livre'),
  (35, 12, '2026-05-12', 0, 'en_attente'),
  (36, 12, '2025-11-05', 0, 'livre'),
  (37, 13, '2026-03-18', 0, 'livre'),
  (38, 13, '2025-08-08', 0, 'livre'),
  (39, 14, '2026-04-25', 0, 'expedie'),
  (40, 14, '2025-10-30', 0, 'livre'),
  (41, 15, '2026-02-15', 0, 'livre'),
  (42, 15, '2025-07-22', 0, 'annule'),
  (43, 16, '2026-04-08', 0, 'expedie'),
  (44, 17, '2025-11-20', 0, 'livre'),
  (45, 18, '2026-01-25', 0, 'livre'),
  (46, 19, '2025-08-15', 0, 'expedie'),
  (47, 20, '2025-06-12', 0, 'livre'),
  (48, 21, '2025-07-08', 0, 'livre'),
  (49, 22, '2026-03-30', 0, 'expedie'),
  (50, 23, '2025-09-18', 0, 'livre');


-- ---------- Lignes de commande ----------
-- (commande_id, produit_id, quantite, prix_unitaire)
INSERT INTO lignes_commande (commande_id, produit_id, quantite, prix_unitaire) VALUES
  -- Commande 1 : Marie Dupont
  ( 1,  1, 1, 18.90),
  ( 1,  5, 1, 34.50),
  ( 1,  9, 2, 12.50),
  -- Commande 2
  ( 2,  6, 1, 45.00),
  ( 2, 13, 1, 55.00),
  -- Commande 3
  ( 3,  2, 1, 22.50),
  ( 3, 16, 1, 14.90),
  ( 3, 17, 1, 13.90),
  -- Commande 4
  ( 4,  4, 1, 39.90),
  ( 4,  8, 1, 38.00),
  -- Commande 5 : Jean Martin
  ( 5, 14, 1, 89.00),
  -- Commande 6
  ( 6,  3, 1, 29.90),
  ( 6,  7, 1, 24.90),
  -- Commande 7
  ( 7, 10, 2, 19.90),
  ( 7, 11, 1, 16.50),
  -- Commande 8
  ( 8, 13, 1, 55.00),
  ( 8, 15, 1, 24.90),
  -- Commande 9
  ( 9,  5, 1, 34.50),
  ( 9,  6, 1, 45.00),
  -- Commande 10 : Sophie Bernard
  (10,  4, 1, 39.90),
  -- Commande 11
  (11,  1, 2, 18.90),
  (11,  2, 1, 22.50),
  -- Commande 12
  (12, 18, 1, 21.00),
  (12, 19, 1, 26.50),
  -- Commande 13
  (13, 14, 1, 89.00),
  (13, 20, 1, 32.00),
  -- Commande 14 : Pierre Petit
  (14, 13, 1, 55.00),
  (14, 14, 1, 89.00),
  -- Commande 15
  (15,  7, 1, 24.90),
  (15, 10, 1, 19.90),
  -- Commande 16
  (16,  3, 1, 29.90),
  -- Commande 17 : Camille Robert
  (17,  4, 1, 39.90),
  (17, 11, 1, 16.50),
  -- Commande 18
  (18,  6, 1, 45.00),
  (18,  8, 1, 38.00),
  -- Commande 19
  (19, 12, 1, 28.00),
  (19, 16, 1, 14.90),
  -- Commande 20 : Lucas Richard
  (20,  1, 1, 18.90),
  (20,  5, 1, 34.50),
  -- Commande 21
  (21,  9, 2, 12.50),
  (21, 17, 1, 13.90),
  -- Commande 22
  (22, 14, 1, 89.00),
  -- Commande 23 : Emma Durand
  (23,  2, 1, 22.50),
  (23,  7, 1, 24.90),
  -- Commande 24
  (24,  4, 1, 39.90),
  (24, 20, 1, 32.00),
  -- Commande 25
  (25, 13, 1, 55.00),
  -- Commande 26 : Lea Dubois
  (26,  5, 1, 34.50),
  (26,  6, 1, 45.00),
  (26, 11, 1, 16.50),
  -- Commande 27
  (27, 18, 1, 21.00),
  (27, 19, 1, 26.50),
  -- Commande 28
  (28, 14, 1, 89.00),
  -- Commande 29 : Hugo Moreau
  (29,  1, 1, 18.90),
  (29,  3, 1, 29.90),
  -- Commande 30 (annulee)
  (30,  4, 1, 39.90),
  -- Commande 31 : Chloe Laurent
  (31, 16, 1, 14.90),
  (31, 17, 1, 13.90),
  (31, 18, 1, 21.00),
  -- Commande 32
  (32,  8, 1, 38.00),
  -- Commande 33 : Louis Simon
  (33,  5, 1, 34.50),
  (33,  9, 1, 12.50),
  -- Commande 34
  (34, 13, 1, 55.00),
  -- Commande 35 : Sarah Michel
  (35,  2, 1, 22.50),
  (35,  4, 1, 39.90),
  -- Commande 36
  (36, 10, 1, 19.90),
  (36, 11, 1, 16.50),
  -- Commande 37 : Nathan Lefebvre
  (37,  6, 1, 45.00),
  (37,  8, 1, 38.00),
  -- Commande 38
  (38, 14, 1, 89.00),
  -- Commande 39 : Alice Leroy
  (39,  1, 1, 18.90),
  (39,  2, 1, 22.50),
  (39,  7, 1, 24.90),
  -- Commande 40
  (40, 15, 1, 24.90),
  -- Commande 41 : Theo Roux
  (41,  3, 1, 29.90),
  (41, 12, 1, 28.00),
  -- Commande 42 (annulee)
  (42,  5, 1, 34.50),
  -- Commande 43 : Jade David
  (43,  4, 1, 39.90),
  -- Commande 44 : Leo Bertrand
  (44, 13, 1, 55.00),
  (44, 17, 1, 13.90),
  -- Commande 45 : Manon Morel
  (45,  6, 1, 45.00),
  -- Commande 46 : Tom Fournier
  (46,  1, 1, 18.90),
  (46,  9, 1, 12.50),
  -- Commande 47 : Lola Girard
  (47, 16, 1, 14.90),
  -- Commande 48 : Maxime Bonnet
  (48,  4, 1, 39.90),
  (48, 14, 1, 89.00),
  -- Commande 49 : Clara Dupuis
  (49,  5, 1, 34.50),
  -- Commande 50 : Adam Lambert
  (50,  8, 1, 38.00),
  (50, 11, 1, 16.50);


-- ---------- Synchronisation montant_total <-> sum(lignes) ----------
UPDATE commandes c
SET montant_total = (
  SELECT COALESCE(SUM(lc.quantite * lc.prix_unitaire), 0)
  FROM lignes_commande lc
  WHERE lc.commande_id = c.commande_id
);


-- =====================================================
-- Verifications rapides
-- =====================================================
-- SELECT COUNT(*) AS nb_clients   FROM clients;     -- 30
-- SELECT COUNT(*) AS nb_produits  FROM produits;    -- 20
-- SELECT COUNT(*) AS nb_commandes FROM commandes;   -- 50
-- SELECT COUNT(*) AS nb_lignes    FROM lignes_commande;
