-- 1.  DML/DDL: The dvdrental db already has a pre-populated data in it, 
-- but let's assume that the business is still running in which case we 
-- need to not only analyze existing data but also maintain the database 
-- mainly by INSERTing data for new rentals and UPDATEing the db for existing rentals
-- --i.e implementing DML (Data Manipulation Language). To this effect,
-- a.   Write ALL the queries we need to rent out a given movie. 
-- (Hint: these are the business logics that go into this task: 
-- first confirm that the given movie is in stock, and 
-- then INSERT a row into the rental and the payment tables. 
-- You may also need to check whether the customer has an outstanding balance or
-- an overdue rental before allowing him/her to rent a new DVD).
DO $$
DECLARE
    CURRENT_AMOUNT NUMERIC;
    MOVIE_PRICE NUMERIC;
    OVERDUE_RENTALS INT;
    CAN_RENT BOOL;
    INV_ID INTEGER[];
    rental_dur int;
  customer_pay int;
--   rent_id int;
  amount_cost int;
BEGIN
--     select rental_id into rent_id from payment
--   where customer_id = 41;

    select rental_duration into rental_dur
  from film where film_id = 11;

  select rental_rate into amount_cost
  from film where film_id = 11;

    SELECT ARRAY_AGG(INVENTORY_ID)
    INTO INV_ID
    FROM INVENTORY
    WHERE FILM_ID = 11
        AND STORE_ID = 1 OR STORE_ID = 2
        AND NOT EXISTS
            (SELECT 1
            FROM RENTAL
            WHERE INVENTORY_ID = INVENTORY.INVENTORY_ID
            AND RETURN_DATE IS NULL);

    SELECT SUM(amount)
    INTO CURRENT_AMOUNT
    FROM payment
    WHERE customer_id = 1;

    SELECT rental_rate
    INTO MOVIE_PRICE
    FROM film
    WHERE film_id = 11;

    SELECT COUNT(*)
    INTO OVERDUE_RENTALS
    FROM rental
    WHERE customer_id = 12
        AND return_date IS NULL
        AND rental_date < current_date - interval '3 days'; -- Define your overdue rental threshold


  SELECT customer_id
    INTO customer_pay
    FROM customer
    WHERE customer_id = 12;


IF CURRENT_AMOUNT > MOVIE_PRICE
AND OVERDUE_RENTALS = 0
AND COUNT(INV_ID) > 0 THEN
INSERT INTO RENTAL(RENTAL_DATE,

                          INVENTORY_ID,
                          CUSTOMER_ID,
                          RETURN_DATE,
                          STAFF_ID,
                          LAST_UPDATE)
VALUES(CAST(TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS timestamp), 403, 1, 
     CAST(CONCAT(CURRENT_DATE + RENTAL_DUR,' ',TO_CHAR(CURRENT_TIMESTAMP, 'HH24:MI:SS')) AS timestamp),1, 
     CAST(CONCAT(CURRENT_DATE + RENTAL_DUR,' ', TO_CHAR(CURRENT_TIMESTAMP, 'HH24:MI:SS')) AS timestamp));

   INSERT INTO payment
    (customer_id, staff_id, rental_id, amount, payment_date)
    VALUES(customer_pay, 1, 126,amount_cost , now());
        CAN_RENT := TRUE;
    ELSE
        CAN_RENT := FALSE;
    END IF;

    -- Output the result
    RAISE NOTICE 'Rented a new DVD: %', CAN_RENT;
    RAISE NOTICE 'Inv_ID: %', COUNT(INV_ID);
  RAISE NOTICE 'Inv_ID: %', rental_dur;

END $$;

-- select * from payment order by payment_id desc;
select * from rental order by rental_date desc;

-- select * from payment order by payment_id desc;

-- select * from payment order by payment_id desc;

-- b.  write ALL the queries we need to process return of a rented movie. 
-- (Hint: update the rental table and add the return date by first identifying 
--  the rental_id to update based on the inventory_id of the movie being returned.)
DO $$
DECLARE
  rentID INT;
