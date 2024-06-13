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
	"sync"

	_ "github.com/go-sql-driver/mysql"
	"github.com/pingcap/parser"
	"github.com/pingcap/parser/ast"
	"github.com/pingcap/parser/mysql"
	_ "github.com/pingcap/tidb/types/parser_driver"
)

const testCaseDir = "./sql"
const testPrepDir = "./prepare"

var connStrNoPush *string
var connStrPushWithBatch *string
var outputSuccessQueries *bool
var dbName *string
var verboseOutput *bool
var fileFilter func(file string) bool

type statementLog struct {
	output    string
	stmt      string
	stmtIndex int
	hasError  bool
	plan      string
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
	db := mustDBOpen(connString, "")
	// Since TiDB PR #16999, the default concurrency is decided by the cores of cpu,
	// we reset these to make the exist test pass
	mustDBExec(db, "set @@tidb_index_lookup_concurrency=4;")
	mustDBExec(db, "set @@tidb_index_lookup_join_concurrency=4;")
	mustDBExec(db, "set @@tidb_hash_join_concurrency=5;")
	mustDBExec(db, "set @@tidb_hashagg_final_concurrency=4;")
	mustDBExec(db, "set @@tidb_hashagg_partial_concurrency=4;")
	mustDBExec(db, "set @@tidb_window_concurrency=4;")
	mustDBExec(db, "set @@tidb_projection_concurrency=4;")
	mustDBExec(db, "set @@tidb_distsql_scan_concurrency=15;")

	mustDBExec(db, "drop database if exists `"+*dbName+"`;")
	mustDBExec(db, "create database `"+*dbName+"`;")
	mustDBClose(db)
}

func iterateTestCases(dir string, parallel bool) {
	successCases := 0
	failedCases := 0

	var files []string
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}
		if !strings.HasSuffix(info.Name(), ".sql") {
			return nil
		}
		if fileFilter != nil && !fileFilter(path) {
			return nil
		}
		files = append(files, path)
		return nil
	})
	if err != nil {
		log.Panicf("Failed to read test case directory [%s]: %v\n", testCaseDir, err)
	}

	if !parallel {
		for _, path := range files {
			log.Printf("Serial Testing [%s]...", path)
			if runTestCase(path) {
				successCases++
			} else {
				failedCases++
			}
		}
	} else {
		wg := &sync.WaitGroup{}
		ch := make(chan bool, len(files))
		for _, path := range files {
			wg.Add(1)
			go func(path string) {
				defer wg.Done()
				log.Printf("Parallel Testing [%s]...", path)
				if runTestCase(path) {
					ch <- true
				} else {
					ch <- false
				}
			}(path)
		}
		wg.Wait()
		close(ch)
		for succ := range ch {
			if succ {
				successCases++
			} else {
				failedCases++
			}
		}
	}

	log.Printf("All test finished: pass cases: %d, fail cases: %d", successCases, failedCases)
	if failedCases > 0 {
		os.Exit(2) // Diff fail results in exit code 2 to distinguish with panic
	}
}

func runTestCase(testCasePath string) bool {
	log.Printf("Parsing...[%s]", testCasePath)
	stmtAsts := readAndParseSQLText(testCasePath)
	statements := make([]string, 0, len(stmtAsts))
	for _, stmt := range stmtAsts {
		statements = append(statements, stmt.Text())
	}

	log.Printf("Running...[%s]", testCasePath)
	noPushDownLogChan := make(chan *statementLog)
	pushDownWithBatchLogChan := make(chan *statementLog)
	go runStatements(noPushDownLogChan, *connStrNoPush, statements)
	go runStatements(pushDownWithBatchLogChan, *connStrPushWithBatch, statements)
	return diffRunResult(testCasePath, noPushDownLogChan, pushDownWithBatchLogChan)
}

func runStatements(logChan chan *statementLog, connString string, statements []string) {
	db := mustDBOpen(connString, *dbName)
	for i, stmt := range statements {
		runSingleStatement(stmt, i, db, logChan)
	}
	mustDBClose(db)
	close(logChan)
}

func runQuery(db *sql.DB, sql string) (string, error) {
	rows, err := db.Query(sql)
	buf := new(bytes.Buffer)
	if err != nil {
		return "", err
	}
	defer func() {
		expectNoErr(rows.Close())
	}()
	cols, err := rows.Columns()
	expectNoErr(err)
	if len(cols) > 0 {
		byteRows, err := SqlRowsToByteRows(rows, cols)
		expectNoErr(err)

		sqlErr := rows.Err()
		if sqlErr != nil {
			return "", sqlErr
		}
		WriteQueryResult(byteRows, buf)
	}
	buf.WriteString("\n")

	return buf.String(), nil
}

func runSingleStatement(stmt string, stmtIndex int, db *sql.DB, logChan chan *statementLog) bool {
	hasError := false

	plan, err := runQuery(db, fmt.Sprintf("EXPLAIN %s", stmt))
	if err != nil {
		plan = fmt.Sprintf("Failed to get plan: %s", err.Error())
	}

	output, err := runQuery(db, stmt)
	if err != nil {
		hasError = true
		output = err.Error() + "\n"
	}

	logChan <- &statementLog{
		output:    output,
		stmt:      stmt,
		stmtIndex: stmtIndex,
		hasError:  hasError,
		plan:      plan,
	}
	return !hasError
}

