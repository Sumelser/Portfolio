/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: SUMAROKOVA ELIZAVETA
 * Дата: 09-01-2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
	COUNT(id) AS total_users,	-- общее кол-во игроков
	SUM(payer) AS payer_users,	-- кол-во платящих игроков
	round(avg(payer), 4) AS  part_users	-- доля платящих игроков
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
	r.race,
	COUNT(u.id) AS total_users,
	SUM(payer) AS payer_users,
	ROUND(AVG(u.payer), 4) AS part_users
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING (race_id) 
GROUP BY race
ORDER BY part_users DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
	SELECT 
		count(amount) AS total_purchase,
		sum(amount) AS total_cost,
		min(amount) AS min_cost,
		max(amount) AS max_cost,
		avg(amount) AS avg_cost,
		percentile_disc(0.5) WITHIN GROUP (ORDER BY amount) AS median_cost,
		stddev(amount) AS stddev_cost
	FROM fantasy.events;


-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
	SELECT 
	count(CASE WHEN amount>0 THEN NULL
			ELSE amount end) AS zero_costs,
	ROUND(100*count(CASE WHEN amount>0 THEN NULL
			ELSE amount end)::NUMERIC/count(transaction_id), 3) AS zero_part
	FROM fantasy.events;
-- проверка нулевых покупок
SELECT item_code,
	game_items,
	count(transaction_id) AS count,
	count(DISTINCT id) AS count_buyers,
	count(seller_id) AS count_sellers,
	count(date)  AS count_date
FROM fantasy.events e 
JOIN fantasy.items i USING (item_code)
WHERE amount=0
GROUP BY item_code, game_items 
ORDER BY count DESC;
--проверка, есть ли среди купивших книгу за бесплатно игроки, не купившие потом вообще ничего
SELECT DISTINCT id
FROM fantasy.events e 
WHERE amount=0
EXCEPT 
SELECT DISTINCT id
FROM fantasy.events e
WHERE amount<>0;
--проверка аномально крупных покупок
SELECT *
FROM fantasy.events e 
ORDER BY amount DESC
LIMIT 10;
--проверка стоимости предмета book of legends (item_code=6010)
SELECT 
	count(amount) AS total_purchase,
	sum(amount) AS total_cost,	
	min(amount) AS min_cost,
	max(amount) AS max_cost,
	avg(amount) AS avg_cost,
	percentile_disc(0.5) WITHIN GROUP (ORDER BY amount) AS median_cost,
	stddev(amount) AS stddev_cost
FROM fantasy.events
WHERE amount<>0 AND item_code=6010;  
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
	
	WITH qwer AS ( 
		SELECT id,
		-- подсчет количества покупок и средней суммы каждого игрока
		COUNT(transaction_id) AS transaction_count,
		sum(amount) AS sum_amount
		FROM fantasy.events e 
		WHERE amount>0
		GROUP BY id
	)
	SELECT
		payer,
		COUNT(DISTINCT id),
		-- считаем среднее ко-во покупок и среднюю суммарную стоимость на одного игрока
		avg(transaction_count) AS avg_purchases,
		AVG(sum_amount) AS avg_amount
	FROM qwer q JOIN fantasy.users u USING (id)
	GROUP BY payer;


-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь
	
	WITH сount_users AS(
		SELECT item_code,
		COUNT(DISTINCT id) AS item_buyers,
		(SELECT COUNT(DISTINCT id) FROM fantasy.events e ) AS total_buyers
		FROM fantasy.events e 
		WHERE amount<>0
		GROUP BY item_code
	),	
	mn_tbl AS (
		SELECT e.item_code,
		game_items,
		COUNT(transaction_id) OVER(PARTITION BY e.item_code) AS item_purchases,
		COUNT(transaction_id) OVER() AS total_purchases,
		item_buyers,
		total_buyers
		FROM fantasy.events e 
		JOIN fantasy.items i USING (item_code)
		LEFT JOIN сount_users cu USING (item_code)
		WHERE amount<>0
	)
	SELECT
		item_code,
		game_items,
		avg(item_purchases) AS item_purchases,
		round(avg(item_purchases::NUMERIC/total_purchases), 4) AS part_of_purchases,
		avg(item_buyers) AS item_buyers,
		round(avg(item_buyers::numeric/total_buyers), 4) AS part_of_buyers
	FROM mn_tbl
	GROUP BY item_code, game_items
	ORDER BY item_purchases DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- попытка два
WITH count_users AS ( -- общее кол-во игроков для каждой расы
	SELECT 
		race,
		COUNT(DISTINCT id) AS total_users
	FROM fantasy.race r 
	JOIN fantasy.users u USING (race_id)
	GROUP BY race
),
--доля платящих игроков
payers AS (
	SELECT 
		race,
		count(DISTINCT e.id) AS total_payers
	FROM fantasy.race r 
	JOIN fantasy.users u USING (race_id)
	JOIN fantasy.events e USING (id)
	WHERE amount<>0 AND payer=1
	GROUP BY race
	ORDER BY race
),
--кол-во и сумма покупок
purchases AS (
	SELECT 
		race,
		count(DISTINCT e.id) AS total_buyers,
		count(transaction_id) AS count_purchases,
		sum(amount) AS total_amount
	FROM fantasy.race r 
	LEFT JOIN fantasy.users u USING (race_id)
	LEFT JOIN fantasy.events e USING (id)
	GROUP BY race
)
--main querry
SELECT 
	race,
	total_users,
	total_buyers,
	ROUND(total_buyers::NUMERIC/total_users, 4) AS part_buyers,
	--total_payers,
	round(total_payers::NUMERIC/total_buyers, 4) AS part_payers,
	round(count_purchases::NUMERIC/total_buyers, 4) AS avg_purchases_per_user,
	round(total_amount::NUMERIC/count_purchases, 4) AS total_amount_per_user,
	round(total_amount::NUMERIC/total_buyers, 4) AS total_sum_amount_per_user
FROM count_users
JOIN payers USING (race)
JOIN purchases USING (race);
