/* Frage 3: Welche Rabattaktionen kosten am meisten und bringen am wenigsten?
   Vergleicht die gekaufte Menge mit Rabatt mit der normalen Menge ohne Rabatt. */

/* Hilfstabelle: Wie viele Stück werden pro Position normalerweise ohne Rabatt gekauft? */
WITH basis AS (
    SELECT ProductID,
           AVG(CAST(OrderQty AS DECIMAL(10,2))) AS MengeOhneRabatt
    FROM analytics.v_SalesLineMargin
    WHERE SpecialOfferID = 1          /* 1 = kein Rabatt */
    GROUP BY ProductID
)
SELECT
    so.SpecialOfferID,
    so.Description,
    so.Type,
    so.DiscountPct,
    /* Wie viel Rabatt wurde insgesamt gegeben */
    SUM(v.Rabatt)                       AS Rabattkosten,
    SUM(v.OrderQty)                     AS Menge,
    /* Wie viel wurde mehr gekauft als ohne Rabatt üblich */
    SUM(v.OrderQty - b.MengeOhneRabatt) AS Zusatzmenge,
    /* Was hat jedes zusätzlich verkaufte Stück an Rabatt gekostet */
    SUM(v.Rabatt) / NULLIF(SUM(v.OrderQty - b.MengeOhneRabatt), 0) AS RabattJeZusatzstueck,
    SUM(v.Marge)                        AS Marge
FROM analytics.v_SalesLineMargin v
/* Name und Art der Aktion */
JOIN Sales.SpecialOffer so ON so.SpecialOfferID = v.SpecialOfferID
/* Vergleichswert ohne Rabatt dazunehmen */
LEFT JOIN basis b          ON b.ProductID = v.ProductID
/* Nur Verkäufe mit Rabatt */
WHERE v.SpecialOfferID <> 1
GROUP BY so.SpecialOfferID, so.Description, so.Type, so.DiscountPct
/* Teuerste Aktionen zuerst */
ORDER BY Rabattkosten DESC;