func diffRunResult(
	testCasePath string,
	noPushDownLogChan chan *statementLog,
	pushDownWithBatchLogChan chan *statementLog,
) bool {
	execOkStatements := 0
	execFailStatements := 0
	diffFailStatements := 0

	successQueries := new(bytes.Buffer)
	output := new(bytes.Buffer)
	logger := log.New(output, "", log.LstdFlags)

	for {
		noPushDownLog, ok1 := <-noPushDownLogChan
		pushDownWithBatchLog, ok3 := <-pushDownWithBatchLogChan

		allEnd := !(ok1 || ok3)
		if allEnd {
			break
		}
		if !ok1 {
			logger.Panicf("Internal error: NoPushDown channel drained\n")
		}
		if !ok3 {
			logger.Panicf("Internal error: WithPushDown channel drained\n")
		}
		if noPushDownLog.stmt != pushDownWithBatchLog.stmt {
			logger.Panicln("Internal error: Pre-check failed, stmt should be identical",
				noPushDownLog.stmt, pushDownWithBatchLog.stmt)
		}
		if noPushDownLog.stmtIndex != pushDownWithBatchLog.stmtIndex {
			logger.Panicln("Internal error: Pre-check failed, stmtIndex should be identical",
				noPushDownLog.stmtIndex, pushDownWithBatchLog.stmtIndex)
		}

		hasError := false
		if noPushDownLog.hasError || pushDownWithBatchLog.hasError {
			execFailStatements++
			hasError = true
		} else {
			execOkStatements++
		}

		diffFail := false
		if hasError {
			// If there are errors, currently we don't check content and only check existence
			if !noPushDownLog.hasError || !pushDownWithBatchLog.hasError {
				diffFail = true
			}
		} else {
			// If there are no error, check content
			if noPushDownLog.output != pushDownWithBatchLog.output {
				diffFail = true
			}
		}

		if diffFail {
			diffFailStatements++
			logger.Printf("Test fail: Outputs are not matching.\n"+
				"Test case: %s\n"+
				"Statement: #%d - %s\n"+
				"NoPushDown Output: \n%s\n"+
				"WithPushDown Output: \n%s\n\n"+
				"NoPushDown Plan: \n%s\n"+
				"WithPushDown Plan: \n%s\n\n",
				testCasePath,
				noPushDownLog.stmtIndex,
				noPushDownLog.stmt,
				noPushDownLog.output,
				pushDownWithBatchLog.output,
				noPushDownLog.plan,
				pushDownWithBatchLog.plan)
		} else if hasError {
			if *verboseOutput {
				logger.Printf("Warn: Execute fail, diff skipped.\n"+
					"Test case: %s\n"+
					"Statement: #%d - %s\n"+
					"NoPushDown Output: \n%s\n"+
					"WithPushDown Output: \n%s\n\n",
					testCasePath,
					noPushDownLog.stmtIndex,
					noPushDownLog.stmt,
					noPushDownLog.output,
					pushDownWithBatchLog.output)
			}
		} else {
			if *verboseOutput {
				// Output is same and there is no errors
				logger.Printf("Info: SQL result is idential: \n%s\n", noPushDownLog.stmt)
			}

			successQueries.WriteString(noPushDownLog.stmt)
			successQueries.WriteByte('\n')
		}
	}

	logger.Printf("Test summary: non-matching queries: %d, success queries: %d, skipped queries: %d",
		diffFailStatements,
		execOkStatements,
		execFailStatements)

	if diffFailStatements == 0 {
		logger.Printf("Test summary(%s): Test case PASS", testCasePath)
	} else {
		logger.Printf("Test summary(%s): Test case FAIL", testCasePath)
	}

	// combine all output
	log.Println(output.String())

	if diffFailStatements > 0 {
		os.Exit(2)
	}

	if *outputSuccessQueries {
		outputFilePath := testCasePath + ".success"
		logger.Printf("Output success queries to [%s]", outputFilePath)
		expectNoErr(ioutil.WriteFile(outputFilePath, successQueries.Bytes(), 0644))
	}

	return diffFailStatements == 0
}

func buildDefaultConnStr(port int) string {
	return fmt.Sprintf("root@tcp(localhost:%d)/{db}?allowNativePasswords=true", port)
}

func main() {
	connStrNoPush = flag.String("conn-no-push", buildDefaultConnStr(4005), "The connection string to connect to a NoPushDown TiDB instance")
	connStrPushWithBatch = flag.String("conn-push-down", buildDefaultConnStr(4007), "The connection string to connect to a WithPushDown TiDB instance")
	outputSuccessQueries = flag.Bool("output-success", false, "Output success queries of test cases to a file ends with '.success' along with the original test case")
	dbName = flag.String("db", "push_down_test_db", "The database name to run test cases")
	verboseOutput = flag.Bool("verbose", false, "Verbose output")
	includeFiles := flag.String("include", "", "Test cases included in this test (file lists separated by comma)")
	excludeFiles := flag.String("exclude", "", "Test cases excluded in this test (file lists separated by comma)")

	flag.Parse()

	prepareDB(*connStrNoPush)
	prepareDB(*connStrPushWithBatch)

	// Prepare SQL does not apply the filter
	iterateTestCases(testPrepDir, false)

	log.SetOutput(os.Stdout)
	log.Printf("Prepare finished, start testing...")

	// Build the filter
	var includeList, excludeList []string
	if len(*includeFiles) > 0 {
		includeList = strings.Split(*includeFiles, ",")
	}
	if len(*excludeFiles) > 0 {
		excludeList = strings.Split(*excludeFiles, ",")
	}
	fileFilter = func(file string) bool {
		if len(includeList) == 0 && len(excludeList) == 0 {
			return true
		}
		base := filepath.Base(file)
		for _, ex := range excludeList {
			if ex == base {
				return false
			}
		}
		for _, in := range includeList {
			if in == base {
				return true
			}
		}

		if len(excludeList) != 0 {
			return true
		}

		return false
	}
	iterateTestCases(testCaseDir, true)
}
