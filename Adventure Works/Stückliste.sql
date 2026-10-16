/* Frage 5a: Funktion, die ein Produkt komplett in alle Einzelteile zerlegt.
   Man gibt eine Produkt ID hinein und bekommt alle Teile über alle Ebenen zurück.
   Beispiel: Velo > Rad > Speichen. */
CREATE FUNCTION analytics.fn_Stueckliste (@ProductID INT)
RETURNS TABLE
AS
RETURN
WITH bom AS (
    /* Startpunkt: die direkten Teile des Produkts (Ebene 1) */
    SELECT
        b.ProductAssemblyID,
        b.ComponentID,
        CAST(b.PerAssemblyQty AS DECIMAL(18,4)) AS Menge,
        1 AS Ebene
    FROM Production.BillOfMaterials b
    WHERE b.ProductAssemblyID = @ProductID
      AND b.EndDate IS NULL           /* nur aktuell gültige Stückliste */

    UNION ALL

    /* Wiederholung: zu jedem gefundenen Teil dessen eigene Teile holen.
       Läuft automatisch weiter, bis keine Teile mehr gefunden werden. */
    SELECT
        b.ProductAssemblyID,
        b.ComponentID,
        /* Mengen über die Ebenen multiplizieren, z. B. 2 Räder x 32 Speichen = 64 */
        CAST(bom.Menge * b.PerAssemblyQty AS DECIMAL(18,4)),
        bom.Ebene + 1
    FROM Production.BillOfMaterials b
    JOIN bom ON b.ProductAssemblyID = bom.ComponentID
    WHERE b.EndDate IS NULL
)
/* Ergebnis mit Name und Kosten jedes Teils */
SELECT
    bom.Ebene,
    bom.ProductAssemblyID,
    bom.ComponentID,
    p.Name                     AS Komponente,
    bom.Menge,
    p.StandardCost,
    bom.Menge * p.StandardCost AS Kosten
FROM bom
JOIN Production.Product p ON p.ProductID = bom.ComponentID;
