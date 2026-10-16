/* Frage 5c: Welche Teile treiben die Kosten jedes Velos?
   Zeigt pro Velo die 5 teuersten Teile über alle Ebenen. */

/* Schritt 1: Für jedes Velo die Funktion aufrufen und Kosten pro Teil summieren */
WITH kosten AS (
    SELECT
        p.Name        AS Fahrrad,
        f.Komponente,
        SUM(f.Kosten) AS Kosten
    FROM Production.Product p
    JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
    JOIN Production.ProductCategory pc    ON pc.ProductCategoryID = ps.ProductCategoryID
    /* CROSS APPLY ruft die Funktion für jedes Velo einzeln auf */
    CROSS APPLY analytics.fn_Stueckliste(p.ProductID) f
    WHERE pc.Name = 'Bikes'           /* nur Velos */
      AND f.StandardCost > 0          /* nur Teile mit Kosten */
    GROUP BY p.Name, f.Komponente
),
/* Schritt 2: Teile pro Velo nach Kosten nummerieren und Anteil berechnen */
rang AS (
    SELECT *,
           /* Nummerierung pro Velo, teuerstes Teil = 1 */
           ROW_NUMBER() OVER (PARTITION BY Fahrrad ORDER BY Kosten DESC) AS Rang,
           /* Anteil des Teils an den Gesamtkosten des Velos */
           100.0 * Kosten / NULLIF(SUM(Kosten) OVER (PARTITION BY Fahrrad), 0) AS Anteil
    FROM kosten
)
/* Schritt 3: Nur die 5 teuersten Teile pro Velo anzeigen */
SELECT Fahrrad, Rang, Komponente, Kosten,
       CAST(Anteil AS DECIMAL(6,2)) AS AnteilProzent
FROM rang
WHERE Rang <= 5
ORDER BY Fahrrad, Rang;