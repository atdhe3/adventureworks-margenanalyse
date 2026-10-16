CREATE VIEW dbo.DimProduct AS
SELECT p.ProductID, p.Name AS Product, ps.Name AS Subcategory,
       pc.Name AS Category, p.Color, p.ListPrice
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID;
go

CREATE VIEW dbo.DimCustomer AS
SELECT c.CustomerID, pe.FirstName, pe.LastName, st.Name AS Store
FROM Sales.Customer c
LEFT JOIN Person.Person pe ON c.PersonID = pe.BusinessEntityID
LEFT JOIN Sales.Store st ON c.StoreID = st.BusinessEntityID;

go

CREATE VIEW dbo.DimTerritory AS
SELECT TerritoryID, Name AS Territory, CountryRegionCode, [Group] AS Region
FROM Sales.SalesTerritory;