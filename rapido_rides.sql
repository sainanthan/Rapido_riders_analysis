-- DATABASE SETUP
-- Step 1: Create Database
CREATE DATABASE rapido_project;
USE rapido_project;

-- Step 2: Create Main Table
CREATE TABLE rides (
    ride_id VARCHAR(50) PRIMARY KEY,
    services VARCHAR(50),
    ride_date DATE,
    ride_time TIME,
    ride_status VARCHAR(30),
    source VARCHAR(100),
    destination VARCHAR(100),
    duration INT,
    distance FLOAT,
    ride_charge DECIMAL(10,2),
    misc_charge DECIMAL(10,2),
    total_fare DECIMAL(10,2),
    payment_method VARCHAR(50)
);

-- Step 3: Loading Data
LOAD DATA LOCAL INFILE 'D:\DA projects\Rapido Rider Analysis\rides_data.csv'
INTO TABLE rides
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(services, date, time, ride_status, source, destination, duration, ride_id, distance, ride_charge, misc_charge, total_fare, payment_method)
SET 
ride_date = STR_TO_DATE(date, '%Y-%m-%d'),
ride_time = TIME(time);

SHOW VARIABLES LIKE 'local_infile';

LOAD DATA LOCAL INFILE 'D:/DA projects/Rapido Rider Analysis/rides_data.csv'
INTO TABLE rides
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@services, @date, @time, @ride_status, @source, @destination, @duration, @ride_id, @distance, @ride_charge, @misc_charge, @total_fare, @payment_method)
SET
services = @services,
ride_date = STR_TO_DATE(@date, '%Y-%m-%d'),
ride_time = TIME(@time),
ride_status = @ride_status,
source = @source,
destination = @destination,
duration = @duration,
ride_id = @ride_id,
distance = @distance,
ride_charge = @ride_charge,
misc_charge = @misc_charge,
total_fare = @total_fare,
payment_method = @payment_method;

SHOW VARIABLES LIKE 'local_infile';

select*from rides;


-- Step 4: Data Cleaning and Handling null values
-- Check nulls and duplicates
SELECT 
    SUM(ride_charge IS NULL) AS null_ride_charge,
    SUM(misc_charge IS NULL) AS null_misc_charge,
    SUM(total_fare IS NULL) AS null_total_fare
FROM rides;

-- Handle nulls for cancelled rides
UPDATE rides
SET ride_charge = 0, misc_charge = 0, total_fare = 0
WHERE ride_status = 'cancelled';

-- Ensuring no duplicate ride_ids
SELECT ride_id, COUNT(*) FROM rides GROUP BY ride_id HAVING COUNT(*) > 1;


-- Step 4: Feature Engineering
-- Add fare per km
ALTER TABLE rides ADD COLUMN fare_per_km DECIMAL(10,2);
UPDATE rides
SET fare_per_km = CASE WHEN distance > 0 THEN total_fare / distance ELSE 0 END;

-- Add hour of ride
ALTER TABLE rides ADD COLUMN ride_hour INT;
UPDATE rides SET ride_hour = HOUR(ride_time);

-- Add day of week
ALTER TABLE rides ADD COLUMN ride_day VARCHAR(20);
UPDATE rides SET ride_day = DAYNAME(ride_date);




-- Step 5: Business Problems & Analytical Queries 
-- 1.Total Rides & Total Revenue
SELECT 
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed';


-- 2.Cancelled vs Completed Rides
SELECT 
    ride_status,
    COUNT(*) AS ride_count,
    ROUND((COUNT(*) / (SELECT COUNT(*) FROM rides))*100, 2) AS percentage
FROM rides
GROUP BY ride_status;


-- 3.Top Performing Services by Revenue
SELECT 
    services,
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue,
    ROUND(AVG(total_fare),2) AS avg_fare
FROM rides
WHERE ride_status = 'completed'
GROUP BY services
ORDER BY total_revenue DESC;


-- 4.Average Fare per Kilometer by Service
SELECT 
    services,
    ROUND(AVG(fare_per_km),2) AS avg_fare_per_km
FROM rides
WHERE ride_status = 'completed'
GROUP BY services;

-- 5.Peak Ride Hours
SELECT 
    ride_hour,
    COUNT(*) AS total_rides
FROM rides
WHERE ride_status = 'completed'
GROUP BY ride_hour
ORDER BY total_rides DESC;


--  6.Busiest Days of the Week
SELECT 
    ride_day,
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed'
GROUP BY ride_day
ORDER BY total_revenue DESC;


-- 7.Revenue Lost Due to Cancellations
SELECT 
    SUM(ride_charge) AS potential_revenue,
    (SELECT SUM(total_fare) FROM rides WHERE ride_status='completed') AS actual_revenue,
    SUM(ride_charge) - (SELECT SUM(total_fare) FROM rides WHERE ride_status='completed') AS revenue_lost
FROM rides
WHERE ride_status='cancelled';


-- 8.Top Payment Methods
SELECT 
    payment_method,
    COUNT(*) AS total_rides,
    SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed'
GROUP BY payment_method
ORDER BY total_revenue DESC;


-- 9.Most Common Source-Destination Routes
SELECT 
    source, destination,
    COUNT(*) AS ride_count
FROM rides
WHERE ride_status = 'completed'
GROUP BY source, destination
ORDER BY ride_count DESC
LIMIT 10;


-- 10.Avg Ride Duration and Distance by Service
SELECT 
    services,
    ROUND(AVG(duration),2) AS avg_duration_min,
    ROUND(AVG(distance),2) AS avg_distance_km
FROM rides
WHERE ride_status = 'completed'
GROUP BY services; 


-- Step 6: Stored Procedures 
-- Procedure 1 — Daily Summary

DELIMITER $$
CREATE PROCEDURE daily_summary(IN target_date DATE)
BEGIN
    SELECT 
        ride_date,
        COUNT(*) AS total_rides,
        SUM(total_fare) AS total_revenue,
        AVG(total_fare) AS avg_fare
    FROM rides
    WHERE ride_date = target_date
      AND ride_status = 'completed'
    GROUP BY ride_date;
END $$
DELIMITER ;

-- Example call:
CALL daily_summary('2024-07-15');


-- Procedure 2 — Service Report
DELIMITER $$
CREATE PROCEDURE service_report()
BEGIN
    SELECT 
        services,
        COUNT(*) AS total_rides,
        SUM(total_fare) AS total_revenue,
        AVG(duration) AS avg_duration,
        AVG(distance) AS avg_distance
    FROM rides
    WHERE ride_status = 'completed'
    GROUP BY services;
END $$
DELIMITER ;

CALL service_report();


-- Procedure 3 — Payment Breakdown
DELIMITER $$
CREATE PROCEDURE payment_breakdown()
BEGIN
    SELECT 
        payment_method,
        COUNT(*) AS rides,
        SUM(total_fare) AS revenue
    FROM rides
    WHERE ride_status='completed'
    GROUP BY payment_method;
END $$
DELIMITER ;

CALL payment_breakdown();


select count(*) from rides;






