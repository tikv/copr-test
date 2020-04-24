# GO environment variables
export GO111MODULE=on
export GOPROXY=https://goproxy.io

# These variables should be defined by CI script
# https://internal.pingcap.net/idc-jenkins/job/tikv_ghpr_integration-cop-push-down-test/configure
tidb_src_dir=${tidb_src_dir}
tidb_bin=""
pd_bin=${pd_bin}
tikv_bin=${tikv_bin}
include=${include}
exclude=${exclude}

# All push down function lists
push_down_func_list=$(cat ./functions.txt | paste -sd "," -)

realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

# Build path
readonly copr_test_build_path="$(realpath ./build)"
readonly push_down_test_bin="${copr_test_build_path}/push_down_test_bin"
readonly data_souce="$(realpath ./prepare/0_data.sql)"

echo "+ copr_test_build_path"
echo "$copr_test_build_path"

echo "+ push_down_test_bin"
echo "$push_down_test_bin"

echo "+ data_souce"
echo "$data_souce"

# These log locations should be the same as which in CI script
# https://internal.pingcap.net/idc-jenkins/job/tikv_ghpr_integration_pushdownfunc_test/configure
readonly no_push_down_tidb_log_file="${copr_test_build_path}/tidb_no_push_down.log"
readonly with_push_down_tidb_log_file="${copr_test_build_path}/tidb_with_push_down.log"
readonly with_push_down_tikv_log_file="${copr_test_build_path}/tikv_with_push_down.log"
readonly with_push_down_pd_log_file="${copr_test_build_path}/pd_with_push_down.log"

# Config paths
config_path="$(realpath ./config)"

# Read only variables
readonly tidb_src_url="https://github.com/pingcap/tidb/archive/master.zip"
readonly no_push_down_tidb_port="4005"
readonly with_push_down_tidb_port="4007"
readonly tidb_host="127.0.0.1"
readonly tidb_user="root"
readonly tidb_database="test"
readonly log_level="warn"

# Processes list of all components we launched.
pd_processes=()
tikv_processes=()
tidb_processes=()

set -u

function check_env() {
  # Check PD and TiKV binaries path
  if [ -z "$pd_bin" ]; then
    echo "PD server binary path not specified (pd_bin environment variable not set)"
    exit 1
  fi

  if [ -z "$tikv_bin" ]; then
    echo "TiKV server binary path not specified (tikv_bin environment variable not set)"
    exit 1
  fi
}

function prepare_config() {
  cp -r ${config_path} ${copr_test_build_path}
  config_path="${copr_test_build_path}/config"
  find ${config_path} -type f -exec sed -i 's@\/tmp\/copr_test@'${copr_test_build_path}'@g' {} \;

  no_push_down_config_dir="${config_path}/no_push_down"
  with_push_down_config_dir="${config_path}/with_push_down"
}

# $1: PD binary path
# $2: configuration file
# $3: log file
# $4: log level
# $5: message type: WithPushDown
function run_pd() {
  echo
  echo "+ PD version:"
  $1 --version

  echo
  echo "+ Launching PD for $5 test using config $2"
  $1 -config $2 -log-file $3 -L $4 &

  # Return the PID of the new PD process
  pd_processes+=("$!")
}

# $1: TiKV binary path
# $2: configuration file
# $3: log file
# $4: log level
# $5: message type: WithPushDown
function run_tikv() {
  echo
  echo "+ TiKV version:"
  $1 --version

  echo
  echo "+ Launching TiKV for $5 test using config $2"
  $1 -C $2 --log-file $3 -L $4 &

  # Return the PID of the new TiKV process
  tikv_processes+=("$!")
}

# $1: TiDB binary path
# $2: configuration file
# $3: log file
# $4: log level
# $5: value for failpoint environment variable
# $6: message type: NoPushDown/WithPushDown
function run_tidb() {
  echo
  echo "+ TiDB version:"
  $1 -V

  echo
  echo "+ Launching TiDB for $6 test using config $2"
  export GO_FAILPOINTS="$5"
  $1 -config $2 -log-file $3 -L $4 &

  # Return the PID of the new TiDB process
  tidb_processes+=("$!")
}

