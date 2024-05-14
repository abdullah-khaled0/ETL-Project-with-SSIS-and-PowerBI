CREATE TABLE DimCustomer (
    CustomerID VARCHAR(20) PRIMARY KEY,
    Gender VARCHAR(10),
    SeniorCitizen INT,
    Partner VARCHAR(3),
    Dependents VARCHAR(3)
);

CREATE TABLE DimInternetService (
    InternetServiceID INT PRIMARY KEY IDENTITY(1,1),
    InternetService VARCHAR(20)
);

CREATE TABLE DimContract (
    ContractID INT PRIMARY KEY IDENTITY(1,1),
    Contract VARCHAR(20)
);

CREATE TABLE DimPaymentMethod (
    PaymentMethodID INT PRIMARY KEY IDENTITY(1,1),
    PaymentMethod VARCHAR(50)
);

CREATE TABLE FactCustomerInteraction (
    CustomerID VARCHAR(20),
    Tenure INT,
    MonthlyCharges DECIMAL(10,2),
    TotalCharges DECIMAL(10,2),
    Churn VARCHAR(3),
    InternetServiceID INT,
    ContractID INT,
    PaymentMethodID INT,
    FOREIGN KEY (CustomerID) REFERENCES DimCustomer(CustomerID),
    FOREIGN KEY (InternetServiceID) REFERENCES DimInternetService(InternetServiceID),
    FOREIGN KEY (ContractID) REFERENCES DimContract(ContractID),
    FOREIGN KEY (PaymentMethodID) REFERENCES DimPaymentMethod(PaymentMethodID)
);




DELETE FROM DimCustomer;
-- Insert data into DimCustomer table
INSERT INTO TargetDatabase.dbo.DimCustomer (CustomerID, Gender, SeniorCitizen, Partner, Dependents)
SELECT customerID, Gender, SeniorCitizen, Partner, Dependents
FROM SourceDatabase.dbo.Customers;


-- Insert data into DimInternetService table
INSERT INTO TargetDatabase.dbo.DimInternetService (InternetService)
SELECT DISTINCT InternetService
FROM SourceDatabase.dbo.Customers;


-- Insert data into DimContract table
INSERT INTO TargetDatabase.dbo.DimContract (Contract)
SELECT DISTINCT Contract
FROM SourceDatabase.dbo.Customers;

-- Insert data into DimPaymentMethod table
INSERT INTO TargetDatabase.dbo.DimPaymentMethod (PaymentMethod)
SELECT DISTINCT PaymentMethod
FROM SourceDatabase.dbo.Customers;


DELETE FROM FactCustomerInteraction;
-- Insert data into FactCustomerInteraction table
INSERT INTO TargetDatabase.dbo.FactCustomerInteraction (CustomerID, Tenure, MonthlyCharges, TotalCharges, Churn, InternetServiceID, ContractID, PaymentMethodID)
SELECT
    sc.customerID,
    TRY_CONVERT(INT, sc.tenure) AS Tenure,
    TRY_CONVERT(DECIMAL(10, 2), sc.MonthlyCharges) AS MonthlyCharges,
    TRY_CONVERT(DECIMAL(10, 2), sc.TotalCharges) AS TotalCharges,
    sc.Churn,
    di.InternetServiceID,
    dc.ContractID,
    dpm.PaymentMethodID
FROM
    SourceDatabase.dbo.Customers sc
    JOIN TargetDatabase.dbo.DimInternetService di ON sc.InternetService = di.InternetService
    JOIN TargetDatabase.dbo.DimContract dc ON sc.Contract = dc.Contract
    JOIN TargetDatabase.dbo.DimPaymentMethod dpm ON sc.PaymentMethod = dpm.PaymentMethod



USE SourceDatabase;
USE TargetDatabase;


SELECT * FROM DimCustomer;
SELECT * FROM DimInternetService;
SELECT * FROM DimContract;
SELECT * FROM DimPaymentMethod;
SELECT * FROM FactCustomerInteraction;

SELECT * FROM Customers;


-- Total Customers
CREATE OR ALTER VIEW vw_Total_Customers AS
SELECT 
    COUNT(CustomerID) AS Total_Customers
FROM 
    dbo.FactCustomerInteraction;


-- Gender Distribution
CREATE OR ALTER VIEW vw_Gender_Distribution AS
SELECT 
    Gender,
    COUNT(*) AS Total_Customers,
    (COUNT(*) * 1.0 / (SELECT COUNT(*) FROM DimCustomer)) * 100 AS Percentage
FROM 
    DimCustomer
GROUP BY 
    Gender;


-- Churn Rate
CREATE OR ALTER VIEW vw_Churn_Rate AS
SELECT 
    AVG(CASE WHEN Churn = 'Yes' THEN 1.0 ELSE 0.0 END) AS Churn_Rate
