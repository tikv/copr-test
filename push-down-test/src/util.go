package main

import (
	"bytes"
	"database/sql"
	"io/ioutil"
	"log"

	"github.com/pingcap/errors"
)

type ByteRow struct {
	Data [][]byte
}

type ByteRows struct {
	Cols []string
	Data []ByteRow
}

func (rows *ByteRows) Len() int {
	return len(rows.Data)
}

func (rows *ByteRows) Less(i, j int) bool {
	r1 := rows.Data[i]
	r2 := rows.Data[j]
	for i := 0; i < len(r1.Data); i++ {
		res := bytes.Compare(r1.Data[i], r2.Data[i])
		switch res {
		case -1:
			return true
		case 1:
			return false
		}
	}
	return false
}

func (rows *ByteRows) Swap(i, j int) {
	rows.Data[i], rows.Data[j] = rows.Data[j], rows.Data[i]
}

func SqlRowsToByteRows(rows *sql.Rows) (*ByteRows, error) {
	cols, err := rows.Columns()
	if err != nil {
		return nil, errors.Trace(err)
	}

	data := make([]ByteRow, 0, 8)
	args := make([]interface{}, len(cols))
	for rows.Next() {
		tmp := make([][]byte, len(cols))
		for i := 0; i < len(args); i++ {
			args[i] = &tmp[i]
		}
		err := rows.Scan(args...)
		if err != nil {
			return nil, errors.Trace(err)
		}

		data = append(data, ByteRow{tmp})
	}
	err = rows.Err()
	if err != nil {
		return nil, errors.Trace(err)
	}

	return &ByteRows{Cols: cols, Data: data}, nil
}

// Write the `rows` to `target`
func WriteQueryResult(rows *ByteRows, target *bytes.Buffer) {
	cols := rows.Cols
	for i, c := range cols {
		target.WriteString(c)
		if i != len(cols)-1 {
			target.WriteString("\t")
		}
	}
	target.WriteString("\n")

	for _, row := range rows.Data {
		var value string
		Assert(len(row.Data) == len(cols), "len(row.Data) must equal to len(cols)")
		for i, col := range row.Data {
			// Here we can check if the value is nil (NULL value)
			if col == nil {
				value = "NULL"
			} else {
				value = string(col)
			}
			target.WriteString(value)
			if i < len(row.Data)-1 {
				target.WriteString("\t")
			}
		}
		target.WriteString("\n")
	}
}

func Assert(ok bool, msg string) {
	if !ok {
		panic(msg)
	}
}

func expectNoErr(err error) {
	if err != nil {
		log.Panicln(err)
	}
}

func readFile(fileName string) string {
	d, err := ioutil.ReadFile(fileName)
	if err != nil {
		log.Panicf("read file[%s] failed, err is [%v]\n", fileName, err)
	}
	return string(d)
}

func mustDBClose(db *sql.DB) {
	err := db.Close()
	if err != nil {
		log.Panicf("Failed to close DB: %v\n", err)
	}
}

func mustDBOpen(connString string) *sql.DB {
	db, err := sql.Open("mysql", connString)
	if err != nil {
		log.Panicf("Failed to open DB [%s]: %v\n", connString, err)
	}
	return db
}

func mustDBExec(db *sql.DB, query string) {
	_, err := db.Exec(query)
	if err != nil {
		log.Panicf("Failed to execute query [%s]: %v\n", query, err)
	}
}
