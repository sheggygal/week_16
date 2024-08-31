--Detailed Medal Analysis

-- Identify Competitors with Medals in Both Summer and Winter Olympics
-- Step 1: Create a temporary table to store competitors and their medal counts for each season
CREATE TEMP TABLE competitor_medal_counts AS
WITH competitor_medals AS (
    SELECT
        gc.person_id,
        g.season,
        COUNT(me.id) AS medal_count
    FROM olympics.games_competitor gc
    JOIN olympics.games g ON gc.games_id = g.id
    JOIN olympics.competitor_event ce ON gc.person_id = ce.competitor_id
    JOIN olympics.medal me ON ce.Medal_id = me.id
    GROUP BY gc.person_id, g.season
),
summer_winter_competitors AS (
    SELECT
        person_id,
        SUM(CASE WHEN season = 'Summer' THEN medal_count ELSE 0 END) AS summer_medals,
        SUM(CASE WHEN season = 'Winter' THEN medal_count ELSE 0 END) AS winter_medals
    FROM competitor_medals
    GROUP BY person_id
    HAVING SUM(CASE WHEN season = 'Summer' THEN 1 ELSE 0 END) > 0
       AND SUM(CASE WHEN season = 'Winter' THEN 1 ELSE 0 END) > 0
)
SELECT
    p.full_name,
    s.summer_medals,
    w.winter_medals
FROM summer_winter_competitors sw
JOIN olympics.person p ON sw.person_id = p.id
LEFT JOIN LATERAL (
    SELECT SUM(medal_count) AS summer_medals
    FROM competitor_medals
    WHERE person_id = sw.person_id AND season = 'Summer'
) s ON TRUE
LEFT JOIN LATERAL (
    SELECT SUM(medal_count) AS winter_medals
    FROM competitor_medals
    WHERE person_id = sw.person_id AND season = 'Winter'
) w ON TRUE;

-- Step 2: Display the contents of the temporary table
SELECT * FROM competitor_medal_counts;

-- Competitors with Medals in Exactly Two Different Sports
-- Step 1: Create a temporary table to store competitors with medals in exactly two different sports
-- Using CTEs for clarity
WITH competitor_sports AS (
    SELECT
        gc.person_id,
        COUNT(DISTINCT e.sport_id) AS sports_count
    FROM olympics.games_competitor gc
    JOIN olympics.competitor_event ce ON gc.person_id = ce.competitor_id
    JOIN olympics.event e ON ce.event_id = e.id
    JOIN olympics.medal me ON ce.Medal_id = me.id
    GROUP BY gc.person_id
    HAVING COUNT(DISTINCT e.sport_id) = 2
),
competitor_medals AS (
    SELECT
        gc.person_id,
        COUNT(me.id) AS total_medals
    FROM olympics.games_competitor gc
    JOIN olympics.competitor_event ce ON gc.person_id = ce.competitor_id
    JOIN olympics.medal me ON ce.Medal_id = me.id
    GROUP BY gc.person_id
)
SELECT
    p.full_name,
    cm.total_medals
FROM competitor_sports cts
JOIN olympics.person p ON cts.person_id = p.id
JOIN competitor_medals cm ON cts.person_id = cm.person_id
ORDER BY cm.total_medals DESC
LIMIT 3;

-- Region and Competitor Performance

--  Retrieve the Regions with Competitors Who Have Won the Highest Number of Medals in a Single Olympic Event
-- Subquery to find the highest number of medals won by each competitor in a single event
WITH Max_Medals_Per_Event AS (
    SELECT
        gc.person_id,
        e.id AS event_id,
        COUNT(ce.Medal_id) AS medals_count
    FROM olympics.games_competitor gc
    JOIN olympics.competitor_event ce ON gc.person_id = ce.competitor_id
    JOIN olympics.event e ON ce.event_id = e.id
    GROUP BY gc.person_id, e.id
),
Max_Medals_Per_Competitor AS (
    SELECT
        person_id,
        MAX(medals_count) AS max_medals
    FROM Max_Medals_Per_Event
    GROUP BY person_id
),
Competitors_With_Max_Medals AS (
    SELECT
        mp.person_id,
        mp.max_medals,
        pr.region_id
    FROM Max_Medals_Per_Competitor mp
    JOIN olympics.person_region pr ON mp.person_id = pr.person_id
),
Region_Medals_Count AS (
    SELECT
        nr.region_name,
        SUM(cwmm.max_medals) AS total_medals
    FROM Competitors_With_Max_Medals cwmm
    JOIN olympics.noc_region nr ON cwmm.region_id = nr.id
    GROUP BY nr.region_name
)
-- Display the top 5 regions with the highest total medals
SELECT
    region_name,
    total_medals
FROM Region_Medals_Count
ORDER BY total_medals DESC
LIMIT 5;

-- Create a Temporary Table for Competitors Who Have Participated in More Than Three Olympic Games but Have Not Won Any Medals
-- Create the temporary table
CREATE TEMP TABLE competitors_no_medals AS
WITH Competitor_Games AS (
    SELECT
        gc.person_id,
        COUNT(DISTINCT gc.games_id) AS games_count
    FROM olympics.games_competitor gc
    GROUP BY gc.person_id
    HAVING COUNT(DISTINCT gc.games_id) > 3
),
Competitor_Medals AS (
    SELECT
        ce.competitor_id
    FROM olympics.competitor_event ce
    JOIN olympics.medal me ON ce.Medal_id = me.id
    GROUP BY ce.competitor_id
),
Competitors_No_Medals AS (
    SELECT
        p.id AS person_id,
        p.full_name,
        cg.games_count
    FROM Competitor_Games cg
    LEFT JOIN Competitor_Medals cm ON cg.person_id = cm.competitor_id
    JOIN olympics.person p ON cg.person_id = p.id
    WHERE cm.competitor_id IS NULL
)
-- Insert data into the temporary table
SELECT
    full_name,
    games_count
FROM Competitors_No_Medals;

-- Display the contents of the temporary table
SELECT * FROM competitors_no_medals;