function build_tidb() {
  echo
  echo "+ Building TiDB"

  # If `$tidb_src_dir` is not set, download the TiDB master branch for the test
  if [ -z $tidb_src_dir ]; then
    echo "  - TiDB source code path not specified (tidb_src_dir environment variable is not set)"
    echo "  - Downloading TiDB source code from ${tidb_src_url}"

    # Download TiDB source code
    wget ${tidb_src_url} -O ${copr_test_build_path}/tidb_master.zip

    # Unzip the ZIP file
    unzip -q ${copr_test_build_path}/tidb_master.zip -d ${copr_test_build_path}/tidb_master

    tidb_src_dir=${copr_test_build_path}/tidb_master/tidb-master
  fi

  echo "  - Building TiDB binary with failpoint enabled from ${tidb_src_dir}"
  # Enable failpoints
  make -C ${tidb_src_dir} failpoint-enable
  make -C ${tidb_src_dir}
  make -C ${tidb_src_dir} failpoint-disable

  tidb_bin=${tidb_src_dir}/bin/tidb-server
}

function build_tester() {
  echo
  echo "+ Building Push Down Tester"
  go build -o "$push_down_test_bin" ./src
}

function clean_all_proc() {
  for tidb in "${tidb_processes[@]}"; do
    kill -9 "$tidb"
  done

  for tikv in "${tikv_processes[@]}"; do
    kill -9 "$tikv"
  done

  for pd in "${pd_processes[@]}"; do
    kill -9 "$pd"
  done
}

