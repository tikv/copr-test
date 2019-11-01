# Test of JSON_LENGTH function.
create table utf8_mj_length (a int, c varchar(20)) CHARACTER SET 'utf8';
insert into utf8_mj_length values( 1, null );
insert into utf8_mj_length values( 2, '1' );
insert into utf8_mj_length values( 3, 'abc' );
insert into utf8_mj_length values( 4, '"abc"' );
insert into utf8_mj_length values ( 5, 'true' );
insert into utf8_mj_length values ( 6, 'false' );
insert into utf8_mj_length values ( 7, 'null' );

select a, c, json_length( c ) from utf8_mj_length where a = 1;

select a, c, json_length( c ) from utf8_mj_length where a = 2;

select a, c, json_length( c ) from utf8_mj_length where a = 4;
select a, c, json_length( c ) from utf8_mj_length where a = 5;
select a, c, json_length( c ) from utf8_mj_length where a = 6;
select a, c, json_length( c ) from utf8_mj_length where a = 7;


create table json_mj_length( a int, b json );

insert into json_mj_length values( 1, NULL );

select a, b, json_length( b ) from json_mj_length where a = 1;

set names 'utf8';

select a, c, json_length( c, '$' ) from utf8_mj_length where a = 1;
select a, c, json_length( c, '$' ) from utf8_mj_length where a = 2;

select a, c, json_length( c, '$' ) from utf8_mj_length where a = 4;
select a, c, json_length( c, '$' ) from utf8_mj_length where a = 5;
select a, c, json_length( c, '$' ) from utf8_mj_length where a = 6;
select a, c, json_length( c, '$' ) from utf8_mj_length where a = 7;

select a, b, json_length( b, '$' ) from json_mj_length where a = 1;

drop table utf8_mj_length;
drop table json_mj_length;

# Make sure that every JSON function accepts latin1 text arguments. The JSON
# functions use utf8mb4 internally, so they will need to perform charset
# conversion.
CREATE TABLE t_latin1(id INT PRIMARY KEY AUTO_INCREMENT,
                      json_text VARCHAR(20),
                      json_atom_text VARCHAR(20),
                      json_path VARCHAR(20))
CHARACTER SET 'latin1';
INSERT INTO t_latin1 (json_text, json_atom_text, json_path) VALUES
(CONVERT(X'5B22E6F8E5225D' USING latin1),             # ["\u00e6\u00f8\u00e5"]
 CONVERT(X'E5F8E6' USING latin1),                     # \u00e5\u00f8\u00e6
 '$[0]'),
(CONVERT(X'7B22E6F8E5223A22E6F8E5227D' USING latin1),
                                  # {"\u00e6\u00f8\u00e5":"\u00e6\u00f8\u00e5"}
 CONVERT(X'E5F8E6' USING latin1),                     # \u00e5\u00f8\u00e6
 CONVERT(X'242E22E6F8E522' USING latin1));            # $."\u00e6\u00f8\u00e5"
SELECT JSON_LENGTH(json_text, json_path) FROM t_latin1 ORDER BY id;
DROP TABLE t_latin1;