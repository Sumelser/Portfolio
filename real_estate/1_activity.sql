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
-- разделим объявления на три категории (1 - быстропроданные, 2 - средняя скорость продажи, 3 - застойные продажи)
categories as (
	select *,
	ntile(3) over(order by days_exposition) as category
	from real_estate.advertisement a 
	WHERE id IN (SELECT * FROM filtered_id) and days_exposition is not null
)
--параметры квартир по категориям
select 
	case 
		when city_id='6X8I'
			then 'Санкт-Петербург'
		else 'Ленинградская Область'
	end as region,
	case 
		when category=1
			then 'быстропроданные квартиры'
		when category=2
			then 'средняя скорость продажи'
		when category=3
			then 'долгопродаваемые квартиры'
	end as category,
	round(avg(last_price/total_area)::numeric, 2) as price_per_meter,
	round(avg(total_area)::numeric, 2) as total_area,
	round(avg(rooms)::numeric, 2) as rooms,
	round(avg(balcony)::numeric, 2) as balcony
from categories c
join real_estate.flats using (id)
WHERE id IN (SELECT * FROM filtered_id)
	and city_id in (select * from correct_city_id)
group by region, category
order by region, c.category;
