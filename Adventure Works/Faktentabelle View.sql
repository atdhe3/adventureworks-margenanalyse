CREATE VIEW dbo.FactSales AS
SELECT d.SalesOrderID, d.SalesOrderDetailID,
       CAST(h.OrderDate AS date) AS OrderDate,
       h.CustomerID, d.ProductID, h.TerritoryID,
       d.OrderQty, d.UnitPrice, d.UnitPriceDiscount, d.LineTotal
FROM Sales.SalesOrderDetail d
JOIN Sales.SalesOrderHeader h ON d.SalesOrderID = h.SalesOrderID;
