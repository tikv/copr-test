create database push_down_test_db;
use push_down_test_db;

drop table if exists tb10;
create table tb10
(
    int_s       int(32) signed,
    int_u       int(32) unsigned,
    bigint_s    bigint(64) signed,
    bigint_u    bigint(64) unsigned,
    float_num   float(32, 8),
    double_num  double(64, 10),
    char_num    varchar(20),
    decimal_num decimal(65, 10),
    time_num    datetime,
    json_num    json
);

insert into tb10 (int_s, int_u, bigint_s, bigint_u, float_num, double_num, char_num, decimal_num, time_num, json_num)
values (0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

insert into tb10 (int_s, int_u, bigint_s, bigint_u, float_num, double_num, char_num, decimal_num, json_num)
values (2147483647, 2147483647, 2147483647, 2147483647, 2147483647, 2147483647, '2147483647', 2147483647, '2147483647');

insert into tb10 (int_s, bigint_s, float_num, double_num, char_num, decimal_num, json_num)
values (-2147483648, -2147483648, -2147483648, -2147483648, '-2147483648', -2147483648, '-2147483648');

insert into tb10 (int_u, bigint_s, bigint_u, float_num, double_num, char_num, decimal_num, json_num)
values (4294967295, 4294967295, 4294967295, 4294967295, 4294967295, '4294967295', 4294967295, '4294967295');

insert into tb10 (bigint_s, bigint_u, float_num, double_num, char_num, decimal_num, json_num)
values (9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, '9223372036854775807',
        9223372036854775807, '9223372036854775807');

insert into tb10 (bigint_s, float_num, double_num, char_num, decimal_num, json_num)
values (-9223372036854775808, -9223372036854775808, -9223372036854775808, '-9223372036854775808',
        -9223372036854775808, '-9223372036854775808');

insert into tb10 (bigint_u, float_num, double_num, char_num, decimal_num, json_num)
values (18446744073709551615, 18446744073709551615,
        18446744073709551615, '18446744073709551615', 18446744073709551615, '18446744073709551615');

insert into tb10 (float_num, double_num, char_num, decimal_num, json_num)
values (36893488147419103232,
        36893488147419103232, 36893488147419103232, 36893488147419103232, 36893488147419103232);

insert into tb10 (float_num, double_num, char_num, decimal_num, json_num)
values (-36893488147419103232,
        -36893488147419103232, -36893488147419103232, -36893488147419103232, -36893488147419103232);

insert into tb10 (  float_num, double_num, char_num, decimal_num, json_num)
values (-36893488147419103232,
        -36893488147419103232, -36893488147419103232, -36893488147419103232,
        -36893488147419103232);

cast to signed int
select *
from tb10
where cast(int_s as signed int) = int_s;
show warnings;
select *
from tb10
where cast(int_u as signed int) = int_s;
show warnings;
select *
from tb10
where cast(bigint_s as signed int) = int_s;
show warnings;
select *
from tb10
where cast(bigint_u as signed int) = int_s;
show warnings;

select *
from tb10
where cast(float_num as signed int) = int_s;
show warnings;
select *
from tb10
where cast(double_num as signed int) = int_s;
show warnings;
select *
from tb10
where cast(char_num as signed int) = int_s;
show warnings;
select *
from tb10
where cast(decimal_num as signed int) = int_s;
show warnings;
select *
from tb10
where cast(time_num as signed int) = int_s;
show warnings;
select *
from tb10
where cast(json_num as signed int) = int_s;
show warnings;

select *
from tb10
where cast(int_s as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(int_u as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(bigint_s as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(bigint_u as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(float_num as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(double_num as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(char_num as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(decimal_num as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(time_num as signed int) = bigint_s;
show warnings;
select *
from tb10
where cast(json_num as signed int) = bigint_s;
show warnings;

# cast to unsigned int
select *
from tb10
where cast(int_s as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(int_u as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(bigint_s as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(bigint_u as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(float_num as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(double_num as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(char_num as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(decimal_num as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(time_num as unsigned int) = int_u;
show warnings;
select *
from tb10
where cast(json_num as unsigned int) = int_u;
show warnings;

select *
from tb10
where cast(int_s as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(int_u as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(bigint_s as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(bigint_u as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(float_num as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(double_num as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(char_num as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(decimal_num as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(time_num as unsigned int) = bigint_u;
show warnings;
select *
from tb10
where cast(json_num as unsigned int) = bigint_u;
show warnings;


# cast to real
select *
from tb10
where cast(int_s as real) = float_num;
show warnings;
select *
from tb10
where cast(int_u as real) = float_num;
show warnings;
select *
from tb10
where cast(bigint_s as real) = float_num;
show warnings;
select *
from tb10
where cast(bigint_u as real) = float_num;
show warnings;
select *
from tb10
where cast(float_num as real) = float_num;
show warnings;
select *
from tb10
where cast(double_num as real) = float_num;
show warnings;
select *
from tb10
where cast(char_num as real) = float_num;
show warnings;
select *
from tb10
where cast(decimal_num as real) = float_num;
show warnings;
select *
from tb10
where cast(time_num as real) = float_num;
show warnings;
select *
from tb10
where cast(json_num as real) = float_num;
show warnings;

select *
from tb10
where cast(int_s as real) = double_num;
show warnings;
select *
from tb10
where cast(int_u as real) = double_num;
show warnings;
select *
from tb10
where cast(bigint_s as real) = double_num;
show warnings;
select *
from tb10
where cast(bigint_u as real) = double_num;
show warnings;
select *
from tb10
where cast(float_num as real) = double_num;
show warnings;
select *
from tb10
where cast(double_num as real) = double_num;
show warnings;
select *
from tb10
where cast(char_num as real) = double_num;
show warnings;
select *
from tb10
where cast(decimal_num as real) = double_num;
show warnings;
select *
from tb10
where cast(time_num as real) = double_num;
show warnings;
select *
from tb10
where cast(json_num as real) = double_num;
show warnings;

# cast to float
select *
from tb10
where cast(int_s as float) = float_num;
show warnings;
select *
from tb10
where cast(int_u as float) = float_num;
show warnings;
select *
from tb10
where cast(bigint_s as float) = float_num;
show warnings;
select *
from tb10
where cast(bigint_u as float) = float_num;
show warnings;
select *
from tb10
where cast(float_num as float) = float_num;
show warnings;
select *
from tb10
where cast(double_num as float) = float_num;
show warnings;
select *
from tb10
where cast(char_num as float) = float_num;
show warnings;
select *
from tb10
where cast(decimal_num as float) = float_num;
show warnings;
select *
from tb10
where cast(time_num as float) = float_num;
show warnings;
select *
from tb10
where cast(json_num as float) = float_num;
show warnings;

select *
from tb10
where cast(int_s as float) = double_num;
show warnings;
select *
from tb10
where cast(int_u as float) = double_num;
show warnings;
select *
from tb10
where cast(bigint_s as float) = double_num;
show warnings;
select *
from tb10
where cast(bigint_u as float) = double_num;
show warnings;
select *
from tb10
where cast(float_num as float) = double_num;
show warnings;
select *
from tb10
where cast(double_num as float) = double_num;
show warnings;
select *
from tb10
where cast(char_num as float) = double_num;
show warnings;
select *
from tb10
where cast(decimal_num as float) = double_num;
show warnings;
select *
from tb10
where cast(time_num as float) = double_num;
show warnings;
select *
from tb10
where cast(json_num as float) = double_num;
show warnings;

# cast to double
select *
from tb10
where cast(int_s as double) = float_num;
show warnings;
select *
from tb10
where cast(int_u as double) = float_num;
show warnings;
select *
from tb10
where cast(bigint_s as double) = float_num;
show warnings;
select *
from tb10
where cast(bigint_u as double) = float_num;
show warnings;
select *
from tb10
where cast(float_num as double) = float_num;
show warnings;
select *
from tb10
where cast(double_num as double) = float_num;
show warnings;
select *
from tb10
where cast(char_num as double) = float_num;
show warnings;
select *
from tb10
where cast(decimal_num as double) = float_num;
show warnings;
select *
from tb10
where cast(time_num as double) = float_num;
show warnings;
select *
from tb10
where cast(json_num as double) = float_num;
show warnings;

select *
from tb10
where cast(int_s as double) = double_num;
show warnings;
select *
from tb10
where cast(int_u as double) = double_num;
show warnings;
select *
from tb10
where cast(bigint_s as double) = double_num;
show warnings;
select *
from tb10
where cast(bigint_u as double) = double_num;
show warnings;
select *
from tb10
where cast(float_num as double) = double_num;
show warnings;
select *
from tb10
where cast(double_num as double) = double_num;
show warnings;
select *
from tb10
where cast(char_num as double) = double_num;
show warnings;
select *
from tb10
where cast(decimal_num as double) = double_num;
show warnings;
select *
from tb10
where cast(time_num as double) = double_num;
show warnings;
select *
from tb10
where cast(json_num as double) = double_num;
show warnings;

# cast to string
select *
from tb10
where cast(int_s as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(int_u as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(bigint_s as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(bigint_u as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(float_num as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(double_num as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(char_num as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(decimal_num as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(time_num as char(30)) = char_num;
show warnings;
select *
from tb10
where cast(json_num as char(30)) = char_num;
show warnings;

select *
from tb10
where cast(int_s as decimal(65, 10)) = decimal_num;

# cast to decimal
select *
from tb10
where cast(int_s as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(int_u as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(bigint_s as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(bigint_u as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(float_num as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(double_num as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(char_num as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(decimal_num as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(time_num as decimal(65, 10)) = decimal_num;
show warnings;
select *
from tb10
where cast(json_num as decimal(65, 10)) = decimal_num;
show warnings;

# TODO, the execution plan say they are push downed to TiKV,
#  however, they may run ScalarFunc's cast but not rpn's cast
# cast to time
select *
from tb10
where cast(int_s as time) = time_num;
show warnings;
select *
from tb10
where cast(int_u as time) = time_num;
show warnings;
select *
from tb10
where cast(bigint_s as time) = time_num;
show warnings;
select *
from tb10
where cast(bigint_u as time) = time_num;
show warnings;
select *
from tb10
where cast(float_num as time) = time_num;
show warnings;
select *
from tb10
where cast(double_num as time) = time_num;
show warnings;
select *
from tb10
where cast(char_num as time) = time_num;
show warnings;
select *
from tb10
where cast(decimal_num as time) = time_num;
show warnings;
select *
from tb10
where cast(time_num as time) = time_num;
show warnings;
select *
from tb10
where cast(json_num as time) = time_num;
show warnings;

# cast to json
select *
from tb10
where cast(int_s as json) = json_num;
show warnings;
select *
from tb10
where cast(int_u as json) = json_num;
show warnings;
select *
from tb10
where cast(bigint_s as json) = json_num;
show warnings;
select *
from tb10
where cast(bigint_u as json) = json_num;
show warnings;
select *
from tb10
where cast(float_num as json) = json_num;
show warnings;
select *
from tb10
where cast(double_num as json) = json_num;
show warnings;
select *
from tb10
where cast(char_num as json) = json_num;
show warnings;
select *
from tb10
where cast(decimal_num as json) = json_num;
show warnings;
select *
from tb10
where cast(time_num as json) = json_num;
show warnings;
select *
from tb10
where cast(json_num as json) = json_num;
show warnings;
