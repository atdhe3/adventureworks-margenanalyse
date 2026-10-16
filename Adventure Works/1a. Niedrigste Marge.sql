/* Frage 1a: Welche Produkte haben die niedrigste Marge?
   Zeigt die 20 Produkte, bei denen am wenigsten vom Umsatz übrig bleibt. */
SELECT TOP 20
    p.Name          AS Produkt,
    pc.Name         AS Kategorie,
    SUM(v.OrderQty) AS Menge,
    SUM(v.Umsatz)   AS Umsatz,
    SUM(v.Marge)    AS Marge,
   /* Margenquote in Prozent. NULLIF verhindert eine Division durch null */
   CAST(100.0 * SUM(v.Marge) / NULLIF(SUM(v.Umsatz), 0) AS DECIMAL(6,2)) AS MargenquoteProzent
FROM analytics.v_SalesLineMargin 
/* Produkt, Unterkategorie und Kategorie verbinden */
JOIN Production.Product p             ON p.ProductID = v.ProductID
JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
JOIN Production.ProductCategory pc    ON pc.ProductCategoryID = ps.ProductCategoryID
/* Alle Verkäufe pro Produkt zusammenfassen */
GROUP BY p.Name, pc.Name
/* Schlechteste Marge zuerst */
ORDER BY MargenquoteProzent ASC;