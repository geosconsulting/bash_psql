DROP function link_current_evolution();

CREATE or replace function link_current_evolution()
RETURNS table(current_id BIGINT,date_current date, current_area_ha numeric,
              evolution_firedate date, evolution_area_ha numeric, difference double precision) as
$$
begin 
   return QUERY
     SELECT c.id,c.firedate,c.area_ha,e.firedate,e.area_ha,cast(c.area_ha-e.area_ha as double precision) as "increase"
     from current_ba c
     INNER join evolution_ba e ON (e.id=c.id)
     ORDER BY c.id;
end;
$$
language plpgsql volatile
cost 100
rows 1000;

select * from link_current_evolution();

