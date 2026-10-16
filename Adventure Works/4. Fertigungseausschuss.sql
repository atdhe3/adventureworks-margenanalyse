/* Frage 4: Bei welchen Produkten entsteht der teuerste Ausschuss und warum?
   Ausschuss = Teile, die in der Produktion kaputt gehen und weggeworfen werden. */
SELECT TOP 20
    p.Name              AS Produkt,
    sr.Name             AS Ausschussgrund,
    COUNT(*)            AS Arbeitsauftraege,
    SUM(wo.ScrappedQty) AS Ausschussmenge,
    /* Kosten = weggeworfene Menge mal Herstellkosten */
    SUM(wo.ScrappedQty * p.StandardCost) AS Ausschusskosten
FROM Production.WorkOrder wo
JOIN Production.Product p      ON p.ProductID = wo.ProductID
/* Grund für den Ausschuss */
JOIN Production.ScrapReason sr ON sr.ScrapReasonID = wo.ScrapReasonID
/* Nur Aufträge, bei denen etwas weggeworfen wurde */
WHERE wo.ScrappedQty > 0
GROUP BY p.Name, sr.Name
/* Teuerster Ausschuss zuerst */
ORDER BY Ausschusskosten DESC;