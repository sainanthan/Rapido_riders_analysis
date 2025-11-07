## 🚴‍♂️ Rapido Riders Analysis Dashboard
![Image]()
## 📘 Project Overview
This project analyzes Rapido ride data to extract operational and commercial insights.  
We use **MySQL** for data ingestion, cleaning, transformation and analytical queries, and **Power BI** for interactive visualizations and dashboarding.
**Primary goals**
- Understand ride demand patterns (hour/day/city).  
- Measure revenue and losses (including cancellations).  
- Identify high-value routes and payment preferences.  
- Provide actionable recommendations for operations and pricing.

---

## 🛠️ Tools & Artifacts
- **MySQL** — schema, cleaning, transformations, views, stored procedures.  
- **Power BI Desktop** — interactive dashboards (2 pages).  
- **CSV** — `rides_cleaned.csv` (final cleaned dataset exported from MySQL).  
- **Presentation** — `Rapido_Analysis_PPT.pptx`.  
- **Repository structure** (see lower down).

---

## 📂 Dataset
**File:** `data/rides_cleaned.csv`  
**Example columns:**  
`services, date, time, ride_status, source, destination, duration, ride_id, distance, ride_charge, misc_charge, total_fare, payment_method, ...`


---

## ⚙️ Reproducible Setup — MySQL (Quick)
1. Create database and table:
```sql
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
```
---

## Import CSV (local file):
```sql
LOAD DATA LOCAL INFILE '/path/to/rides_cleaned.csv'
INTO TABLE rides
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(services, @datecol, @timecol, ride_status, source, destination, duration, ride_id, distance, ride_charge, misc_charge, total_fare, payment_method)
SET date = STR_TO_DATE(@datecol, '%Y-%m-%d'),
    time = TIME(@timecol);
```
---

## 🧹 Data Cleaning & Validation:
1.Check null counts:
```sql
SELECT 
  SUM(ride_charge IS NULL) AS null_ride_charge,
  SUM(total_fare IS NULL) AS null_total_fare,
  SUM(payment_method IS NULL) AS null_payment_method
FROM rides;
```
2.Remove duplicates (if any):
```sql
DELETE r1 FROM rides r1
JOIN rides r2
  ON r1.ride_id = r2.ride_id
  AND r1.rowid > r2.rowid; -- adapt if rowid not present
```

3.Fill fares for cancelled rows (option A: set to 0):
```sql
UPDATE rides
SET ride_charge = COALESCE(ride_charge,0),
    misc_charge = COALESCE(misc_charge,0),
    total_fare = COALESCE(total_fare,0)
WHERE ride_status = 'cancelled';
```

4.Validate numeric ranges:
```sql
SELECT * FROM rides WHERE distance <= 0 OR duration < 0;
```
---

## ✨ Feature Engineering (SQL):
```sql
ALTER TABLE rides ADD COLUMN ride_hour TINYINT;
ALTER TABLE rides ADD COLUMN ride_day VARCHAR(10);
ALTER TABLE rides ADD COLUMN fare_per_km DECIMAL(10,2);
ALTER TABLE rides ADD COLUMN route VARCHAR(255);

UPDATE rides
SET ride_hour = HOUR(time),
    ride_day = DAYNAME(date),
    fare_per_km = CASE WHEN distance > 0 THEN ROUND(total_fare / distance,2) ELSE 0 END,
    route = CONCAT(source, ' → ', destination);
```
---

## 🧮 SQL Queries — Business Problems
1) Total Rides & Total Revenue:
```sql
SELECT
  COUNT(*) AS total_rides,
  SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed';
```

2) Cancelled vs Completed Rides (counts & percent)
```sql
SELECT
  ride_status,
  COUNT(*) AS ride_count,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM rides), 2) AS pct_of_total
FROM rides
GROUP BY ride_status;
```

