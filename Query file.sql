#### ROLL Metrics
#### ROLL Metrics

## How many rolls were ordered?

select count(roll_id) as total_rolls_ordered from customer_orders;

## How many unique customer orders were made?

select count(distinct customer_id) as total_customers from customer_orders;

## How many successful orders were delivered by  each driver?

select driver_id,count(distinct order_id) as total_orders_delivered from driver_order
 where cancellation not in ('Cancellation','Customer Cancellation')
 group  by driver_id;
 
 ## How many each type of rolls delivered?
 
 select roll_id,count( roll_id) as total_orders from customer_orders where order_id in (
 select order_id from
 (select *,
CASE
	When cancellation  in ('Cancellation','Customer Cancellation') then "C" 
	else "NC"
end as order_cancellation_details from driver_order
)a
 where order_cancellation_details = "NC"
 )
 group by roll_id
 order by total_orders desc;

 ## How many veg and non-veg rolls ordered by each of the customers?
 
 select a.*,b.roll_name from 
 (
 select customer_id,roll_id, count(roll_id) as num_of_times_ordered  from customer_orders
 group by customer_id,roll_id
 )a
 Inner join  rolls b
 on b.roll_id=a.roll_id;
 
## Maximum number of rolls delivered in a single order?

select *,rank() over(order by total_rolls_delivered desc) rnk from
(
select order_id,count(roll_id) total_rolls_delivered from
(select * from customer_orders where order_id in
(
select order_id from
(
select *,
CASE
	When cancellation  in ('Cancellation','Customer Cancellation') then "C" 
	else "NC"
end as order_cancellation_details from driver_order)a
where order_cancellation_details = "NC"
))h
group by order_id
)l limit 1;

## for each customer how many delivered rolls has at least 1 change and how many had no changes?

# creating temporary table

CREATE TEMPORARY TABLE temp_customers_orders
(
select order_id,customer_id,
      CASE
          when not_include_items is NULL OR not_include_items = "" then '0' 
          else not_include_items
          end as new_not_include_items ,
      CASE
          when extra_items_included is NULL OR extra_items_included =  "" OR extra_items_included = 'NaN' then '0'
          else extra_items_included
          end as new_extra_items_included,
order_date from customer_orders
);
select * from temp_customers_orders;

CREATE TEMPORARY TABLE temp_driver_orders
(
select Order_id,driver_id,pickup_time,distance,duration,
      CASE
          when Cancellation in ("Cancellation" ,"Customer Cancellation" ) then '0' 
          else 1
          end as new_cancellation 
      from driver_order
);

## for each customer how many delivered rolls has at least 1 change and how many had no changes?

select customer_id,change_no_change,count(order_id) at_least_one_change from
(
select *,
        CASE
        when new_not_include_items ='0' and new_extra_items_included='0' then 'No Change'
        else 'Yes change'
        end as change_no_change
 from temp_customers_orders where order_id in
(
select order_id from temp_driver_orders where new_cancellation !='0'
)
)f
group by customer_id,change_no_change;

## How many rolls were delivered that has both_exclusions and extras?

select count(order_id) as total_rolls_had_both_excl_extras from (
select * from temp_customers_orders where order_id in
(
select order_id from temp_driver_orders where new_cancellation !='0'
))s
where new_not_include_items !='0' and new_extra_items_included !='0' ;


## what is the total number of rolls ordered for each hour of the day?

select hour_stamp,count(hour_stamp) as total_rolls_ordered_each_hour from
(select *, concat(cast(hour(order_date) as char) ,'-', cast(hour(order_date)+1 as char)) as hour_stamp from customer_orders)w
group by hour_stamp;

#### what is the total number of orders  for each day of the week?

select day,count(order_id) as total_orders from
(
select *, dayname(order_date) as day from customer_orders
)d
group by day;

#### Driver Metrics
#### Driver Metrics

# Avergae time in minutes, it took for each driver to arrive at Fasoos HQ to pickup the order?

select driver_id,Round(sum(minute(time(pickup_time-order_date)))/count(order_id),1) as avg_time from
(
select *, row_number()over(partition by order_id order by total_time_to_reach) rnk from
(
select c.order_id,c.customer_id,c.roll_id,c.not_include_items,c.extra_items_included,c.order_date,d.pickup_time,
	    d.driver_id,d.distance,d.duration,d.cancellation,time(pickup_time-order_date) as total_time_to_reach from customer_orders c
inner join driver_order d
on d.order_id=c.order_id
where d.pickup_time is not null
)f
)k where rnk=1 
group by driver_id;

## Reltionship between  the number of rolls and how long  the order takes to prepare?

Select order_id,count(roll_id) as no_of_rolls,round(sum(total_time_to_reach)/count(roll_id),0) from
(
select c.order_id,c.customer_id,c.roll_id,c.not_include_items,c.extra_items_included,c.order_date,d.pickup_time,
	    d.driver_id,d.distance,d.duration,d.cancellation,minute(time(pickup_time-order_date)) as total_time_to_reach from customer_orders c
inner join driver_order d
on d.order_id=c.order_id
where d.pickup_time is not null
)d
group by order_id;

## What was the average distance travelled for each of the customer.?
select customer_id,Round(avg(distance),1) as avg_distance_customer from
(
select c.order_id,c.customer_id,c.roll_id,c.not_include_items,c.extra_items_included,c.order_date,d.pickup_time,
        cast(trim(replace(lower(d.distance),'km','')) as decimal(4,2)) as distance,
	    d.driver_id,d.duration,d.cancellation from customer_orders c
inner join driver_order d
on d.order_id=c.order_id
where d.pickup_time is not null
)f
group by customer_id;

## What is the difference betweeen longest and shortest delivery  time for all orders?


Select (max(duration)-min(duration)) as diff from driver_order;

select (max(Time_taken)-min(Time_taken)) as diff from
(
select duration ,
	      case
	      when duration like '%min%' then left(duration,position('m' in duration)-1) 
          else duration
          end as Time_taken
          from driver_order where duration is not null
)g;

# What is the average speed for each driver for each delivery and do you notice any trend for hese values?

select a.order_id,a.driver_id, Round((a.distance/a.time_taken),2) as Speed,b.total_rolls from
(
select  order_id,driver_id,cast(trim(replace(lower(distance),'km','')) as decimal(4,2)) as distance,
	      case
	      when duration like '%min%' then left(duration,position('m' in duration)-1) 
          else duration
          end as Time_taken
		  from driver_order where distance is not null
)a
inner join
(select order_id,count(roll_id) as total_rolls from customer_orders group by  order_id) b
on a.order_id=b.order_id;


## What is the successful delivery percentage for each driver?

select driver_id,Round((sum(cancelled)/count(driver_id)) *100,1) as Succs_delivery_pct from
(
select driver_id,
         case
		 when lower(cancellation) like '%cancel%' then 0
         else 1
         end as  cancelled
         from driver_order
)a
group by driver_id