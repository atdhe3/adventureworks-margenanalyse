--OLTP--

/* Frage 1a: Welche Produkte haben die niedrigste Marge?
   Zeigt die 20 Produkte, bei denen am wenigsten vom Umsatz übrig bleibt. */
SELECT TOP 20
    p.name          AS Produkt,
    SUM(v.OrderQty) AS Menge,
    SUM(v.Umsatz)   AS Umsatz,
    SUM(v.Marge)    AS Marge,
   /* Margenquote in Prozent. NULLIF verhindert eine Division durch null */
   CAST(100.0 * SUM(v.Marge) / NULLIF(SUM(v.Umsatz), 0) AS DECIMAL(6,2)) AS MargenquoteProzent
FROM oltp.v_SalesLineMargin as v
/* Produkt, Unterkategorie und Kategorie verbinden */
JOIN oltp.Product p             ON p.ProductID = v.ProductID
JOIN oltp.ProductSubcategory ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
JOIN oltp.ProductCategory pc    ON pc.ProductCategoryID = ps.ProductCategoryID
/* Alle Verkäufe pro Produkt zusammenfassen */
GROUP BY p.name
/* Schlechteste Marge zuerst */
ORDER BY MargenquoteProzent ASC;



--Star Schema--
-- Abfrage mit derselben Faktentabelle wie in der BigTable:
-- dwh.FactInternetSales

SELECT   TOP (20) p.EnglishProductName AS Produkt,
                  SUM(f.SalesAmount) AS Umsatz,
                  SUM(f.SalesAmount - f.TotalProductCost) AS Marge,
                  CAST (100.0 * SUM(f.SalesAmount - f.TotalProductCost) / NULLIF (SUM(f.SalesAmount), 0) AS DECIMAL (6, 2)) AS MargenquoteProzent
FROM     dwh.FactInternetSales AS f
         INNER JOIN
         dwh.DimProduct AS p
         ON p.ProductKey = f.ProductKey
GROUP BY p.EnglishProductName
ORDER BY MargenquoteProzent ASC, produkt asc;


--BigTable--

SELECT   TOP (20) b.Produkt_EnglishProductName,
                  SUM(b.salesamount) AS Umsatz,
                  SUM(b.salesamount - b.totalProductCost) AS Marge,
                  /* Margenquote in Prozent. NULLIF verhindert eine Division durch null */
                  CAST(
    100.0 * SUM(b.SalesAmount - b.TotalProductCost)
    / NULLIF(SUM(b.SalesAmount), 0)
    AS decimal(6, 2)
) AS MargenquoteProzent
FROM     dwh.BigTable AS b
/* Alle Verkäufe pro Produkt zusammenfassen */
GROUP BY b.Produkt_EnglishProductName
/* Schlechteste Marge zuerst */
ORDER BY MargenquoteProzent ASC, Produkt_EnglishProductName asc;
