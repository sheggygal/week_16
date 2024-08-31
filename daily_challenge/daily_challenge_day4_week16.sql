-- Calculate the Average Budget Growth Rate for Each Production Company --
WITH Budget_Growth_Rate AS (
    SELECT
        pc.company_name,
        m.movie_id,
        m.budget,
        LAG(m.budget) OVER (
            PARTITION BY pc.company_name
            ORDER BY m.release_date
        ) AS previous_budget,
        (m.budget - LAG(m.budget) OVER (
            PARTITION BY pc.company_name
            ORDER BY m.release_date
        )) / NULLIF(LAG(m.budget) OVER (
            PARTITION BY pc.company_name
            ORDER BY m.release_date
        ), 0) AS growth_rate
    FROM
        movies.movie m
    JOIN
        movies.movie_company mc ON m.movie_id = mc.movie_id
    JOIN
        movies.production_company pc ON mc.company_id = pc.company_id
),
Average_Growth_Rate AS (
    SELECT
        company_name,
        AVG(growth_rate) AS avg_growth_rate
    FROM
        Budget_Growth_Rate
    WHERE
        previous_budget IS NOT NULL  -- Exclude the first movie where previous_budget is NULL
    GROUP BY
        company_name
)
SELECT
    company_name,
    avg_growth_rate
FROM
    Average_Growth_Rate
ORDER BY
    avg_growth_rate DESC;


-- Determine the Most Consistently High-Rated Actor --
WITH Average_Rating AS (
    SELECT
        AVG(vote_average) AS avg_rating
    FROM 
        movies.movie
),
High_Rated_Movies AS (
    SELECT
        m.movie_id,
        m.vote_average
    FROM
        movies.movie m
    JOIN
        Average_Rating ar ON m.vote_average > ar.avg_rating
),
Actor_High_Rated_Movies AS (
    SELECT
        p.person_name AS actor_name,
        COUNT(DISTINCT hm.movie_id) AS high_rated_movies_count
    FROM 
        High_Rated_Movies hm
    JOIN 
        movies.movie_cast mc ON hm.movie_id = mc.movie_id
    JOIN 
        movies.person p ON mc.person_id = p.person_id
    GROUP BY 
        p.person_name
),
Ranked_Actors AS (
    SELECT
        actor_name,
        high_rated_movies_count,
        RANK() OVER (ORDER BY high_rated_movies_count DESC) AS rank
    FROM 
        Actor_High_Rated_Movies
)
SELECT 
    actor_name,
    high_rated_movies_count
FROM 
    Ranked_Actors
WHERE 
    rank = 1
ORDER BY 
    high_rated_movies_count DESC;

-- Calculate the Rolling Average Revenue for Each Genre --
WITH Ranked_Movies AS (
    SELECT
        g.genre_name,
        m.movie_id,
        m.revenue,
        m.release_date,
        ROW_NUMBER() OVER (
            PARTITION BY g.genre_name
            ORDER BY m.release_date DESC
        ) AS rn
    FROM 
        movies.movie m
    JOIN 
        movies.movie_genres mg ON m.movie_id = mg.movie_id
    JOIN 
        movies.genre g ON mg.genre_id = g.genre_id
),
Recent_Movies AS (
    SELECT
        genre_name,
        movie_id,
        revenue,
        release_date
    FROM
        Ranked_Movies
    WHERE
        rn <= 3  -- Filter to include only the 3 most recent movies
),
Rolling_Avg_Revenue AS (
    SELECT
        genre_name,
        movie_id,
        revenue,
        release_date,
        AVG(revenue) OVER (
            PARTITION BY genre_name
            ORDER BY release_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_avg_revenue
    FROM
        Recent_Movies
)
SELECT
    genre_name,
    movie_id,
    revenue,
    release_date,
    rolling_avg_revenue
FROM
    Rolling_Avg_Revenue
ORDER BY
    genre_name,
    release_date DESC;

-- Identify the Highest-Grossing Movie Series --
WITH Movie_Keyword_Revenue AS (
    SELECT
        k.keyword_name AS series_name,
        m.title AS movie_title,
        m.revenue
    FROM
        movies.movie m
    JOIN
        movies.movie_keywords mk ON m.movie_id = mk.movie_id
    JOIN
        movies.keyword k ON mk.keyword_id = k.keyword_id
    WHERE
        k.keyword_name ILIKE '%series%' -- Filter for keywords containing 'series'
),
Series_Revenue AS (
    SELECT
        series_name,
        SUM(revenue) AS total_revenue
    FROM
        Movie_Keyword_Revenue
    GROUP BY
        series_name
),
Ranked_Series AS (
    SELECT
        series_name,
        total_revenue,
        RANK() OVER (ORDER BY total_revenue DESC) AS rank
    FROM
        Series_Revenue
)
SELECT
    mkr.series_name,
    mkr.movie_title,
    sr.total_revenue
FROM
    Movie_Keyword_Revenue mkr
JOIN
    Ranked_Series sr ON mkr.series_name = sr.series_name
WHERE
    sr.rank = 1;






