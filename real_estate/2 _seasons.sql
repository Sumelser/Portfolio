-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--находим нас пункты, которым присвоенно больше двух типов
double_city as (
	select distinct city_id
	from real_estate.city c
		join real_estate.flats f using (city_id)
		join real_estate."type" t using (type_id)
	group by city_id
	having count(distinct type)>1),
--находим city_id городов, которым были присвоены и другие типы нас.пунктов
adding_id as (
	select distinct city
	from real_estate.city c
		join real_estate.flats f using (city_id)
		join real_estate."type" t using (type_id)
	where city_id in (select * from double_city)
		and type='город'
	order by city),
--составляем корректный список city_id городов
correct_city_id as(
	select city_id
	from real_estate.flats f
	Where type_id='F8EM'
	        OR city_id in (select * from adding_id)),
publish as (
	select 
		extract(month from first_day_exposition) as month,
		count(id) as count_of_ads
	from real_estate.advertisement a 
	join real_estate.flats f using (id)
	WHERE id IN (SELECT * FROM filtered_id)
				and type_id='F8EM' --фильтруем только города по ленобласти
				and extract(year from first_day_exposition)>2014
				and extract(year from first_day_exposition)<2019
				and city_id in (select * from correct_city_id)
	group by extract('month' from first_day_exposition)
	),
saling as (
	select 
		extract(month from first_day_exposition+days_exposition::int) as month,
		count(id) as count_of_sales,
		round(avg(last_price/total_area)::numeric, 2) as price_per_meter,
		round(avg(total_area)::numeric, 2) as total_area
	from real_estate.advertisement a 
	join real_estate.flats f using (id)
	WHERE id IN (SELECT * FROM filtered_id) 
				and days_exposition is not null
				and extract(year from first_day_exposition)>2014
				and extract(year from first_day_exposition)<2019
				and city_id in (select * from correct_city_id)
	group by extract(month from first_day_exposition+days_exposition::int)
)
select p.month,
	count_of_ads as published,
	count_of_sales as sold,
	total_area, price_per_meter
from publish p join saling using (month)
order by p.month;
