🚴‍♂️ Rapido Riders Analysis Dashboard

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/2/2a/Rapido_logo.png" alt="Rapido Logo" width="160"/>
</p>

📘 Project Overview

This project analyzes Rapido ride data to extract operational and commercial insights. We use MySQL for data ingestion, cleaning, transformation, and analytical queries, and Power BI for interactive visualizations and dashboarding.

Primary Goals

Understand ride demand patterns (hour/day/city).

Measure revenue and losses (including cancellations).

Identify high-value routes and payment preferences.

Provide actionable recommendations for operations and pricing.

🛠️ Tools & Artifacts

Category

Tool

Purpose

Database

MySQL

Schema, cleaning, transformations, views, stored procedures.

Visualization

Power BI Desktop

Interactive dashboards (2 pages).

Data Connection

CSV

rides_cleaned.csv (final cleaned dataset exported from MySQL).

Presentation

PowerPoint

Riders Data Analysis.pptx (Final report and visuals).

📂 Dataset

File: data/rides_cleaned.csv

Example Columns: services, date, time, ride_status, source, destination, duration, ride_id, distance, ride_charge, misc_charge, total_fare, payment_method, ...

⚙️ Reproducible Setup — MySQL (Quick)

The following code is contained within the rapido_rides.sql file.

1. Create Database and Table

CREATE DATABASE rapido_project;
USE rapido_project;

CREATE TABLE rides (
    ride_id VARCHAR(50) PRIMARY KEY,
    services VARCHAR(50),
    date DATE,
    time TIME,
    ride_status VARCHAR(30),
    source VARCHAR(150),
    destination VARCHAR(150),
    duration INT,
    distance DECIMAL(8,2),
    ride_charge DECIMAL(10,2),
    misc_charge DECIMAL(10,2),
    total_fare DECIMAL(10,2),
    payment_method VARCHAR(50)
);


2. Import CSV (Local File)

NOTE: Adjust the file path /path/to/rides_cleaned.csv for your local environment.

LOAD DATA LOCAL INFILE '/path/to/rides_cleaned.csv'
INTO TABLE rides
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(services, @datecol, @timecol, ride_status, source, destination, duration, ride_id, distance, ride_charge, misc_charge, total_fare, payment_method)
SET date = STR_TO_DATE(@datecol, '%Y-%m-%d'),
    time = TIME(@timecol);


3. Data Cleaning & Validation

-- 1. Check null counts:
SELECT 
    SUM(ride_charge IS NULL) AS null_ride_charge,
    SUM(total_fare IS NULL) AS null_total_fare,
    SUM(payment_method IS NULL) AS null_payment_method
FROM rides;

-- 2. Fill fares for cancelled rows (set to 0 to prevent null errors in aggregation):
UPDATE rides
SET ride_charge = COALESCE(ride_charge, 0),
    misc_charge = COALESCE(misc_charge, 0),
    total_fare = COALESCE(total_fare, 0)
WHERE ride_status = 'cancelled';

-- 3. Validate numeric ranges:
SELECT * FROM rides WHERE distance <= 0 OR duration < 0;


4. Feature Engineering (SQL)

ALTER TABLE rides ADD COLUMN ride_hour TINYINT;
ALTER TABLE rides ADD COLUMN ride_day VARCHAR(10);
ALTER TABLE rides ADD COLUMN fare_per_km DECIMAL(10,2);
ALTER TABLE rides ADD COLUMN route VARCHAR(255);

UPDATE rides
SET ride_hour = HOUR(time),
    ride_day = DAYNAME(date),
    fare_per_km = CASE WHEN distance > 0 THEN ROUND(total_fare / distance, 2) ELSE 0 END,
    route = CONCAT(source, ' → ', destination);


🧮 SQL Queries — Business Problems

The following queries were executed to derive the data presented in the Power BI dashboard:

-- 1) Total Rides & Total Revenue (Completed only)
SELECT
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed';

-- 2) Cancelled vs Completed Rides (counts & percent)
SELECT
    ride_status,
    COUNT(*) AS ride_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM rides), 2) AS pct_of_total
FROM rides
GROUP BY ride_status;

-- 3) Top Performing Services by Revenue
SELECT
    services,
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue,
    ROUND(AVG(total_fare), 2) AS avg_fare
FROM rides
WHERE ride_status = 'completed'
GROUP BY services
ORDER BY total_revenue DESC;

-- 4) Average Fare per Kilometer by Service
SELECT
    services,
    ROUND(AVG(fare_per_km), 2) AS avg_fare_per_km
FROM rides
WHERE ride_status = 'completed'
GROUP BY services
ORDER BY avg_fare_per_km DESC;

