-- Average Age of Competitors Who Have Won at Least One Medal, Grouped by the Type of Medal They Won

SELECT
    m.medal_name,
    AVG(g.age) AS average_age
FROM
    olympics.medal m
JOIN
    olympics.competitor_event ce ON m.id = ce.medal_id
JOIN
    olympics.games_competitor g ON ce.competitor_id = g.person_id
GROUP BY
    m.medal_name;

-- Identify the Top 5 Regions with the Highest Number of Unique Competitors Who Have Participated in More Than 3 Different Events 

WITH Competitors_More_Than_Three_Events AS (
    SELECT
        g.person_id,
        COUNT(DISTINCT e.id) AS event_count
    FROM
        olympics.games_competitor g
    JOIN
        olympics.competitor_event ce ON g.person_id = ce.competitor_id
    JOIN
        olympics.event e ON ce.event_id = e.id
    GROUP BY
        g.person_id
    HAVING
        COUNT(DISTINCT e.id) > 3
),
Competitors_Per_Region AS (
    SELECT
        p.region_id,
        COUNT(DISTINCT c.person_id) AS unique_competitors
    FROM
        Competitors_More_Than_Three_Events c
    JOIN
        olympics.person_region p ON c.person_id = p.person_id
    GROUP BY
        p.region_id
)
SELECT
    nr.region_name,
    c.unique_competitors
FROM
    Competitors_Per_Region c
JOIN
    olympics.noc_region nr ON c.region_id = nr.id
ORDER BY
    c.unique_competitors DESC
LIMIT 5;

-- Create a Temporary Table to Store the Total Number of Medals Won by Each Competitor and Filter to Show Only Those Who Have Won More Than 2 Medals 

-- Create the temporary table
CREATE TEMP TABLE Temp_Competitor_Medals AS
SELECT
    g.person_id,
    COUNT(ce.medal_id) AS total_medals
FROM
    olympics.competitor_event ce
JOIN
    olympics.games_competitor g ON ce.competitor_id = g.person_id
GROUP BY
    g.person_id;

-- Query to filter competitors with more than 2 medals
SELECT
    p.full_name,
    t.total_medals
FROM
    Temp_Competitor_Medals t
JOIN
    olympics.person p ON t.person_id = p.id
WHERE
    t.total_medals > 2;

-- Use a Subquery Within a DELETE Statement to Remove Records of Competitors Who Have Not Won Any Medals from a Temporary Table Created for Analysis

DELETE FROM
    Temp_Competitor_Medals
WHERE
    person_id NOT IN (
        SELECT
            ce.competitor_id
        FROM
            olympics.competitor_event ce
    );