-- 1. Letztes volles Jahr finden
--    Nur Jahre mit Bestellungen in allen 12 Monaten zählen, davon das neuste
DECLARE @Jahr AS INT = (SELECT MAX(VolleJahre.Jahr)
                        FROM   (SELECT   YEAR(Bestellungen.OrderDate) AS Jahr
                                FROM     Sales.SalesOrderHeader AS Bestellungen
                                GROUP BY YEAR(Bestellungen.OrderDate)
                                HAVING   COUNT(DISTINCT MONTH(Bestellungen.OrderDate)) = 12) AS VolleJahre);

-- 3. Ausgabe: eine Zeile pro Tabelle mit Zuwachs und Wachstum
SELECT   -- Neue Zeilen im letzten vollen Jahr, Stammdaten ohne Zählung bekommen 0
         ISNULL(Zaehlung.Zuwachs, 0) AS Zuwachs,
         -- Wachstum = Zuwachs ÷ Vorjahr − 1
         -- DECIMAL damit mit Kommastellen gerechnet wird, NULLIF verhindert Division durch 0
         ISNULL (
             ROUND (
                 CAST (Zaehlung.Zuwachs AS DECIMAL (18, 4)) / NULLIF (Zaehlung.Vorjahr, 0) - 1,
                 4
             ),
             0
         ) AS Wachstum
FROM     -- Ausgangspunkt: alle Tabellen der Datenbank, damit auch Stammdaten erscheinen
         sys.tables AS Tabellen
         -- LEFT JOIN: alle Tabellen bleiben, auch die ohne Zuwachs
         LEFT OUTER JOIN
         (-- 2. Zuwachs zählen: pro Tabelle neue Zeilen im Basisjahr und im Vorjahr
          SELECT   Ereignisse.Tabelle,
                   SUM (
                       CASE WHEN YEAR (Ereignisse.Datum) = @Jahr THEN 1 ELSE 0 END
                   ) AS Zuwachs, -- Basisjahr
                   SUM (
                       CASE WHEN YEAR (Ereignisse.Datum) = @Jahr - 1 THEN 1 ELSE 0 END
                   ) AS Vorjahr -- Jahr davor
          FROM     (-- Jede Zeile hier = eine neue Zeile in der Tabelle, mit dem Datum, an dem sie dazukam
                    -- Verkauf: neue Bestellung = Bestelldatum
                    SELECT   'SalesOrderHeader' AS Tabelle,
                             Bestellungen.OrderDate AS Datum
                    FROM     Sales.SalesOrderHeader AS Bestellungen
                    -- Bestellpositionen haben kein eigenes Datum, darum das Bestelldatum über den JOIN holen
                    UNION ALL
                    SELECT   'SalesOrderDetail',
                             Bestellungen.OrderDate
                    FROM     Sales.SalesOrderDetail AS Positionen
                             INNER JOIN
                             Sales.SalesOrderHeader AS Bestellungen
                             ON Positionen.SalesOrderID = Bestellungen.SalesOrderID
                    -- Bestellgründe: ebenfalls über das Bestelldatum
                    UNION ALL
                    SELECT   'SalesOrderHeaderSalesReason',
                             Bestellungen.OrderDate
                    FROM     Sales.SalesOrderHeaderSalesReason AS Gründe
                             INNER JOIN
                             Sales.SalesOrderHeader AS Bestellungen
                             ON Gruende.SalesOrderID = Bestellungen.SalesOrderID
                    -- Neuer Kunde = Datum seiner ersten Bestellung
                    UNION ALL
                    SELECT   'Customer',
                             MIN(Bestellungen.OrderDate)
                    FROM     Sales.SalesOrderHeader AS Bestellungen
                    GROUP BY Bestellungen.CustomerID
                    -- Wechselkurse: Datum des Kurses
                    UNION ALL
                    SELECT   'CurrencyRate',
                             Kurse.CurrencyRateDate
                    FROM     Sales.CurrencyRate AS Kurse
                    -- Einkauf: neue Einkaufsbestellung = Bestelldatum
                    UNION ALL
                    SELECT   'PurchaseOrderHeader',
                             Einkauf.OrderDate
                    FROM     Purchasing.PurchaseOrderHeader AS Einkauf
                    -- Einkaufspositionen: Bestelldatum über den JOIN holen
                    UNION ALL
                    SELECT   'PurchaseOrderDetail',
                             Einkauf.OrderDate
                    FROM     Purchasing.PurchaseOrderDetail AS Einkaufspositionen
                             INNER JOIN
                             Purchasing.PurchaseOrderHeader AS Einkauf
                             ON Einkaufspositionen.PurchaseOrderID = Einkauf.PurchaseOrderID
                    -- Produktion und Lager
                    UNION ALL
                    SELECT   'TransactionHistory',
                             Transaktionen.TransactionDate
                    FROM     Production.TransactionHistory AS Transaktionen -- Lagerbewegung
                    UNION ALL
                    SELECT   'WorkOrder',
                             Aufträge.StartDate
                    FROM     Production.WorkOrder AS Aufträge -- Arbeitsauftrag
                    UNION ALL
                    SELECT   'WorkOrderRouting',
                             Arbeitsschritte.ScheduledStartDate
                    FROM     Production.WorkOrderRouting AS Arbeitsschritte -- Arbeitsschritt
                    -- Produkte
                    UNION ALL
                    SELECT   'Product',
                             Produkte.SellStartDate
                    FROM     Production.Product AS Produkte -- neues Produkt = Verkaufsstart
                    UNION ALL
                    SELECT   'ProductCostHistory',
                             Kosten.StartDate
                    FROM     Production.ProductCostHistory AS Kosten -- neue Kosten = gültig ab
                    UNION ALL
                    SELECT   'ProductListPriceHistory',
                             Preise.StartDate
                    FROM     Production.ProductListPriceHistory AS Preise -- neuer Preis = gültig ab
                    -- Personal: neuer Mitarbeiter = Eintrittsdatum
                    UNION ALL
                    SELECT   'Employee',
                             Mitarbeiter.HireDate
                    FROM     HumanResources.Employee AS Mitarbeiter) AS -- Alle anderen Tabellen sind Stammdaten und fehlen hier absichtlich
                   Ereignisse
          GROUP BY Ereignisse.Tabelle) AS Zaehlung
         ON -- Verbindung über den Tabellennamen
         -- Personentabellen haben kein eigenes Erstellungsdatum und wachsen wie die Kunden
         Zaehlung.Tabelle = CASE WHEN Tabellen.name IN (
             'Person',
             'BusinessEntity',
             'BusinessEntityAddress',
             'Address',
             'EmailAddress',
             'Password',
             'PersonPhone',
             'CreditCard',
             'PersonCreditCard'
         ) THEN 'Customer' ELSE Tabellen.name END
-- Nur eigene Tabellen, keine Systemtabellen von Microsoft
WHERE    Tabellen.is_ms_shipped = 0
-- Alphabetisch sortieren wie im Excel Blatt OLTP
-- HumanResources.Shift heisst im Excel HumanResources_Shift und muss an derselben Stelle stehen
ORDER BY CASE WHEN Tabellen.name = 'Shift' THEN 'HumanResources_Shift' ELSE Tabellen.name END;