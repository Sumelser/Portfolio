--1. диапазон дат
select max(first_day_exposition) as last_day,
	min(first_day_exposition) as first_day
from real_estate.advertisement a ;

--2. кол-во объявлений по нас пунктам
select type,
count(distinct id) as count_adv
from real_estate.flats f 
left join real_estate."type" t using (type_id)
group by type
order by count_adv desc;

--3. статистика снятых с продажи объявлений и 4. процент снятых объявлений
select 
	min(days_exposition) as min_de,
	max(days_exposition) as max_de,
	round(avg(days_exposition)::numeric, 2) as avg_de,
	percentile_disc(0.5) within group (order by days_exposition) as med_de,
	(select count(id) from real_estate.advertisement a where days_exposition is not null)/count(id)::numeric*100 as count_sales
from real_estate.advertisement a ;

--5. кол-во объявлений в СПб (city_id='6X8I')
select
	(select count(id) from real_estate.flats f where city_id='6X8I')/count(id)::numeric*100
from real_estate.flats f ;

--6. статистика стоимости кв метра
with meter_price as(
	select last_price/total_area::numeric as price_per_meter
	from real_estate.advertisement a 
	join real_estate.flats f using (id)
)
select
	min(price_per_meter) as min_ppm,
	max(price_per_meter) as max_ppm,
	round(avg(price_per_meter)::numeric , 2) as avg_ppm,
	percentile_cont(0.5) within group (order by price_per_meter) as med_ppm 
from meter_price

--7. статистика по: общ площадь, кол-во комнат, балконов, высота потолков, этаж
with tot_area as (
	select 'total area' as parametr,
	min(total_area) as min,
	max(total_area) as max,
	round(avg(total_area)::numeric , 2) as avg,
	percentile_cont(0.5) within group (order by total_area) as med,
	percentile_cont(0.99) within group (order by total_area) as p99
	from real_estate.flats f 
),
rooms as (
	select 'rooms' as parametr,
	min(rooms) as min,
	max(rooms) as max,
	round(avg(rooms)::numeric , 2) as avg,
	percentile_cont(0.5) within group (order by rooms) as med,
	percentile_cont(0.99) within group (order by rooms) as p99
	from real_estate.flats f 
),
balcony as(
	select 'balcony' as parametr,
	min(balcony) as min,
	max(balcony) as max,
	round(avg(balcony)::numeric , 2) as avg,
	percentile_cont(0.5) within group (order by balcony) as med,
	percentile_cont(0.99) within group (order by balcony) as p99
	from real_estate.flats f 
),
ceil as (
	select 'ceiling height' as parametr,
	min(ceiling_height) as min,
	max(ceiling_height) as max,
	round(avg(ceiling_height)::numeric , 2) as avg,
	percentile_cont(0.5) within group (order by ceiling_height) as med,
	percentile_cont(0.99) within group (order by ceiling_height) as p99
	from real_estate.flats f 
),
floor as (
	select 'floor' as parametr,
	min(floor) as min,
	max(floor) as max,
	round(avg(floor)::numeric , 2) as avg,
	percentile_cont(0.5) within group (order by floor) as med,
	percentile_cont(0.99) within group (order by floor) as p99
	from real_estate.flats f 
)
select * from tot_area 
union all
select * from rooms
union all
select * from balcony
union all
select * from ceil
union all
select * from floor