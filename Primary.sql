SELECT city_name, Total_trips 
FROM (
    SELECT 
        dc.city_name, 
        COUNT(ft.trip_id) AS Total_trips, 
        ROW_NUMBER() OVER (ORDER BY COUNT(ft.trip_id) DESC) AS rn_desc,
        ROW_NUMBER() OVER (ORDER BY COUNT(ft.trip_id) ASC) AS rn_asc
    FROM dim_city dc
    JOIN fact_trips ft
        ON dc.city_id = ft.city_id
    GROUP BY dc.city_name
) ranked
WHERE rn_desc <= 3 OR rn_asc <= 3
ORDER BY rn_desc, rn_asc;

-- Q2 AVerage fare per trip by city

SELECT dc.city_name, round(AVG(fare_amount),0) AS avg_fare, ROUND(avg(ft.distance_travelled_km)) AS avg_distance FROM dim_city dc
JOIN fact_trips ft
	ON dc.city_id = ft.city_id
GROUP BY dc.city_name
ORDER BY avg_fare DESC;

-- Q3

SELECT dc.city_name, ft.passenger_type, ROUND(avg(passenger_rating),0) AS Passenger_rating, ROUND(AVG(ft.driver_rating),0) AS Driver_rating FROM dim_city dc
JOIN fact_trips ft
	ON dc.city_id = ft.city_id
GROUP BY dc.city_name, ft.passenger_type
ORDER BY passenger_rating DESC;

-- Q4

WITH Trips_month AS (
SELECT dc.city_name AS city_name, monthname(date) AS month, COUNT(trip_id) AS Total_trips FROM dim_city dc
JOIN fact_trips ft
	ON dc.city_id = ft.city_id
GROUP BY 1,2
), to_trips AS(
SELECT *,
	RANK() OVER(partition by city_name ORDER BY Total_trips DESC) as max_trips,
    RANK() OVER(partition by city_name ORDER BY Total_trips ASC) as min_trips

 FROM Trips_month
 )
 
 SELECT city_name, month, Total_trips FROM to_trips
 WHERE max_trips = 1 OR min_trips = 1
 ORDER BY city_name , Total_trips DESC;
 
 -- Q5
 
WITH city_table AS (SELECT dc.city_name, ft.* FROM dim_city dc
JOIN fact_trips ft
	ON dc.city_id = ft.city_id
)
SELECT ct.city_name, dd.day_type , COUNT(ct.trip_id) 
FROM city_table ct
JOIN dim_date dd
	ON ct.date = dd.date 
GROUP BY ct.city_name, dd.day_type
ORDER BY 
    ct.city_name, 
    dd.day_type;

-- Q6


WITH ttrips AS(SELECT city_id, SUM(repeat_passenger_count) AS total_trips FROM dim_repeat_trip_distribution
GROUP BY 1
)
SELECT dd.*, ROUND((repeat_passenger_count/total_trips)*100,2) AS `% of repeat people trips`, tt.total_trips FROM ttrips tt
JOIN dim_repeat_trip_distribution dd
ON tt.city_id = dd.city_id
ORDER BY `% of repeat people trips` desc, dd.city_id;


SET SESSION wait_timeout = 300;
SET GLOBAL max_allowed_packet = 16777216;  -- 16MB (adjust as necessary)
SET GLOBAL net_read_timeout = 600;
SET GLOBAL net_write_timeout = 600;
SET GLOBAL wait_timeout = 28800;  -- 8 hours
SET GLOBAL interactive_timeout = 28800;  -- 8 hours

-- Q7

WITH CTE_Targets AS (
    SELECT 
        dc.city_name,
        tt.month AS target_month,
        tt.total_target_trips,
        np.target_new_passengers,
        pr.target_avg_passenger_rating
    FROM targets_db.monthly_target_trips tt
    JOIN trips_db.dim_city dc
        ON tt.city_id = dc.city_id
    LEFT JOIN targets_db.monthly_target_new_passengers np
        ON tt.city_id = np.city_id AND tt.month = np.month
    LEFT JOIN targets_db.city_target_passenger_rating pr
        ON tt.city_id = pr.city_id
),
CTE_Actuals AS (
    SELECT 
        dc.city_name,
        DATE_FORMAT(ft.date, '%Y-%m') AS actual_month,
        COUNT(ft.trip_id) AS total_trips,
        SUM(CASE WHEN ft.passenger_type = 'NEW' THEN 1 ELSE 0 END) AS new_passengers,
        ROUND(AVG(ft.passenger_rating), 2) AS avg_passenger_rating
    FROM trips_db.fact_trips ft
    JOIN trips_db.dim_city dc
        ON ft.city_id = dc.city_id
    GROUP BY dc.city_name, DATE_FORMAT(ft.date, '%Y-%m')
)
SELECT 
    t.city_name,
    DATE_FORMAT(t.target_month, '%Y-%m') AS target_month,
    a.actual_month,
    t.total_target_trips AS target_total_trips,
    a.total_trips AS actual_total_trips,
    (a.total_trips - t.total_target_trips) AS trip_difference,
    CASE 
        WHEN a.total_trips >= t.total_target_trips THEN 'Met or Exceeded'
        ELSE 'Missed'
    END AS trip_status,
    t.target_new_passengers,
    a.new_passengers AS actual_new_passengers,
    (a.new_passengers - t.target_new_passengers) AS passenger_difference,
    CASE 
        WHEN a.new_passengers >= t.target_new_passengers THEN 'Met or Exceeded'
        ELSE 'Missed'
    END AS passenger_status,
    t.target_avg_passenger_rating,
    a.avg_passenger_rating AS actual_avg_passenger_rating,
    (a.avg_passenger_rating - t.target_avg_passenger_rating) AS rating_difference,
    CASE 
        WHEN a.avg_passenger_rating >= t.target_avg_passenger_rating THEN 'Met or Exceeded'
        ELSE 'Missed'
    END AS rating_status
FROM CTE_Targets t
LEFT JOIN CTE_Actuals a
    ON t.city_name = a.city_name AND DATE_FORMAT(t.target_month, '%Y-%m') = a.actual_month;
