create table tb2
(
    date   datetime,
    date_2 datetime,
    date_3 datetime
);
insert into tb2 (date, date_2, date_3)
values ('1-1-1:10:10', '1-2-1:10:10', '1-2-1:10:10');

##
##

create table tb9
(
    a bigint
);
insert into tb9 (a)
values (30);

select *
from tb9;

select a
from tb9
where (convert(a, signed int) = a);
