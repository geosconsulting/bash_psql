begin;
drop index if exists this_index_:TSUFF;
commit;

begin;
create table new_table_:TSUFF (greeting text not null default '');
commit;

begin;
insert into new_table_:TSUFF (greeting)
values ('Hello from table ' || :QTSUFF);
commit;
