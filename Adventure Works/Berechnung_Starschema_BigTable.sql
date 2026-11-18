-- 1. Letztes volles Jahr finden
--    Nur Jahre mit Verkäufen in allen 12 Monaten zählen, davon das neuste
DECLARE @Jahr AS INT = (SELECT MAX(VolleJahre.Jahr)
                        FROM   (SELECT   YEAR(Verkaeufe.OrderDate) AS Jahr
                                FROM     dwh.FactInternetSales AS Verkaeufe
                                GROUP BY YEAR(Verkaeufe.OrderDate)
                                HAVING   COUNT(DISTINCT MONTH(Verkaeufe.OrderDate)) = 12) AS VolleJahre);

-- 2. Temporäre Tabelle als Ablage für die Resultate von sp_spaceused
CREATE TABLE #Speicher (
    Tabelle      NVARCHAR (128),
    Zeilen       CHAR (20)     ,
    Reserviert   VARCHAR (18)  ,
    Daten        VARCHAR (18)  ,
    Indexgroesse VARCHAR (18)  ,
    Ungenutzt    VARCHAR (18)  
);

-- 3. Jede Tabelle mit sp_spaceused messen und das Resultat in #Speicher schreiben
--    Faktentabelle des Star Schemas
INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.FactInternetSales';

--    Dimensionen des Star Schemas
INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimDate';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimProduct';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimProductSubcategory';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimProductCategory';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimCustomer';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimGeography';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimPromotion';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimCurrency';

INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.DimSalesTerritory';

--    Materialisierte BigTable
INSERT INTO #Speicher
EXECUTE sp_spaceused 'dwh.BigTable';

-- 5. Alles zusammen ausgeben, eine Zeile pro Tabelle
SELECT   -- Schema vor den Namen setzen, weil sp_spaceused nur den Tabellennamen liefert
         'dwh.' + Speicher.Tabelle AS Datenobjekt,
         -- Anzahl Zeilen kommt als Text und wird zur Zahl
         CAST (Speicher.Zeilen AS BIGINT) AS Bestand,
         -- Neue Zeilen im letzten vollen Jahr, Stammdaten ohne Zählung bekommen 0
         ISNULL(Zaehlung.Zuwachs, 0) AS Zuwachs,
         -- Wachstum = Zuwachs ÷ Vorjahr − 1
         -- DECIMAL damit mit Kommastellen gerechnet wird, NULLIF verhindert Division durch 0
         ISNULL (
             ROUND (
                 CAST (Zaehlung.Zuwachs AS DECIMAL (18, 4)) / NULLIF (Zaehlung.Vorjahr, 0) - 1,
                 4
             ),
             0
         ) AS Wachstum,
         -- Satzlänge = data in KB × 1024 ÷ Anzahl Zeilen = Bytes pro Zeile
         -- REPLACE entfernt " KB", damit aus dem Text eine Zahl wird
         ISNULL (
             CAST (ROUND (
                 CAST (REPLACE (
                     Speicher.Daten,
                     ' KB',
                     ''
                 ) AS BIGINT) * 1024.0 / NULLIF (CAST (Speicher.Zeilen AS BIGINT), 0),
                 0
             ) AS INT),
             0
         ) AS Satzlaenge
FROM     #Speicher AS Speicher
         -- LEFT JOIN: alle gemessenen Tabellen bleiben, auch ohne Zuwachs
         LEFT JOIN
         (-- 4. Zuwachs zählen: pro Tabelle neue Zeilen im Basisjahr und im Vorjahr
          SELECT   Ereignisse.Tabelle,
                   SUM(CASE WHEN Ereignisse.Jahr = @Jahr THEN 1 ELSE 0 END) AS Zuwachs,
                   SUM(CASE WHEN Ereignisse.Jahr = @Jahr - 1 THEN 1 ELSE 0 END) AS Vorjahr
          FROM     (-- Jede Zeile hier = eine neue Zeile in der Tabelle, mit dem Jahr, in dem sie dazukam
                    -- Faktentabelle: neue Verkaufsposition = Bestelldatum
                    SELECT 'FactInternetSales' AS Tabelle,
                           YEAR(Verkaeufe.OrderDate) AS Jahr
                    FROM   dwh.FactInternetSales AS Verkaeufe
                    -- BigTable: eine Zeile pro Verkauf, wächst darum genau wie die Faktentabelle
                    UNION ALL
                    SELECT 'BigTable',
                           YEAR(Verkaeufe.OrderDate)
                    FROM   dwh.FactInternetSales AS Verkaeufe
                    -- Neuer Kunde = Datum des ersten Kaufs
                    UNION ALL
                    SELECT 'DimCustomer',
                           YEAR(Kunden.DateFirstPurchase)
                    FROM   dwh.DimCustomer AS Kunden
                    -- Neues Produkt = Startdatum
                    UNION ALL
                    SELECT 'DimProduct',
                           YEAR(Produkte.StartDate)
                    FROM   dwh.DimProduct AS Produkte
                    -- Neue Aktion = Startdatum
                    UNION ALL
                    SELECT 'DimPromotion',
                           YEAR(Aktionen.StartDate)
                    FROM   dwh.DimPromotion AS Aktionen
                    -- Kalender: ein Tag pro Zeile, also 365 pro Jahr
                    UNION ALL
                    SELECT 'DimDate',
                           YEAR(Kalender.FullDateAlternateKey)
                    FROM   dwh.DimDate AS Kalender) AS -- Alle anderen Dimensionen sind Stammdaten und fehlen hier absichtlich
                   Ereignisse
          GROUP BY Ereignisse.Tabelle) AS Zaehlung
         ON Zaehlung.Tabelle = Speicher.Tabelle
-- 6. Sortieren: Faktentabelle oben (0), Dimensionen in der Mitte (1), BigTable unten (2)
ORDER BY CASE WHEN Speicher.Tabelle = 'BigTable' THEN 2 WHEN Speicher.Tabelle LIKE 'Fact%' THEN 0 ELSE 1 END,
         Speicher.Tabelle;

-- Temporäre Tabelle löschen, damit das Skript erneut ausgeführt werden kann
DROP TABLE #Speicher;