BEGIN
  SELECT rental_id INTO rentID -- 2
  FROM rental
  WHERE inventory_id = 1525
    AND customer_id = 459
    AND return_date IS NOT NULL;

  -- Check if rentID has a valid value (not null) before proceeding with the update
  IF rentID IS NOT NULL THEN
    UPDATE rental
    SET return_date = CURRENT_DATE
    WHERE rental_id = rentID;
  END IF;
END $$;

-- select * from rental where inventory_id = 1525 and customer_id = 459



-- 2. DQL: Now that we have an up-to-date database, let's write some queries and 
-- analyze the data to understand how our DVD rental business is performing so far.
-- a. Which movie genres are the most and least popular?
-- And how much revenue have they each generated for the business?

SELECT FC.CATEGORY_ID,
	C.NAME AS GENRE,
	COUNT(*) AS RENTAL_COUNT,
	SUM(P.AMOUNT) AS TOTAL_REVENUE
FROM FILM_CATEGORY AS FC
JOIN CATEGORY AS C ON FC.CATEGORY_ID = C.CATEGORY_ID
JOIN FILM AS F ON FC.FILM_ID = F.FILM_ID
LEFT JOIN INVENTORY AS I ON F.FILM_ID = I.FILM_ID
LEFT JOIN RENTAL AS R ON I.INVENTORY_ID = R.INVENTORY_ID
LEFT JOIN PAYMENT AS P ON R.RENTAL_ID = P.RENTAL_ID
GROUP BY FC.CATEGORY_ID,
	C.NAME
ORDER BY RENTAL_COUNT DESC;

-- b. What are the top 10 most popular movies?
-- And how many times have they each been rented out thus far?

SELECT F.TITLE AS MOVIE_TITLE,
	COUNT(R.RENTAL_ID) AS RENTAL_COUNT
FROM FILM AS F
JOIN INVENTORY AS I ON F.FILM_ID = I.FILM_ID
JOIN RENTAL AS R ON I.INVENTORY_ID = R.INVENTORY_ID
GROUP BY F.TITLE
ORDER BY RENTAL_COUNT DESC
LIMIT 10;

-- c. Which genres have the highest and the lowest average rental rate?

SELECT C.NAME AS GENRE,
	AVG(F.RENTAL_RATE) AS AVG_RENTAL_RATE
FROM FILM AS F
JOIN FILM_CATEGORY AS FC ON F.FILM_ID = FC.FILM_ID
JOIN CATEGORY AS C ON FC.CATEGORY_ID = C.CATEGORY_ID
GROUP BY C.NAME
ORDER BY AVG_RENTAL_RATE DESC;

-- c. Which genres have the highest and the lowest average rental rate?

SELECT C.NAME AS GENRE,
	AVG(F.RENTAL_RATE) AS AVG_RENTAL_RATE
FROM FILM AS F
JOIN FILM_CATEGORY AS FC ON F.FILM_ID = FC.FILM_ID
JOIN CATEGORY AS C ON FC.CATEGORY_ID = C.CATEGORY_ID
GROUP BY C.NAME
ORDER BY AVG_RENTAL_RATE ASC;

-- d. How many rented movies were returned late?
-- Is this somehow correlated with the genre of a movie?

SELECT
  c.name AS genre,
  SUM(CASE WHEN r.return_date > r.rental_date THEN 1 ELSE 0 END) AS late_returns
FROM film AS f
JOIN film_category AS fc ON f.film_id = fc.film_id
JOIN category AS c ON fc.category_id = c.category_id
JOIN inventory AS i ON f.film_id = i.film_id
JOIN rental AS r ON i.inventory_id = r.inventory_id
GROUP BY c.name
ORDER BY late_returns DESC;


-- e. What are the top 5 cities that rent the most movies?
-- How about in terms of total sales volume?
-- Top 5 cities by rental count

SELECT CI.CITY AS CITY_NAME,
	COUNT(*) AS RENTAL_COUNT
