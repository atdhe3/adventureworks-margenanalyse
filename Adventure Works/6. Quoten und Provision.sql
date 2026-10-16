/* Frage 6: Erreichen die Verkäufer ihre Ziele, und passt die Provision zur Marge?
   Vergleicht Umsatzziel, echten Umsatz, Marge und Provision pro Verkäufer. */

/* Schritt 1: Zu jeder Quote das Datum der nächsten Quote holen.
   So weiss man, von wann bis wann eine Quote gilt. */
WITH quoten AS (
    SELECT
        BusinessEntityID,
        QuotaDate,
        SalesQuota,
        LEAD(QuotaDate) OVER (PARTITION BY BusinessEntityID ORDER BY QuotaDate) AS NaechsteQuota
    FROM Sales.SalesPersonQuotaHistory
),
/* Schritt 2: Für jeden Zeitraum den echten Umsatz und die Marge des Verkäufers berechnen */
perioden AS (
    SELECT q.BusinessEntityID, q.SalesQuota, i.Umsatz, i.Marge
    FROM quoten q
    /* OUTER APPLY behält auch Zeiträume ohne Verkäufe */
    OUTER APPLY (
        SELECT SUM(v.Umsatz) AS Umsatz, SUM(v.Marge) AS Marge
        FROM analytics.v_SalesLineMargin v
        WHERE v.SalesPersonID = q.BusinessEntityID
          AND v.OrderDate >= q.QuotaDate
          /* Letzte Quote hat keinen Nachfolger, dort 3 Monate annehmen */
          AND v.OrderDate <  COALESCE(q.NaechsteQuota, DATEADD(MONTH, 3, q.QuotaDate))
    ) i
)
/* Sc-hritt 3: Alles pro Verkäufer zusammenfassen */
SELECT
    pp.FirstName + ' ' + pp.LastName  AS Vertriebsmitarbeiter,
    SUM(pe.SalesQuota)                AS Quote,
    SUM(pe.Umsatz)                    AS Umsatz,
    /* Wie viel Prozent des Ziels wurden erreicht */
    CAST(100.0 * SUM(pe.Umsatz) / NULLIF(SUM(pe.SalesQuota), 0) AS DECIMAL(6,2)) AS QuotenerreichungProzent,
    SUM(pe.Marge)                     AS Marge,
    sp.CommissionPct,
    /* Provision = Umsatz mal Provisionssatz */
    SUM(pe.Umsatz) * sp.CommissionPct AS Provision,
    /* Wie viel der Marge geht als Provision weg */
    CAST(100.0 * SUM(pe.Umsatz) * sp.CommissionPct / NULLIF(SUM(pe.Marge), 0) AS DECIMAL(6,2)) AS ProvisionInProzentDerMarge
FROM perioden pe
/* Provisionssatz des Verkäufers */
JOIN Sales.SalesPerson sp ON sp.BusinessEntityID = pe.BusinessEntityID
/* Name des Verkäufers */
JOIN Person.Person pp     ON pp.BusinessEntityID = sp.BusinessEntityID
GROUP BY pp.FirstName, pp.LastName, sp.CommissionPct
/* Beste Zielerreichung zuerst */
ORDER BY QuotenerreichungProzent DESC;