function clean_build() {
  echo
  echo "+ Cleaning up temp directory stale data: ${copr_test_build_path}"
  mkdir -p ${copr_test_build_path}
  rm -rf ${copr_test_build_path}/*
}

function kill_all_proc() {
  echo
  echo "+ Kill all processes"

  pkill -9 -U ${USER} tidb-server
  pkill -9 -U ${USER} tikv-server
  pkill -9 -U ${USER} pd-server
  exit 0
}

function prebuild() {
  check_env
  clean_build
  prepare_config
  build_tidb
  build_tester
}

function no_push_down_prebuild() {
  clean_build
  prepare_config
  build_tidb
}

# $1: second(s) to sleep
# $2: wait target
function my_sleep() {
  echo "  - Sleep ${1}s to wait for ${2} to start"
  sleep ${1}
}

# $1: tidb user
# $2: tidb host
# $3: tidb port
# $4: message type: NoPushDown/WithPushDown
function wait_for_tidb() {
  echo
  echo "+ Waiting TiDB start up ($4)"

  i=0
  while ! mysql --default-character-set utf8 -e 'show databases' -u $1 -h $2 -P $3; do
    i=$((i + 1))
    if [[ "$i" -gt 30 ]]; then
      echo "* Fail to start TiDB"
      exit 1
    fi
    sleep 3
  done
  echo "  - TiDB startup successfully ($4)"
}

# $1: TiKV log file
# $2: message type: WithPushDown
function wait_for_tikv() {
  echo
  echo "+ Waiting TiKV start up ($2)"

  i=0
  while [ ! -f "${1}" ]; do
    i=$((i + 1))
    if [[ "$i" -gt 30 ]]; then
      echo "* Fail to start TiKV ($2)"
      exit 1
    fi
    sleep 2
  done
  echo "  - TiKV startup successfully ($2)"
}

function start_full_test() {
  prebuild

  # Run all PDs
  run_pd ${pd_bin} ${with_push_down_config_dir}/pd.toml ${with_push_down_pd_log_file} ${log_level} "PushWithPushDown"
  my_sleep 3 "PD"

  # Run all TiKVs
  run_tikv ${tikv_bin} ${with_push_down_config_dir}/tikv.toml ${with_push_down_tikv_log_file} ${log_level} "WithPushDown"
  wait_for_tikv ${with_push_down_tikv_log_file} "WithPushDown"

  # Run all tidbs
  run_tidb ${tidb_bin} ${no_push_down_config_dir}/tidb.toml ${no_push_down_tidb_log_file} ${log_level} "" "NoPushDown"
  run_tidb ${tidb_bin} ${with_push_down_config_dir}/tidb.toml ${with_push_down_tidb_log_file} ${log_level} \
    "github.com/pingcap/tidb/expression/PushDownTestSwitcher=return(\"$push_down_func_list\");github.com/pingcap/tidb/expression/PanicIfPbCodeUnspecified=return(true)" \
    "WithPushDown"
  my_sleep 10 "TiDB"

  wait_for_tidb ${tidb_user} ${tidb_host} ${no_push_down_tidb_port} "NoPushDown"
  wait_for_tidb ${tidb_user} ${tidb_host} ${with_push_down_tidb_port} "WithPushDown"

  echo "+ Start test"

  $push_down_test_bin \
    -conn-no-push "${tidb_user}@tcp(${tidb_host}:${no_push_down_tidb_port})/{db}?allowNativePasswords=true" \
    -conn-push-down "${tidb_user}@tcp(${tidb_host}:${with_push_down_tidb_port})/{db}?allowNativePasswords=true" \
    -include "${include}" \
    -exclude "${exclude}"
  readonly exit_code=$?

  echo "+ Test finished"
  echo "  - ${push_down_test_bin} exit code is ${exit_code}"

  clean_all_proc
  exit $exit_code
}

function start_push_down_with_vec_test() {
  prebuild

  run_pd ${pd_bin} ${with_push_down_config_dir}/pd.toml ${with_push_down_pd_log_file} ${log_level} "PushWithPushDown"
  my_sleep 3 "PD"

  run_tikv ${tikv_bin} ${with_push_down_config_dir}/tikv.toml ${with_push_down_tikv_log_file} ${log_level} "WithPushDown"
  wait_for_tikv ${with_push_down_tikv_log_file} "WithPushDown"
  run_tidb ${tidb_bin} ${with_push_down_config_dir}/tidb.toml ${with_push_down_tidb_log_file} ${log_level} \
    "github.com/pingcap/tidb/expression/PushDownTestSwitcher=return(\"$push_down_func_list\");github.com/pingcap/tidb/expression/PanicIfPbCodeUnspecified=return(true)" \
    "WithPushDown"
  my_sleep 10 "TiDB"
  wait_for_tidb ${tidb_user} ${tidb_host} ${with_push_down_tidb_port} "WithPushDown"
  mysql --default-character-set utf8 -u ${tidb_user} -h ${tidb_host} -P ${with_push_down_tidb_port} -D ${tidb_database} <${data_souce}
  mysql --default-character-set utf8 -u ${tidb_user} -h ${tidb_host} -P ${with_push_down_tidb_port} -D ${tidb_database}

  clean_all_proc
}

function start_no_push_down_test() {
  no_push_down_prebuild
  run_tidb ${tidb_bin} ${no_push_down_config_dir}/tidb.toml ${no_push_down_tidb_log_file} ${log_level} "" "NoPushDown"
  my_sleep 10 "TiDB"

  wait_for_tidb ${tidb_user} ${tidb_host} ${no_push_down_tidb_port} "NoPushDown"
  mysql --default-character-set utf8 -u ${tidb_user} -h ${tidb_host} -P ${no_push_down_tidb_port} -D ${tidb_database} <${data_souce}
  mysql --default-character-set utf8 -u ${tidb_user} -h ${tidb_host} -P ${no_push_down_tidb_port} -D ${tidb_database}

  kill -9 ${tidb_processes[0]}
}

if [ "$1" == "full-test" ]; then
  start_full_test
elif [ "$1" == "no-push-down" ]; then
  start_no_push_down_test
elif [ "$1" == "with-push-down" ]; then
  start_push_down_with_vec_test
elif [ "$1" == "clean" ]; then
  clean_build
  kill_all_proc
else
  echo "Wrong command"
  exit 1
fi
