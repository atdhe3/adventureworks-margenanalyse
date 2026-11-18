--   BigTable erstellen Materialisiert das Star Schema (FactInternetSales mit 9 Dimensionen) in eine einzige flache Tabelle mit allen Attributen,ohne 
-- Berechnungen und ohne Aggregation (eine Zeile pro Verkaufsposition)

-- 1. Spaltenliste automatisch zusammensetzen
--    Liest alle Spaltennamen der beteiligten Tabellen aus sys.columns,
--    damit kein Attribut vergessen geht
DECLARE @Spalten AS NVARCHAR (MAX) = (
    SELECT STRING_AGG (
               -- Pro Spalte ein Eintrag wie: Produkt.[Color] AS [Produkt_Color]
               -- Der Präfix verhindert doppelte Spaltennamen, z.B. ProductKey in Fakt und Dimension
               CAST (Quelle.Alias + '.' + QUOTENAME (Spalten.name) + ' AS ' + QUOTENAME (Quelle.Praefix + Spalten.name) AS NVARCHAR (MAX)),
               ', '   -- Einträge mit Komma trennen
           ) WITHIN GROUP (ORDER BY Quelle.Reihenfolge, Spalten.column_id)   -- Reihenfolge: zuerst Fakt, dann Dimensionen, jeweils wie in der Tabelle

    -- Liste der beteiligten Tabellen mit Alias 
   
    FROM (VALUES
        (1,  'dwh.FactInternetSales',     'Verkauf',        ''),                 
        (2,  'dwh.DimDate',               'Bestelldatum',   'Datum_'),
        (3,  'dwh.DimProduct',            'Produkt',        'Produkt_'),
        (4,  'dwh.DimProductSubcategory', 'Unterkategorie', 'Unterkategorie_'),
        (5,  'dwh.DimProductCategory',    'Kategorie',      'Kategorie_'),
        (6,  'dwh.DimCustomer',           'Kunde',          'Kunde_'),
        (7,  'dwh.DimGeography',          'Geografie',      'Geografie_'),
        (8,  'dwh.DimPromotion',          'Aktion',         'Aktion_'),
        (9,  'dwh.DimCurrency',           'Waehrung',       'Waehrung_'),
        (10, 'dwh.DimSalesTerritory',     'Gebiet',         'Gebiet_')
    ) AS Quelle (Reihenfolge, Tabelle, Alias, Praefix)

    -- Zu jeder Tabelle alle ihre Spalten holen
    INNER JOIN sys.columns AS Spalten
        ON Spalten.object_id = OBJECT_ID(Quelle.Tabelle)

    -- Binärdaten wie Produktbilder (LargePhoto) weglassen
    WHERE TYPE_NAME(Spalten.system_type_id) NOT IN ('varbinary', 'image')
);


-- 2. Den ganzen Befehl als Text zusammensetzen
--    SELECT <alle Spalten> INTO dwh.BigTable erstellt die neue Tabelle und füllt sie
--    LEFT JOIN: keine Verkaufszeile geht verloren, auch wenn eine Dimension fehlt
DECLARE @Befehl AS NVARCHAR (MAX) = 'SELECT ' + @Spalten + ' INTO dwh.BigTable
FROM dwh.FactInternetSales AS Verkauf
LEFT JOIN dwh.DimDate AS Bestelldatum ON Verkauf.OrderDateKey = Bestelldatum.DateKey
LEFT JOIN dwh.DimProduct AS Produkt ON Verkauf.ProductKey = Produkt.ProductKey
LEFT JOIN dwh.DimProductSubcategory AS Unterkategorie ON Produkt.ProductSubcategoryKey = Unterkategorie.ProductSubcategoryKey
LEFT JOIN dwh.DimProductCategory AS Kategorie ON Unterkategorie.ProductCategoryKey = Kategorie.ProductCategoryKey
LEFT JOIN dwh.DimCustomer AS Kunde ON Verkauf.CustomerKey = Kunde.CustomerKey
LEFT JOIN dwh.DimGeography AS Geografie ON Kunde.GeographyKey = Geografie.GeographyKey
LEFT JOIN dwh.DimPromotion AS Aktion ON Verkauf.PromotionKey = Aktion.PromotionKey
LEFT JOIN dwh.DimCurrency AS Waehrung ON Verkauf.CurrencyKey = Waehrung.CurrencyKey
LEFT JOIN dwh.DimSalesTerritory AS Gebiet ON Verkauf.SalesTerritoryKey = Gebiet.SalesTerritoryKey';
-- Verknüpfungen:
-- Produkt → Unterkategorie → Kategorie hängen aneinander (Produkthierarchie)
-- Kunde → Geografie: Wohnort des Kunden
-- Alle anderen Dimensionen hängen direkt an der Faktentabelle


-- 3. Befehl ausführen, die BigTable wird erstellt
EXECUTE (@Befehl);


-- 4. Kontrolle: beide Zahlen müssen gleich sein (60'398),
--    sonst wären durch die JOINs Zeilen verloren gegangen oder doppelt entstanden
SELECT COUNT(*) AS Zeilen_BigTable
FROM   dwh.BigTable AS BigTable;

SELECT COUNT(*) AS Zeilen_Fakt
FROM   dwh.FactInternetSales AS Verkauf;