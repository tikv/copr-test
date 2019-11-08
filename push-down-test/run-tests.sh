#!/usr/bin/env bash

# check the pd and tikv binaries environment
if [ -z $pd_bin ]; then
  echo "PD server binary path not specified (pd_bin environment variable not set)"
  exit 1
fi

if [ -z $tikv_bin ]; then
  echo "TiKV server binary path not specified (tikv_bin environment variable not set)"
  exit 1
fi

# All push down function lists
push_down_func_list=$(cat ./functions.txt | paste -sd "," -)

# these var is define by CI script
# https://internal.pingcap.net/idc-jenkins/job/tikv_ghpr_integration-cop-push-down-test/configure
tidb_src_dir=$tidb_src_dir
tidb_bin=""
pd_bin=$pd_bin
tikv_bin=$tikv_bin
# the hash of tidb_master_bin and pd_master_bin
#tidb_master_sha=$tidb_master_sha
#pd_master_sha=$pd_master_sha
#tikv_cur_sha=$tikv_cur_sha

readonly no_push_down_tidb_port="4005"
readonly push_down_tidb_port="4006"
readonly push_down_with_batch_tidb_port="4007"
readonly tidb_host="127.0.0.1"
readonly tidb_user="root"
readonly log_level="warn"

# This log location should be the same as which in CI script
# https://internal.pingcap.net/idc-jenkins/job/tikv_ghpr_integration_pushdownfunc_test/configure
readonly no_push_down_tidb_log_file="/tmp/copr_test/tidb_no_push_down.log"
readonly push_down_no_batch_tidb_log_file="/tmp/copr_test/tidb_push_down_no_batch.log"
readonly push_down_with_batch_tidb_log_file="/tmp/copr_test/tidb_push_down_with_batch.log"
readonly tikv_no_batch_log_file="/tmp/copr_test/tikv_no_batch.log"
readonly tikv_with_batch_log_file="/tmp/copr_test/tikv_with_batch.log"
readonly pd_no_batch_log_file="/tmp/copr_test/pd_no_batch.log"
readonly pd_with_batch_log_file="/tmp/copr_test/pd_with_batch.log"

readonly no_push_down_config_dir="./config/no_push_down"
readonly push_down_no_batch_config_dir="./config/push_down_no_batch"
readonly push_down_with_batch_config_dir="./config/push_down_with_batch"

readonly push_down_test_bin="./bin/push_down_test_bin"

export GO111MODULE=on
export GOPROXY=https://goproxy.io

set -u

function run_pds() {
  echo
  echo "+ PD version"
  "$pd_bin" --version

  echo
  echo "+ Starting PD"
  "$pd_bin" -config "$push_down_no_batch_config_dir"/pd.toml -log-file "$pd_no_batch_log_file" -L ${log_level} &
  pd_no_batch_pid=$!

  "$pd_bin" -config "$push_down_with_batch_config_dir"/pd.toml -log-file "$pd_with_batch_log_file" -L ${log_level} &
  pd_with_batch_pid=$!
}

function run_tikvs() {
  echo
  echo "+ TiKV version"
  "$tikv_bin" --version

  echo
  echo "+ Starting TiKV"
  "$tikv_bin" -C "$push_down_no_batch_config_dir"/tikv.toml --log-file "$tikv_no_batch_log_file" -L ${log_level} &
  tikv_no_batch_pid=$!

  "$tikv_bin" -C "$push_down_with_batch_config_dir"/tikv.toml --log-file "$tikv_with_batch_log_file" -L ${log_level} &
  tikv_with_batch_pid=$!
}

function run_tidbs() {
  echo
  echo "+ TiDB version"
  "$tidb_bin" -V

  echo
  echo "+ Starting TiDB"
  export GO_FAILPOINTS=""
  "$tidb_bin" -log-file "$no_push_down_tidb_log_file" -config "$no_push_down_config_dir"/tidb.toml -L ${log_level} &
  tidb_no_push_down_pid=$!

  export GO_FAILPOINTS="github.com/pingcap/tidb/expression/PushDownTestSwitcher=return(\"$push_down_func_list\")"
  "$tidb_bin" -log-file "$push_down_no_batch_tidb_log_file" -config "$push_down_no_batch_config_dir"/tidb.toml -L ${log_level} &
  tidb_push_down_no_batch_pid=$!

  export GO_FAILPOINTS="github.com/pingcap/tidb/expression/PushDownTestSwitcher=return(\"$push_down_func_list\")"
  "$tidb_bin" -log-file "$push_down_with_batch_tidb_log_file" -config "$push_down_with_batch_config_dir"/tidb.toml -L ${log_level} &
  tidb_push_down_with_batch_pid=$!
}

# make sure that after run this function,
# the current working dir is not change
function build_tidb() {
  echo
  echo "+ Building TiDB"
  if [ -z $tidb_src_dir ]; then
    echo "  - TiDB source code path not specified (tidb_src_dir environment variable is not set)"
    readonly tidb_src_url="https://github.com/pingcap/tidb/archive/master.zip"
    echo "  - Downloading TiDB source code from ${tidb_src_url}"
    mkdir -p /tmp/copr_test/
    rm -rf /tmp/copr_test/tidb_master /tmp/copr_test/tidb_master.zip
    wget ${tidb_src_url} -O /tmp/copr_test/tidb_master.zip
    unzip /tmp/copr_test/tidb_master.zip -d /tmp/copr_test/tidb_master
    tidb_src_dir=/tmp/copr_test/tidb_master/tidb-master
  fi

  echo "  - Building TiDB binary with failpoint enabled from ${tidb_src_dir}"
  cur_dir=$(pwd)
  cd ${tidb_src_dir}
  make failpoint-enable
  make
  tidb_bin=$(pwd)/bin/tidb-server
  cd ${cur_dir}
}

