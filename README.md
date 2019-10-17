## What is `copr-test`

The `copr-test` is the integration test for `Coprocessor` of the TiKV. The `Coprocessor` is used to execute TiDB push-down
executor to improve the database performance. It's important to keep execution result consistent between TiDB and `Coprocessor`.
This is the purpose of `copr-test`.

The basic principle of `copr-test` is to execute test cases in TiDB standalone (with `mocktikv`) and TiDB cluster (with `Coprocessor`)
and compare the execution result. We think the TiDB and Coprocessor is consistent if the results in both sides are same, vice versa.
We use `github.com/pingcap/parser` to parse every file, and iterator the []ast.StmtNode to run every SQL.
So if there is any error in the test SQL file, the error msg is hard to read. Creating the database and tables in you local database
and use IDE(such as CLion) to write SQL file as test case is recommended.

The `Coprocessor` contains two execution frameworks, `Batch` (vectorized execution engine) and `Non-Batch` in current
stage (remove the `Non-Batch` version is in plan). So all test cases should be passed in the following execution environment.

1. TiDB with mocktikv
2. TiDB + TiKV with Non-Batch
3. TiDB + TiKV with Batch

### How do I know which expressions will be pushed down?

The `Coprocessor` does not implement all builtin functions (or implemented but not tested fully) which have implemented by TiDB,
so we can only push down the functions that Coprocessor has implemented and fully tested. Whether a function is pushed down or not
is determined by the function `canFuncBePushed` in TiDB [tidb-expression/expr_to_pb.go](https://github.com/pingcap/tidb/blob/a090e6be2991bf85b18fcdb096f84d41f4f6bd85/expression/expr_to_pb.go#L303)

We have added a failpoint `PushDownTestSwitcher` in the function `canFuncBePushed` to hijack our customized push down condition.
And we will push down all functions in our integration tests using `export GO_FAILPOINTS="github.com/pingcap/tidb/expression/PushDownTestSwitcher=return(\"all\")"`, see the `run_tests.sh`[./push-down-test/run-tests.sh].
The test will fail If the test contains some functions which don't be implemented in the Coprocessor.

## How to add test cases?

- Test cases location
    
    All test cases should be placed in `push-down-test/sql` directory (sub dir of push-down-test/sql is also allowed, you can originate
    them in different dir.), and all SQL files will be executed in lexical order by file name.
    So if your case want to prepare some data before running tests, you can add some suffix to the file name, eg: `xxx.1.sql` and `xxx.2.sql`.
    
- Test case file name convention

    How about: Files ends with .sql suffix will be treated as test cases and other files will be ignored.
    
- Test case example

    ```sql
    create table tb2
    (
    date datetime,
    date_2 datetime,
    date_3 datetime
    );
    insert into tb2 (date, date_2, date_3)
    values ('1-1-1:10:10', '1-2-1:10:10', '1-2-1:10:10');
    select *
    from tb2;
    SELECT CAST(date AS time), cast(date_2 as date), cast(date_3 as date)
    from tb2;
    ```

## How to run it in local environment?

Because of the `copr-test` is the integration test for TiKV Coprocessor, so there is a minimal requirement if you want
run the integration test in your local environment.

### Minimal requirement components

- PD: [PD](https://github.com/pingcap/pd) is the abbreviation for Placement Driver. It is used to manage and schedule the TiKV cluster.

    1. Make sure ​Go​ (version 1.12) is installed.
    2. Use `make` to build the PD (the binary will be placed in the `bin` directory).

- TiKV: [Building and setting up a development workspace](https://github.com/tikv/tikv/blob/master/CONTRIBUTING.md#building-and-setting-up-a-development-workspace)
- TiDB: [Building TiDB on a local OS/shell environment](https://github.com/pingcap/community/blob/master/CONTRIBUTING.md#building-tidb-on-a-local-osshell-environment)

The `copr-test` integration test will retrieve the source code of the TiDB master branch automatically (but you can specify the
TiDB source code path by `$tidb_src_dir` instead of using remote latest TiDB source code), so you should only prepare
the build environment for it. The binaries of TiKV and PD should be provided by environment variables (`$pd_bin` and `$tikv_bin`).

### Example guide

```shell
mkdir ~/devel/opensource/
cd ~/devel/opensource
git clone https://github.com/pingcap/pd.git
git clone https://github.com/tikv/copr-test.git
git clone https://github.com/tikv/tikv.git

cd ~/devel/opensource/pd
make

cd ~/devel/opensource/tikv
make

cd ~/devel/opensource/copr-test
pd_bin=~/devel/opensource/pd/bin/pd-server tikv_bin=~/devel/opensource/tikv/target/release/tikv-server make push-down-test
```