-- 5) Peak Ride Hours
SELECT
    ride_hour,
    COUNT(*) AS total_rides
FROM rides
WHERE ride_status = 'completed'
GROUP BY ride_hour
ORDER BY total_rides DESC;

-- 6) Busiest Days of Week (rides + revenue)
SELECT
    ride_day,
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed'
GROUP BY ride_day
ORDER BY total_revenue DESC;

-- 7) Revenue Lost Due to Cancellations (Sum of fares recorded for cancelled rides)
SELECT SUM(total_fare) AS cancelled_revenue_loss
FROM rides
WHERE ride_status = 'cancelled';

-- 8) Top Payment Methods (by Revenue)
SELECT
    payment_method,
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed'
GROUP BY payment_method
ORDER BY total_revenue DESC;

-- 9) Most Common Source–Destination Routes (Top 10)
SELECT route, COUNT(*) AS ride_count
FROM rides
WHERE ride_status = 'completed'
GROUP BY route
ORDER BY ride_count DESC
LIMIT 10;

-- 10) Average Ride Duration and Distance by Service
SELECT
    services,
    ROUND(AVG(duration), 2) AS avg_duration_min,
    ROUND(AVG(distance), 2) AS avg_distance_km
FROM rides
WHERE ride_status = 'completed'
GROUP BY services
ORDER BY avg_duration_min DESC;


🧰 Stored Procedures

These procedures automate routine reporting, allowing for easy, repeatable data extraction.

-- Procedure 1 — Daily Summary
DELIMITER $$
CREATE PROCEDURE daily_summary(IN target_date DATE)
BEGIN
    SELECT 
        date AS ride_date,
        COUNT(*) AS total_rides,
        SUM(total_fare) AS total_revenue,
        AVG(total_fare) AS avg_fare
    FROM rides
    WHERE date = target_date
      AND ride_status = 'completed'
    GROUP BY date;
END $$
DELIMITER ;

-- Example call:
-- CALL daily_summary('2024-07-15');


-- Procedure 2 — Service Report
DELIMITER $$
CREATE PROCEDURE service_report()
BEGIN
    SELECT 
        services,
        COUNT(*) AS total_rides,
        SUM(total_fare) AS total_revenue,
        AVG(duration) AS avg_duration_min,
        AVG(distance) AS avg_distance_km
    FROM rides
    WHERE ride_status = 'completed'
    GROUP BY services;
END $$
DELIMITER ;

-- Example call:
-- CALL service_report();


-- Procedure 3 — Payment Breakdown
DELIMITER $$
CREATE PROCEDURE payment_breakdown()
BEGIN
    SELECT 
        payment_method,
        COUNT(*) AS rides,
        SUM(total_fare) AS revenue
    FROM rides
    WHERE ride_status = 'completed'
    GROUP BY payment_method
    ORDER BY revenue DESC;
END $$
DELIMITER ;

-- Example call:
-- CALL payment_breakdown();


📈 Key Insights & Dashboard Structure

The Power BI dashboard provides a visual breakdown of the following insights:

Completion Rate: Completed rides form approximately ~90% of total trips.

Peak Demand: Peak ride hours are consistently between 8:00 AM–10:00 AM and 6:00 PM–8:00 PM.

Top Revenue Driver: The Bike category contributes the most to overall revenue.

Cancellation Impact: The business loses millions in potential revenue due to cancellations, emphasizing the need for operational improvements.

Payment Trends: UPI & Wallet are the most frequently used payment methods.

Dashboard Pages

Page 1: Performance & Revenue Overview (Total Rides, Revenue by Service Type, Rides by Time & Day).

Page 2: Customer & Operational Insights (Payment Method Trends, Cancellation Rate, Common Routes, Revenue Lost).

💡 Key Business Recommendations

Optimize Driver Allocation: Increase active riders in high-demand hours and routes (identified in Query 5, 6, 9) to cut waiting times and increase completion rates.

Encourage Digital Payments: Offer UPI cashback/rewards (identified in Query 8) to boost seamless payments and transaction efficiency.

Reduce Cancellations: Enhance ETA (Estimated Time of Arrival) accuracy to reduce customer cancellations (identified in Query 2, 7).

Dynamic Pricing: Adjust fares during off-peak hours (identified in Query 5) to increase ridership and utilize fleet capacity.

Customer Loyalty Program: Reward frequent riders to improve retention and lifetime value.

Operational Monitoring: Automate real-time tracking of ride completion rate.

📚 Author

👤 Sai Nanthan 📧 Email: [your email]

🔗 LinkedIn Profile | GitHub Profile
