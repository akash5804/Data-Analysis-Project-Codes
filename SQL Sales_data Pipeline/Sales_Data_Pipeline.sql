-- Step 1: Create Staging Table
CREATE TABLE IF NOT EXISTS staging_sales limit 5; (
    InvoiceNo text,
    StockCode varchar(30),
    Description varchar(125),
    Quantity int,
	InvoiceDate text,
	UnitPrice Numeric(10,2),
	CustomerID int,
    Country varchar(20)
);

-- Step 2: Load CSV Data into Staging Table
-- Open pgAdmin 4 and connect to your PostgreSQL database.
-- Navigate to your database → Schemas → Tables → staging_sales.
-- Right-click on staging_sales → Select "Import/Export Data...".
-- In the pop-up window:
-- Filename: Select your CSV file (E-Commerce Data.csv).
-- Format: Choose CSV.
-- Header: Yes (check the box).
-- Delimiter: , (comma).

-- Step 3: Create Final Processed Table
CREATE TABLE IF NOT EXISTS final_sales (
    InvoiceNo text,
    StockCode varchar(30),
    Description varchar(125),
    Quantity int,
	InvoiceDate TimeStamp,
	UnitPrice Numeric(10,2),
	CustomerID int,
    Country varchar(20)
);

-- Step 4: Insert Clean Data into Final Table
INSERT INTO final_sales (InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country)
SELECT 
    InvoiceNo, 
    StockCode,
	Description,
	Quantity,
	TO_TIMESTAMP(InvoiceDate, 'MM/DD/YYYY HH24:MI'), -- Convert text date to timestamp
	UnitPrice,
	CustomerID,
	Country   
FROM staging_sales
WHERE quantity > 0;

-- Step 5: Create Aggregated Sales Summary View
CREATE or replace VIEW sales_summary AS
SELECT 
    description, 
    SUM(UnitPrice) AS total_sales, 
    SUM(Quantity) AS total_quantity
FROM final_sales
GROUP BY description
order by total_sales desc;

-- Step 6: Log Execution Timestamp
CREATE TABLE IF NOT EXISTS pipeline_logs (
    run_id SERIAL PRIMARY KEY,
    run_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Step 7: Create Trigger to Automate insertion in final_sales
CREATE OR REPLACE FUNCTION move_to_final_sales()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO final_sales (InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country)
    SELECT 
        NEW.InvoiceNo, 
        NEW.StockCode, 
        NEW.Description, 
        NEW.Quantity,
		TO_TIMESTAMP(NEW.InvoiceDate, 'MM/DD/YYYY HH24:MI'),  -- Convert if stored as TEXT
        NEW.UnitPrice,
		NEW.CustomerID,
		NEW.Country
    ;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_move_to_final
AFTER INSERT ON staging_sales
FOR EACH ROW
EXECUTE FUNCTION move_to_final_sales();

-- Step 8: Create Trigger for Automatic Logging
CREATE OR REPLACE FUNCTION log_pipeline_run()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO pipeline_logs (run_time) VALUES (CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_pipeline_log
AFTER INSERT ON final_sales
FOR EACH STATEMENT
EXECUTE FUNCTION log_pipeline_run();