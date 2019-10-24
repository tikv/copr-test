## What is `copr-test`

`copr-test` is the integration test for the `Coprocessor` subproject of TiKV. `Coprocessor` executes TiDB push-down
executors to improve database performance. The purpose of `copr-test` is to keep execution results consistent between TiDB and `Coprocessor`. 

The basic principle of `copr-test` is to execute test cases on a standalone TiDB (with `mocktikv`) and on a TiDB cluster (with `Coprocessor`), 
and compare the execution results. We can conclude that TiDB and Coprocessor are consistent if the results on both sides are the same, and vice versa.

`Coprocessor` contains two execution frameworks, `Batch` (vectorized execution engine) and `Non-Batch` in the current
stage (removing the `Non-Batch` version is on the schedule). So all test cases must be passed in the following execution environments:

- TiDB with mocktikv
- TiDB + TiKV with Non-Batch
- TiDB + TiKV with Batch

### How do I know which expressions will be pushed down?

The `Coprocessor` subproject does not implement (or implemented but not fully tested) all functions of TiDB, 
so we can only push down the functions that are implemented and fully tested for `Coprocessor`. Whether a function is pushed down or not
is determined by `canFuncBePushed` function in TiDB [tidb-expression/expr_to_pb.go](https://github.com/pingcap/tidb/blob/a090e6be2991bf85b18fcdb096f84d41f4f6bd85/expression/expr_to_pb.go#L303)

We have added a [failpoint](https://github.com/pingcap/failpoint) `PushDownTestSwitcher` in `canFuncBePushed` function to hijack our customized push-down conditions.
All functions in our integration tests will be pushed down via `export GO_FAILPOINTS="github.com/pingcap/tidb/expression/PushDownTestSwitcher=return(\"all\")"`.  For details, see `run_tests.sh`[./push-down-test/run-tests.sh].
The test fails if the test contains some functions that are not implemented in `Coprocessor`.

## How to add test cases?

- Test cases location
    
    All test cases should be placed in the `push-down-test/sql` directory (A sub-directory of `push-down-test/sql` is also allowed. You can organize them in different directories), and all SQL files will be executed in alphabetical order by file names.
    If your case requires some data preparation before the test, you can add some suffixes to the file name, for example, `xxx.1.sql` and `xxx.2.sql`.
    
- Test case file name convention

    Files ending with the .sql suffix will be treated as test cases and other files will be ignored.
    
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

## How to run a test case in your local environment?

As the integration test for TiKV Coprocessor, `copr-test` requires a minimal requirement to run 
in your local environment.

### Minimal requirements per component

- PD: [PD](https://github.com/pingcap/pd) is the abbreviation for Placement Driver. It is used to manage and schedule the TiKV cluster.

    1. Make sure ​Go​ (version 1.12) is installed.
    2. Use `make` to build PD (the binary will be placed in the `bin` directory).

- TiKV: [Building and setting up a development workspace](https://github.com/tikv/tikv/blob/master/CONTRIBUTING.md#building-and-setting-up-a-development-workspace)
- TiDB: [Building TiDB on a local OS/shell environment](https://github.com/pingcap/community/blob/master/CONTRIBUTING.md#building-tidb-on-a-local-osshell-environment)

`copr-test` integration test retrieves the source code from the TiDB master branch automatically, but you can also
specify source code of your selection at a local path by using `$tidb_src_dir`. This  means you should only prepare
the build environment for it. The binaries of TiKV and PD are provided via environment variables (`$pd_bin` and `$tikv_bin`).

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