function build_tester() {
  echo
  echo "+ Building Push Down Tester"
  echo "  - Building from ${push_down_test_bin}"
  go build -o "$push_down_test_bin" ./src
}

function cat_log() {
  echo "no push down tidb log (this tidb use mocktikv, so has no pd and tikv log)"
  cat "$no_push_down_tidb_log_file"
  echo
  echo

  echo "push down no batch tidb log"
  cat "$push_down_no_batch_tidb_log_file"
  echo
  echo "push down no batch tikv log"
  cat "$tikv_no_batch_log_file"
  echo
  echo "push down no batch pd log"
  cat "$pd_no_batch_log_file"
  echo
  echo

  echo "push down with batch tidb log"
  cat "$push_down_with_batch_tidb_log_file"
  echo
  echo "push down with batch tikv log"
  cat "$tikv_with_batch_log_file"
  echo
  echo "push down with batch pd log"
  cat "$pd_with_batch_log_file"
  echo
  echo
}

function kill_all_proc() {
  echo
  echo "+ Killing existing tidb / tikv / pd process"
  killall -9 tidb-server
  killall -9 tikv-server
  killall -9 pd-server
}

function clear_data() {
  echo
  echo "+ Cleaning up temp directory stale data: /tmp/copr_test"
  rm -rf "/tmp/copr_test"
}

function my_sleep() {
  second=$1
  name=$2
  echo "  - Sleep ${second}s to wait for ${name} to start"
  sleep ${second}
}

function wait_for_tidb() {
  echo
  echo "+ Waiting TiDB start up"

  echo "  - Waiting TiDB (no push down)"
  i=0
  while ! mysql -u$tidb_user -h$tidb_host -P$no_push_down_tidb_port --default-character-set utf8 -e 'show databases;'; do
    i=$((i + 1))
    if [[ "$i" -gt 30 ]]; then
      echo '* Failed to start TiDB'
      exit 1
    fi
    sleep 3
  done
  echo '  - TiDB startup successfully (no push down)'

  echo "  - Waiting TiDB (push down without vectorization)"
  i=0
  while ! mysql -u$tidb_user -h$tidb_host -P$push_down_tidb_port --default-character-set utf8 -e 'show databases;'; do
    i=$((i + 1))
    if [[ "$i" -gt 30 ]]; then
      echo '* Failed to start TiDB'
      exit 1
    fi
    sleep 3
  done
  echo '  - TiDB startup successfully (push down without vectorization)'

  echo "  - Waiting TiDB (push down with vectorization)"
  i=0
  while ! mysql -u$tidb_user -h$tidb_host -P$push_down_with_batch_tidb_port --default-character-set utf8 -e 'show databases;'; do
    i=$((i + 1))
    if [[ "$i" -gt 30 ]]; then
      echo '* Failed to start TiDB'
      exit 1
    fi
    sleep 3
  done
  echo '  - TiDB startup successfully (push down with vectorization)'
}

clear_data
kill_all_proc
# this will set tidb_bin env var
build_tidb
build_tester
# make sure that three tidb use different tikv and pd (for example, one is mocktikv, one is tikv1 one is tikv2)
run_pds
my_sleep 3 "PD"
run_tikvs
my_sleep 3 "TiKV"
run_tidbs
my_sleep 10 "TiDB"
wait_for_tidb

echo
echo "+ Test Configurations"
echo "  - tidb_no_push_down_pid=${tidb_no_push_down_pid}"
echo "  - tikv_no_batch_pid=${tikv_no_batch_pid}"
echo "  - pd_no_batch_pid=${pd_no_batch_pid}"
echo "  - tidb_push_down_no_batch_pid=${tidb_push_down_no_batch_pid}"
echo "  - tikv_with_batch_pid=${tikv_with_batch_pid}"
echo "  - pd_with_batch_pid=${pd_with_batch_pid}"
echo "  - tidb_push_down_with_batch_pid=${tidb_push_down_with_batch_pid}"

echo
echo "+ Start test"

./$push_down_test_bin \
  -conn-no-push "${tidb_user}@tcp(${tidb_host}:${no_push_down_tidb_port})/{db}?allowNativePasswords=true" \
  -conn-push "${tidb_user}@tcp(${tidb_host}:${push_down_tidb_port})/{db}?allowNativePasswords=true" \
  -conn-push-with-batch "${tidb_user}@tcp(${tidb_host}:${push_down_with_batch_tidb_port})/{db}?allowNativePasswords=true"
readonly exit_code=$?

echo "+ Test finished"
echo "  - ${push_down_test_bin} exit code is ${exit_code}"
if [[ $exit_code -ne 2 && $exit_code -ne 0 ]]; then
  cat_log
fi

kill_all_proc
exit $exit_code