FROM CITY AS CI
JOIN ADDRESS AS A ON CI.CITY_ID = A.CITY_ID
JOIN CUSTOMER AS CU ON A.ADDRESS_ID = CU.ADDRESS_ID
JOIN RENTAL AS R ON CU.CUSTOMER_ID = R.CUSTOMER_ID
GROUP BY CI.CITY
ORDER BY RENTAL_COUNT DESC
LIMIT 5;

-- Top 5 cities by total sales volume

SELECT CI.CITY AS CITY_NAME,
	SUM(P.AMOUNT) AS TOTAL_SALES
FROM CITY AS CI
JOIN ADDRESS AS A ON CI.CITY_ID = A.CITY_ID
JOIN CUSTOMER AS CU ON A.ADDRESS_ID = CU.ADDRESS_ID
JOIN PAYMENT AS P ON CU.CUSTOMER_ID = P.CUSTOMER_ID
GROUP BY CI.CITY
ORDER BY TOTAL_SALES DESC
LIMIT 5;

-- f. Who are your 10 best customers in terms of returning movies on time and being loyal?

SELECT
  cu.customer_id,
  cu.first_name,
  cu.last_name,
  COUNT(*) AS rentals_on_time
FROM customer AS cu
JOIN rental AS r ON cu.customer_id = r.customer_id
WHERE r.return_date <= r.rental_date
GROUP BY cu.customer_id, cu.first_name, cu.last_name
ORDER BY rentals_on_time DESC
LIMIT 10;


-- g. What are the 10 best-rated movies?
-- Is customer rating somehow correlated with revenue? Which actors have acted in the most number of the most popular or highest-rated movies?
-- 10 best-rated movies

SELECT F.TITLE AS MOVIE_TITLE,
	   avg(f.rental_rate) AS avg_rating
FROM FILM AS F
JOIN FILM_ACTOR AS FA ON F.FILM_ID = FA.FILM_ID
LEFT JOIN ACTOR AS A ON FA.ACTOR_ID = A.ACTOR_ID 
LEFT JOIN rental AS r ON f.film_id = r.rental_id
GROUP BY F.TITLE
ORDER BY AVG_RATING DESC
LIMIT 10;

-- Actors in most popular or highest-rated movies
-- To find actors in the most popular movies, you can use the query from (b) with a JOIN on the film_actor and actor tables.
-- Similarly, you can find actors in the highest-rated movies by changing the ORDER BY in the above query.
 -- h. Rentals and hence revenues have been falling behind among young families. In order to reverse this, you wish to target all movies categorized as family films.

SELECT F.TITLE AS MOVIE_TITLE,
	C.NAME AS GENRE
FROM FILM AS F
JOIN FILM_CATEGORY AS FC ON F.FILM_ID = FC.FILM_ID
JOIN CATEGORY AS C ON FC.CATEGORY_ID = C.CATEGORY_ID
WHERE C.NAME = 'Family';

-- i. How much revenue has each store generated so far?

SELECT S.STORE_ID,
	SUM(P.AMOUNT) AS TOTAL_REVENUE
FROM STORE AS S
JOIN STAFF AS ST ON S.MANAGER_STAFF_ID = ST.STAFF_ID
JOIN PAYMENT AS P ON ST.STAFF_ID = P.STAFF_ID
GROUP BY S.STORE_ID ;

-- j. To create a view of the top 5 genres by average revenue:


SELECT FC.CATEGORY_ID,
	C.NAME AS GENRE,
	AVG(P.AMOUNT) AS AVG_REVENUE
FROM FILM_CATEGORY AS FC
JOIN CATEGORY AS C ON FC.CATEGORY_ID = C.CATEGORY_ID
JOIN FILM AS F ON FC.FILM_ID = F.FILM_ID
LEFT JOIN INVENTORY AS I ON F.FILM_ID = I.FILM_ID
LEFT JOIN RENTAL AS R ON I.INVENTORY_ID = R.INVENTORY_ID
LEFT JOIN PAYMENT AS P ON R.RENTAL_ID = P.RENTAL_ID
GROUP BY FC.CATEGORY_ID,
	C.NAME
ORDER BY AVG_REVENUE DESC
LIMIT 5;