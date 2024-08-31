-- Update the Heights of Competitors Based on the Average Height of Competitors from the Same Region

UPDATE olympics.person p
SET height = avg_height.avg_height
FROM (
    SELECT 
        pr.person_id,
        AVG(p2.height) AS avg_height
    FROM olympics.person p2
    JOIN olympics.person_region pr ON p2.id = pr.person_id
    JOIN olympics.noc_region nr ON pr.region_id = nr.id
    JOIN olympics.person_region pr1 ON nr.id = pr1.region_id
    WHERE pr1.person_id = p2.id
    GROUP BY pr.person_id
) avg_height
WHERE p.id = avg_height.person_id;

-- Insert New Records into a Temporary Table for Competitors Who Participated in More Than One Event in the Same Games

-- Create the temporary table
CREATE TEMP TABLE Temp_Competitors_Multiple_Events AS
WITH Event_Counts AS (
    SELECT
        g.person_id,
        g.games_id,
        COUNT(DISTINCT ce.event_id) AS event_count
    FROM
        olympics.games_competitor g
    JOIN
        olympics.competitor_event ce ON g.person_id = ce.competitor_id
    GROUP BY
        g.person_id, g.games_id
)
SELECT
    person_id,
    COUNT(*) AS total_events_participated
FROM
    Event_Counts
WHERE
    event_count > 1
GROUP BY
    person_id;

-- Identify Regions Where the Average Number of Medals Won Per Competitor is Greater Than the Overall Average

WITH Competitor_Medals AS (
    SELECT
        g.person_id,
        COUNT(ce.medal_id) AS medal_count
    FROM
        olympics.games_competitor g
    JOIN
        olympics.competitor_event ce ON g.person_id = ce.competitor_id
    GROUP BY
        g.person_id
),
Medals_Per_Region AS (
    SELECT
        pr.region_id,
        AVG(cm.medal_count) AS avg_medals_per_competitor
    FROM
        Competitor_Medals cm
    JOIN
        olympics.person_region pr ON cm.person_id = pr.person_id
    GROUP BY
        pr.region_id
),
Overall_Avg_Medals AS (
    SELECT
        AVG(medal_count) AS overall_avg
    FROM
        Competitor_Medals
)
SELECT
    nr.region_name
FROM
    Medals_Per_Region mpr
JOIN
    olympics.noc_region nr ON mpr.region_id = nr.id
JOIN
    Overall_Avg_Medals oam ON mpr.avg_medals_per_competitor > oam.overall_avg;

-- Create a Temporary Table to Track Competitors’ Participation Across Different Seasons and Identify Those Who Have Participated in Both Summer and Winter Games
-- Create a temporary table to track competitors' participation across different seasons
CREATE TEMP TABLE competitor_season_participation AS
SELECT
    gc.person_id,
    MIN(g.season) AS min_season,
    MAX(g.season) AS max_season
FROM olympics.games_competitor gc
JOIN olympics.games g ON gc.games_id = g.id
GROUP BY gc.person_id;

-- Step 2: Identify competitors who have participated in both Summer and Winter games
SELECT
    p.full_name,
    csp.min_season,
    csp.max_season
FROM competitor_season_participation csp
JOIN olympics.person p ON csp.person_id = p.id
WHERE csp.min_season <> csp.max_season; 