3) Top Performing Services by Revenue
```sql
SELECT
  services,
  COUNT(*) AS total_rides,
  SUM(total_fare) AS total_revenue,
  ROUND(AVG(total_fare),2) AS avg_fare
FROM rides
WHERE ride_status = 'completed'
GROUP BY services
ORDER BY total_revenue DESC;
```

4) Average Fare per Kilometer by Service
```sql
SELECT
  services,
  ROUND(AVG(fare_per_km),2) AS avg_fare_per_km
FROM rides
WHERE ride_status = 'completed'
GROUP BY services
ORDER BY avg_fare_per_km DESC;
```

5) Peak Ride Hours
```sql
SELECT
  ride_hour,
  COUNT(*) AS total_rides
FROM rides
WHERE ride_status = 'completed'
GROUP BY ride_hour
ORDER BY total_rides DESC;
```


6) Busiest Days of Week (rides + revenue)
```sql
SELECT
  ride_day,
  COUNT(*) AS total_rides,
  SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed'
GROUP BY ride_day
ORDER BY total_revenue DESC;
```

7) Revenue Lost Due to Cancellations

Two ways: (A) Sum of cancelled fares, (B) difference approach.

-- A: cancelled revenue
```sql
SELECT SUM(total_fare) AS cancelled_revenue
FROM rides
WHERE ride_status = 'cancelled';
```

-- B: potential revenue (if ride_charge is pre-billing) vs actual revenue
```sql
SELECT 
  SUM(ride_charge) AS potential_revenue_from_cancelled,
  (SELECT SUM(total_fare) FROM rides WHERE ride_status='completed') AS actual_completed_revenue,
  SUM(ride_charge) - (SELECT SUM(total_fare) FROM rides WHERE ride_status='completed') AS revenue_lost_estimate
FROM rides
WHERE ride_status = 'cancelled';
```

8) Top Payment Methods
```sql
SELECT
  payment_method,
  COUNT(*) AS total_rides,
  SUM(total_fare) AS total_revenue
FROM rides
WHERE ride_status = 'completed'
GROUP BY payment_method
ORDER BY total_revenue DESC;
```

9) Most Common Source–Destination Routes (Top 10)
```sql
SELECT route, COUNT(*) AS ride_count
FROM rides
WHERE ride_status = 'completed'
GROUP BY route
ORDER BY ride_count DESC
LIMIT 10;
```

10) Average Ride Duration and Distance by Service
```sql
SELECT
  services,
  ROUND(AVG(duration),2) AS avg_duration_min,
  ROUND(AVG(distance),2) AS avg_distance_km
FROM rides
WHERE ride_status = 'completed'
GROUP BY services
ORDER BY avg_duration_min DESC;
```
---

## 🧰 Stored Procedures
-- Procedure 1 — Daily Summary
```sql
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
```

-- Procedure 2 — Service Report
```sql
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
```

-- Procedure 3 — Payment Breakdown
```sql
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
```
---

## 📈 Insights & Visualizations:
**Page 1**
– Ride Performance Overview
- Total Rides, Total Revenue, Avg Fare
- Revenue by Service Type
- Rides by Time & Day
![image](https://github.com/sainanthan/Rapido_riders_analysis/blob/main/ride_performance_overiew.png)

**Page 2** 
– Business & Operations Insights
- Payment Method Trends
- Cancellation Rate
- Common Routes
- Revenue Lost from Cancellations
![image](https://github.com/sainanthan/Rapido_riders_analysis/blob/main/business_operations_insight.png)

---
## 💡 Key Business Recommendations:
- 1️⃣ Optimize Driver Allocation: Increase active riders in high-demand hours and routes.
- 2️⃣ Encourage Digital Payments: Offer UPI cashback/rewards to boost seamless payments.
- 3️⃣ Reduce Cancellations: Introduce penalties or AI-based ETA improvements.
- 4️⃣ Dynamic Pricing: Adjust fares during off-peak hours to increase ridership.
- 5️⃣ Customer Loyalty Program: Reward frequent riders to improve retention.
- 6️⃣ Operational Monitoring: Automate real-time tracking of ride completion rate.
