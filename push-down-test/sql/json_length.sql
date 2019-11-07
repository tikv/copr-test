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
SELECT JSON_LENGTH(json_text, json_path) FROM t_latin1 where JSON_LENGTH(json_text, json_path) > 0 ORDER BY id;
DROP TABLE t_latin1;