/* Frage 2: Wie unterscheiden sich Onlineshop und Händler?
   Vergleicht Umsatz, Bestellwert, Rabatt und Marge der beiden Verkaufswege. */
SELECT
    /* Flag in lesbaren Text umwandeln */
    CASE WHEN OnlineOrderFlag = 1 THEN 'Online' ELSE 'Reseller' END AS Kanal,
    /* Aufträge zählen, nicht einzelne Positionen */
    COUNT(DISTINCT SalesOrderID)               AS Auftraege,
    SUM(Umsatz)                                AS Umsatz,
    /* Durchschnittlicher Wert pro Auftrag */
    SUM(Umsatz) / COUNT(DISTINCT SalesOrderID) AS DurchschnittlicherBestellwert,
    SUM(Rabatt)                                AS Rabatt,
    SUM(Marge)                                 AS Marge,
    CAST(100.0 * SUM(Marge) / NULLIF(SUM(Umsatz), 0) AS DECIMAL(6,2)) AS MargenquoteProzent
FROM analytics.v_SalesLineMargin
/* Ergibt zwei Zeilen: Online und Reseller */
GROUP BY OnlineOrderFlag;