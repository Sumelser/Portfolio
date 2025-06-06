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
--кол-во проданных квартир, а также характеристики этих квартир, в разрезе по нас.пунктам
sales_by_city as (
	select 
		city,
		CASE WHEN city_id in (select * from correct_city_id) THEN 'F8EM'
			ELSE type_id
		END as type_,
		count(a.id) as sales_count,
		round(avg(days_exposition)::numeric, 2) as days_exposition,
		round(avg(last_price/total_area)::numeric, 0) as price_per_meter,
		round(avg(total_area)::numeric, 2) as total_area
	from real_estate.city c 
		join real_estate.flats f using (city_id)
		join real_estate.advertisement a using (id)
	where id IN (SELECT * FROM filtered_id)
			and city_id<>'6X8I'
			and days_exposition is not null
	group by city , type_
),
--общее кол-во объявлений в разрезе по нас.пунктам
advs_by_city as(
	select 
		city,
		CASE WHEN city_id in (select * from correct_city_id) THEN 'F8EM'
			ELSE type_id
		END as type_,
		count(a.id) as advs_count
	from real_estate.city c 
		join real_estate.flats f using (city_id)
		join real_estate.advertisement a using (id)
	where id IN (SELECT * FROM filtered_id)
			and city_id<>'6X8I'
	group by city, type_
)
select
	abc.city,
	advs_count,
	--sales_count,
	round(sales_count::numeric/advs_count*100, 2) as sales_share,
	days_exposition,
	price_per_meter,
	total_area
from advs_by_city abc
	join sales_by_city sbc on abc.city=sbc.city
								and abc.type_=sbc.type_
	join real_estate."type" t on t.type_id = abc.type_
								and t.type_id = sbc.type_
where advs_count>100 and abc.type_='F8EM'
order by advs_count desc;
