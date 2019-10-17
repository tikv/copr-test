package main

import (
	"bytes"
	"database/sql"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	_ "github.com/go-sql-driver/mysql"
	"github.com/pingcap/parser"
	"github.com/pingcap/parser/ast"
	"github.com/pingcap/parser/mysql"
	_ "github.com/pingcap/tidb/types/parser_driver"
)

const testCaseDir = "./sql"

var connStrNoPush *string
var connStrPush *string
var connStrPushWithBatch *string
var outputSuccessQueries *bool
var dbName *string

type statementLog struct {
	output    *bytes.Buffer
	stmt      string
	stmtIndex int
	hasError  bool
}

func parseSQLText(data string) (res []ast.StmtNode, warns []error, err error) {
	p := parser.New()
	p.EnableWindowFunc(true)
	// TODO, is there any problem in sqlMode?
	p.SetSQLMode(mysql.ModeNone)
	// FIXME, should change the collation and charset according to user's sql
	statements, warns, err := p.Parse(data, "utf8mb4", "utf8mb4_bin")
	return statements, warns, err
}

func readAndParseSQLText(sqlFilePath string) []ast.StmtNode {
	data := readFile(sqlFilePath)
	statements, warns, err := parseSQLText(data)
	if warns != nil {
		log.Printf("Parse warning: %v\n", warns)
	}
	if err != nil {
		log.Panicf("Parse failed: %v\n", err)
	}
	return statements
}

func prepareDB(connString string) {
	log.Printf("Preparing database [%s] for [%s]...", *dbName, connString)
	db := mustDBOpen(connString)
	mustDBExec(db, "drop database if exists `"+*dbName+"`;")
	mustDBExec(db, "create database `"+*dbName+"`;")
	mustDBClose(db)
}

func iterateTestCases() {
	err := filepath.Walk(testCaseDir, func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}
		if !strings.HasSuffix(info.Name(), ".sql") {
			return nil
		}
		log.Printf("Testing [%s]...", path)
		runTestCase(path)
		return nil
	})
	if err != nil {
		log.Panicf("Failed to read test case directory [%s]: %v\n", testCaseDir, err)
	}
}

func runTestCase(testCasePath string) {
	log.Printf("Parsing...")
	stmtAsts := readAndParseSQLText(testCasePath)
	statements := make([]string, 0, len(stmtAsts))
	for _, stmt := range stmtAsts {
		statements = append(statements, stmt.Text())
	}

	log.Printf("Running...")
	noPushDownLogChan := make(chan *statementLog)
	pushDownLogChan := make(chan *statementLog)
	pushDownWithBatchLogChan := make(chan *statementLog)
	go runStatements(noPushDownLogChan, *connStrNoPush, statements)
	go runStatements(pushDownLogChan, *connStrPush, statements)
	go runStatements(pushDownWithBatchLogChan, *connStrPushWithBatch, statements)
	ok := diffRunResult(testCasePath, noPushDownLogChan, pushDownLogChan, pushDownWithBatchLogChan)
	if !ok {
		log.Printf("Test failed. Stop.")
		os.Exit(2) // Diff fail results in exit code 2 to distinguish with panic
	}
}

func runStatements(logChan chan *statementLog, connString string, statements []string) {
	db := mustDBOpen(connString)
	mustDBExec(db, "use `"+*dbName+"`;")
	for i, stmt := range statements {
		runSingleStatement(stmt, i, db, logChan)
	}
	mustDBClose(db)
	close(logChan)
}

func runSingleStatement(stmt string, stmtIndex int, db *sql.DB, logChan chan *statementLog) bool {
	hasError := false
	logBuf := new(bytes.Buffer)
	rows, err := db.Query(stmt)
	if err != nil {
		hasError = true
		logBuf.WriteString(string(err.Error()))
		logBuf.WriteString("\n")
	} else {
		cols, err := rows.Columns()
		expectNoErr(err)
		if len(cols) > 0 {
			byteRows, err := SqlRowsToByteRows(rows)
			expectNoErr(err)
			WriteQueryResult(byteRows, logBuf)
		}
		logBuf.WriteString("\n")
		expectNoErr(rows.Close())
		expectNoErr(rows.Err())
	}
	logChan <- &statementLog{
		output:    logBuf,
		stmt:      stmt,
		stmtIndex: stmtIndex,
		hasError:  hasError,
	}
	return !hasError
}