FROM 
    FactCustomerInteraction;


-- Average Monthly Charges
CREATE OR ALTER VIEW vw_Avg_Monthly_Charges AS
SELECT 
    AVG(MonthlyCharges) AS Avg_Monthly_Charges
FROM 
    FactCustomerInteraction;


-- Customer Lifetime Duration
CREATE OR ALTER VIEW vw_Avg_Customer_Lifetime_Duration AS
SELECT 
    AVG(Tenure) AS Avg_Customer_Lifetime_Duration
FROM 
    FactCustomerInteraction;


-- Average Monthly Charges by Contract Type
CREATE OR ALTER VIEW vw_Avg_Monthly_Charges_By_Contract AS
SELECT 
    dc.Contract,
    AVG(fci.MonthlyCharges) AS Avg_Monthly_Charges
FROM 
    FactCustomerInteraction fci
JOIN 
    DimContract dc ON fci.ContractID = dc.ContractID
GROUP BY 
    dc.Contract;


-- Average Tenure by Payment Method
CREATE OR ALTER VIEW vw_Avg_Tenure_By_Payment_Method AS
SELECT 
    dp.PaymentMethod,
    AVG(fci.Tenure) AS Avg_Tenure
FROM 
    FactCustomerInteraction fci
JOIN 
    DimPaymentMethod dp ON fci.PaymentMethodID = dp.PaymentMethodID
GROUP BY 
    dp.PaymentMethod;


-- Customer Lifetime Value (CLV) by Payment Method
CREATE OR ALTER VIEW vw_CLV_By_Payment_Method AS
SELECT 
    dp.PaymentMethod,
    AVG(fci.TotalCharges) AS CLV
FROM 
    FactCustomerInteraction fci
JOIN 
    DimPaymentMethod dp ON fci.PaymentMethodID = dp.PaymentMethodID
GROUP BY 
    dp.PaymentMethod;


-- Customer Lifetime Value (CLV) by Tenure
CREATE OR ALTER VIEW vw_CLV_By_Tenure AS
SELECT 
    CASE
        WHEN fci.Tenure <= 12 THEN '0-12 months'
        WHEN fci.Tenure <= 24 THEN '13-24 months'
        WHEN fci.Tenure <= 36 THEN '25-36 months'
        ELSE 'Over 36 months'
    END AS Tenure_Range,
    AVG(fci.TotalCharges) AS Avg_CLV
FROM 
    FactCustomerInteraction fci
GROUP BY 
    CASE
        WHEN fci.Tenure <= 12 THEN '0-12 months'
        WHEN fci.Tenure <= 24 THEN '13-24 months'
        WHEN fci.Tenure <= 36 THEN '25-36 months'
        ELSE 'Over 36 months'
    END;


-- Payment Method Distribution
CREATE OR ALTER VIEW vw_Payment_Method_Distribution AS
SELECT 
    pm.PaymentMethod,
    COUNT(*) AS Total_Customers,
    (COUNT(*) * 1.0 / (SELECT COUNT(*) FROM FactCustomerInteraction)) * 100 AS Percentage
FROM 
    FactCustomerInteraction fci
JOIN 
    DimPaymentMethod pm ON fci.PaymentMethodID = pm.PaymentMethodID
GROUP BY 
    pm.PaymentMethod;


-- Contract Type Distribution
CREATE OR ALTER VIEW vw_Contract_Type_Distribution AS
SELECT 
    c.Contract,
    COUNT(*) AS Total_Customers,
    (COUNT(*) * 1.0 / (SELECT COUNT(*) FROM FactCustomerInteraction)) * 100 AS Percentage
FROM 
    FactCustomerInteraction fci
JOIN 
    DimContract c ON fci.ContractID = c.ContractID
GROUP BY 
    c.Contract;


-- Internet Service Type Distribution
CREATE OR ALTER VIEW vw_Internet_Service_Distribution AS
SELECT 
    is_.InternetService,
    COUNT(*) AS Total_Customers,
    (COUNT(*) * 1.0 / (SELECT COUNT(*) FROM FactCustomerInteraction)) * 100 AS Percentage
FROM 
    FactCustomerInteraction fci
JOIN
    DimInternetService is_ ON fci.InternetServiceID = is_.InternetServiceID
GROUP BY 
    is_.InternetService;


-- Churn Status Distribution
CREATE OR ALTER VIEW vw_Churn_Status_Distribution AS
SELECT 
    fci.Churn,
    COUNT(*) AS Total_Customers,
    (COUNT(*) * 1.0 / (SELECT COUNT(*) FROM FactCustomerInteraction)) * 100 AS Percentage
FROM 
    FactCustomerInteraction fci
GROUP BY 
    fci.Churn;