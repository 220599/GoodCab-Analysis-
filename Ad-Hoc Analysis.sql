SELECT * FROM dim_city dc
JOIN fact_trips ft
ON dc.city_id = ft.city_id;


-- Q1 City Level Fare and Trip Summary Report
SELECT dc.city_name, 
	COUNT(ft.trip_id) AS total_trips, 
    ROUND(AVG((ft.fare_amount)/(ft.distance_travelled_km)),0)  AS avg_fare_per_Km,
	ROUND(AVG(ft.fare_amount),0) AS avg_fare_per_trip, 
	ROUND(COUNT(ft.trip_id) * 100 / (SELECT COUNT(trip_id) FROM fact_trips),2) AS `%_contribution_to_total_trips`
FROM dim_city dc
JOIN fact_trips ft
	ON dc.city_id = ft.city_id
GROUP BY dc.city_name
ORDER BY total_trips DESC;

-- Q2 Monthly City-Level Trips target Performance Report

WITH month_city AS (
SELECT dc.city_name, monthname(ft.date) AS monthName,
	COUNT(ft.trip_id) AS total_trips
FROM dim_city dc
JOIN fact_trips ft
	ON dc.city_id = ft.city_id
GROUP BY dc.city_name, monthname(ft.date)
),
 ttarget AS (SELECT dc.city_name,
 monthname(mt.month) AS monthName, 
 SUM(total_target_trips) AS target_trips
 FROM targets_db.monthly_target_trips mt
left JOIN dim_city dc
	ON dc.city_id = mt.city_id
GROUP BY dc.city_name, mt.month
ORDER BY city_name
)


SELECT month_city.city_name, 
month_city.monthName, 
month_city.total_trips AS actual_trips, 
tt.target_trips, 
CASE
	WHEN (month_city.total_trips > tt.target_trips) THEN "Above Target"
    ELSE 'Below Target'
END AS performance_status,
ROUND(((month_city.total_trips-tt.target_trips)/tt.target_trips *100),2) AS `%_difference`
FROM month_city 
JOIN ttarget tt
	ON month_city.city_name = tt.city_name AND month_city.monthName = tt.monthName ;
    
    
    
-- Q4

WITH ranked_cities AS (
    SELECT 
        dc.city_name,
        SUM(fs.new_passengers) AS total_new_passengers,
        RANK() OVER (ORDER BY SUM(fs.new_passengers) DESC) AS city_rank
    FROM 
        fact_passenger_summary fs
    JOIN 
        dim_city dc
    ON 
        fs.city_id = dc.city_id
    GROUP BY 
        dc.city_name
),
categorized_cities AS (
    SELECT 
        city_name,
        total_new_passengers,
        city_rank,
        CASE
            WHEN city_rank <= 3 THEN 'Top 3'
            WHEN city_rank > (SELECT MAX(city_rank) - 3 FROM ranked_cities) THEN 'Bottom 3'
            ELSE NULL
        END AS city_category
    FROM 
        ranked_cities
)
SELECT 
    city_name,
    total_new_passengers,
    city_rank,
    city_category
FROM 
    categorized_cities
ORDER BY 
    city_rank;
 
 
 
 
 
 -- Q-5 Identify Month with Highest Revenue for Each City 
 

WITH rev_month AS(
SELECT 
	dc.city_name,
    monthname(date) AS months,
    sum(fare_amount) AS Total_rev
FROM 
	fact_trips ft
JOIN dim_city dc
	ON dc.city_id = ft.city_id
GROUP BY 1, 2
ORDER BY Total_rev DESC)
,
rank_table  AS (
SELECT * ,
RANK() OVER(partition by city_name ORDER BY Total_rev DESC ) AS row_rank
FROM rev_month
),
group_city AS(
SELECT 
	city_name, SUM(Total_rev) AS TotalCityRev
FROM rev_month
GROUP BY city_name
)
SELECT 
	rt.city_name, 
    rt.months AS highest_revenue_month,  
    rt.Total_rev AS revenue, 
    ROUND((rt.Total_rev/gc.TotalCityRev)*100,2) AS `percentage_contribution (%)`
FROM rank_table rt
JOIN group_city gc
	ON rt.city_name  = gc.city_name
WHERE row_rank =1
ORDER BY Total_rev DESC
;

-- Q6 Repeat Passeneger Rate Analysis


WITH group_month AS (
SELECT 
	dc.city_name, 
    monthname(date) AS `month`,
    COUNT(trip_id) AS total_passengers,
	SUM(CASE WHEN ft.passenger_type = 'repeated' THEN 1 ELSE 0 END) AS repeat_passneger 
FROM fact_trips ft
JOIN dim_city dc 
	ON dc.city_id = ft.city_id
GROUP BY city_name, monthname(date)
),
City_wide_data AS (
SELECT city_name,
SUM(total_passengers) AS total_city_passengers,
SUM(repeat_passneger) AS total_city_repeat_passenegers 
FROM group_month
GROUP BY city_name
)
SELECT 
	gm.city_name,
    gm.month,
    gm.total_passengers,
	ROUND((repeat_passneger/total_passengers)*100,2) AS monthly_repeat_passenger_rate,
    ROUND((cd.total_city_repeat_passenegers/cd.total_city_passengers)*100,2) AS city_repeat_passenger_rate
FROM group_month gm
JOIN City_wide_data cd
	ON gm.city_name = cd.city_name

ORDER BY city_name, month