func diffRunResult(testCasePath string,
	noPushDownLogChan chan *statementLog,
	pushDownLogChan chan *statementLog,
	pushDownWithBatchLogChan chan *statementLog) bool {

	execOkStatements := 0
	execFailStatements := 0
	diffFailStatements := 0
	successQueries := new(bytes.Buffer)

	for {
		noPushDownLog, ok1 := <-noPushDownLogChan
		pushDownLog, ok2 := <-pushDownLogChan
		pushDownWithBatchLog, ok3 := <-pushDownWithBatchLogChan

		allEnd := !(ok1 || ok2 || ok3)
		if allEnd {
			break
		}
		if !ok1 {
			log.Panicf("Internal error: NoPushDown channel drained\n")
		}
		if !ok2 {
			log.Panicf("Internal error: PushDown channel drained\n")
		}
		if !ok3 {
			log.Panicf("Internal error: PushDownWithBatch channel drained\n")
		}
		if noPushDownLog.stmt != pushDownLog.stmt ||
			pushDownLog.stmt != pushDownWithBatchLog.stmt {
			log.Panicln("Internal error: Pre-check failed, stmt should be identical",
				noPushDownLog.stmt, pushDownLog.stmt, pushDownWithBatchLog.stmt)
		}
		if noPushDownLog.stmtIndex != pushDownLog.stmtIndex ||
			pushDownLog.stmtIndex != pushDownWithBatchLog.stmtIndex {
			log.Panicln("Internal error: Pre-check failed, stmtIndex should be identical",
				noPushDownLog.stmtIndex, pushDownLog.stmtIndex, pushDownWithBatchLog.stmtIndex)
		}

		if noPushDownLog.hasError || pushDownLog.hasError || pushDownWithBatchLog.hasError {
			execFailStatements++
		} else {
			execOkStatements++
		}

		if !bytes.Equal(noPushDownLog.output.Bytes(), pushDownLog.output.Bytes()) ||
			!bytes.Equal(pushDownLog.output.Bytes(), pushDownWithBatchLog.output.Bytes()) {
			diffFailStatements++
			log.Printf("Test fail: Outputs are not matching.\n"+
				"Test case: %s\n"+
				"Statement: #%d - %s\n"+
				"NoPushDown Output: %s\n"+
				"PushDown Output: %s\n"+
				"PushDownWithBatch Output: %s\n\n",
				testCasePath,
				noPushDownLog.stmtIndex,
				noPushDownLog.stmt,
				string(noPushDownLog.output.Bytes()),
				string(pushDownLog.output.Bytes()),
				string(pushDownWithBatchLog.output.Bytes()))
		} else if noPushDownLog.hasError {
			// If output is the same, but there are errors when executing the SQL, output it as well (but tests
			// will not fail).
			log.Printf("Warn: Execute failed but outputs are matching.\n"+
				"Test case: %s\n"+
				"Statement: #%d - %s\n"+
				"Output: %s\n",
				testCasePath,
				noPushDownLog.stmtIndex,
				noPushDownLog.stmt,
				string(noPushDownLog.output.Bytes()))
		} else {
			// Output is same and there is no errors
			successQueries.WriteString(noPushDownLog.stmt)
			successQueries.WriteByte('\n')
		}
	}

	log.Printf("Test summary: Success queries: %d, fail (and ignore) queries: %d (where there are %d non-matching queries)",
		execOkStatements,
		execFailStatements,
		diffFailStatements)

	if diffFailStatements == 0 {
		log.Printf("Test summary: Test case PASS")
	} else {
		log.Printf("Test summary: Test case FAIL")
	}

	if *outputSuccessQueries {
		outputFilePath := testCasePath + ".success"
		log.Printf("Output success queries to [%s]", outputFilePath)
		expectNoErr(ioutil.WriteFile(outputFilePath, successQueries.Bytes(), 0644))
	}

	return diffFailStatements == 0
}

func buildDefaultConnStr(port int) string {
	return fmt.Sprintf("root@tcp(localhost:%d)/?allowNativePasswords=true", port)
}

func main() {
	connStrNoPush = flag.String("conn-no-push", buildDefaultConnStr(4005), "The connection string to connect to a NoPushDown TiDB instance")
	connStrPush = flag.String("conn-push", buildDefaultConnStr(4006), "The connection string to connect to a PushDown TiDB instance")
	connStrPushWithBatch = flag.String("conn-push-with-batch", buildDefaultConnStr(4007), "The connection string to connect to a PushDownWithBatch TiDB instance")
	outputSuccessQueries = flag.Bool("output-success", false, "Output success queries of test cases to a file ends with '.success' along with the original test case")
	dbName = flag.String("db", "push_down_test_db", "The database name to run test cases")
	flag.Parse()

	prepareDB(*connStrNoPush)
	prepareDB(*connStrPush)
	prepareDB(*connStrPushWithBatch)

	log.Printf("Prepare finished, start testing...")
	iterateTestCases()
}
