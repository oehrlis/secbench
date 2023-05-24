#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: sb_run.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
# Editor.....: Stefan Oehrli
# Date.......: 2023.05.19
# Revision...: 
# Purpose....: Script to run a bunch of swingbench tests
# Notes......: --
# Reference..: https://github.com/oehrlis/secbench
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
DEFAULT_SB_SEED_DB="sbpdb_seed"     # default name for the SecBench seed database
DEFAULT_SB_SECBENCH_DB="sbpdb_run"  # default name for the SecBench PDB
DEFAULT_SB_PASSWORD=""              # default value for the default password
DEFAULT_SB_KEEP_PDB="FALSE"         # default value for flag to keep pdbs of each test
# - End of Customization -------------------------------------------------------

# - Default Values -------------------------------------------------------------
# source genric environment variables and functions
export SB_SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
export SB_BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SB_ETC_DIR="$(dirname ${SB_BIN_DIR})/etc"
export SB_LOG_DIR="$(dirname ${SB_BIN_DIR})/log"

# define logfile and logging
export LOG_BASE=${LOG_BASE:-"$SB_LOG_DIR"}  # Use script directory as default logbase
# Define Logfile but first reset LOG_BASE if directory does not exists
if [ ! -d ${LOG_BASE} ] || [ ! -w ${LOG_BASE} ] ; then
    echo "INFO : set LOG_BASE to /tmp"
    export LOG_BASE="/tmp"
fi
TIMESTAMP=$(date "+%Y.%m.%d_%H%M%S")
readonly LOGFILE="$LOG_BASE/$(basename $SB_SCRIPT_NAME .sh)_$TIMESTAMP.log"

# define a few constants / string variables
SB_SETUP="setup.sh"
SB_REMOVE="remove.sh"
# - EOF Default Values ---------------------------------------------------------

# todo: Variables to check
# ORACLE_HOME
# SB_SEED_DB
# SB_SECBENCH_DB
# whole charbench variables...
# todo: check oracle home

# - Functions ------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Function...: Usage
# Purpose....: Display Usage and exit script
# ------------------------------------------------------------------------------
function Usage() {
    # define default values for function arguments
    error=${1:-"0"}                 # default error number
    error_value=${2:-""}            # default error message
    cat << EOI

  Usage: ${SB_SCRIPT_NAME} [options] [benchmark options] [benchmark]

  where:
    benchmark	        Comma separated list of security benchmarks.

  Common Options:
    -h                  Usage this message
    -v                  Enable verbose mode (default \$SB_VERBOSE=${SB_VERBOSE})
    -d                  Enable debug mode (default \$SB_DEBUG=${SB_DEBUG})
 
  benchmark options:
    -B <BENCHMARK>      Name of the benchmark to run (mandatory). Can be a comma
                        separated list of security benchmarks. Whereby each benchmark
                        must have valid a regular setup.sh as well remove.sh scrip
                        it the benchmark folder $SB_CONF_DIR
    -c <CONFIG FILE>    Name of the configuration file to be loaded beside the default
                        configuration files.
    -n                  Dry run mode. Show what would be done but do not actually do it
    -F                  Force mode to delete the seed PDB
    -P                  Prepared mode enabled. PDB hast to be created manually
    -L                  List available benchmarks in $SB_CONF_DIR

  Configuration file:
    The script does load configuration files to define default values as an
    alternative for command line parameter. e.g. to set charbench configuration
    etc. The configuration files are loaded in the following order:

$((get_list_of_config && echo "Command line parameter")|cat -b)

  Logfile : ${LOGFILE}

EOI
    dump_runtime_config     # dump current tool specific environment in debug mode
    clean_quit ${error} ${error_value}  
}

# ------------------------------------------------------------------------------
# Function...: list_benchmarks
# Purpose....: List available benchmarks
# ------------------------------------------------------------------------------
function list_benchmarks() {
    ls $SB_CONF_DIR

    echo "Available Security Benchmark Configurations:"
    echo
    for i in $SB_CONF_DIR/*/$SB_SETUP; do
        bench=$(basename $(dirname $i))
        readme=$(dirname $i)/README.md
        if [ -f "$readme" ]; then
            title=$(head -1 $readme |cut -d' ' -f2-)
        else
            title="n/a"
        fi
        printf '%s%s %s\n' "${bench}" "${padding:${#bench}}: " "${title}"
    done
    clean_quit 0
}
# - EOF Functions --------------------------------------------------------------

# - Initialization -------------------------------------------------------------
# Define a bunch of bash option see 
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o nounset      # stop script if variables and parameters are unset
set -o errexit      # Exit immediately if a pipeline, a list or a compound command returns a non-zero status
set -o pipefail     # pipefail exit after 1st piped commands failed

# initialize logfile
touch $LOGFILE 2>/dev/null
exec &> >(tee -a "$LOGFILE")                # Open standard out at `$LOG_FILE` for write.  
exec 2>&1  

echo "INFO : Start $SB_SCRIPT_NAME on host $(hostname) at $(date)"

# source common variables and functions from sb_functions.sh
if [ -f ${SB_BIN_DIR}/sb_functions.sh ]; then
    . ${SB_BIN_DIR}/sb_functions.sh
else
    echo "ERROR: Can not find common functions ${SB_BIN_DIR}/sb_functions.sh"
    exit 5
fi

trap on_term TERM SEGV      # handle TERM SEGV using function on_term
trap on_int INT             # handle INT using function on_int
load_config                 # load configur26ation files. File list in SB_CONFIG_FILES

# update patch with swingbench if it is available in secbench folder
if [ -d "$SB_BASE/swingbench" ]; then
    echo "INFO : Add local swingbench/bin folder to PATH"
    update_path $SB_BASE/swingbench/bin
else
    echo_warn "WARN : can not find local swingbench folder below $SB_BASE"
    echo_warn "WARN : make sure you swingbench is accessible via PATH"
    echo_warn "WARN : other wise use sb_get_swingbench.sh to download a local swingbench copy"
fi

check_tools             # check if we do have the required tools available
dump_runtime_config     # dump current tool specific environment in debug mode

# get options
while getopts hvdLkFPnB:E: CurOpt; do
    case ${CurOpt} in
        h) Usage 0;;
        v) TVDLDAP_VERBOSE="TRUE" ;;
        d) TVDLDAP_DEBUG="TRUE" ;;
        n) SB_DRYRUN="TRUE";;
        F) SB_FORCE="TRUE";; 
        P) SB_PREPARED="TRUE";; 
        L) list_benchmarks;; 
        B) SB_USE_CASES=$(echo $OPTARG | tr "," " ");;
        k) SB_KEEP_PDB="TRUE";;
        E) clean_quit "${OPTARG}";;
        *) Usage 2 $*;;
    esac
done

# Default values
export SB_KEEP_PDB=${SB_KEEP_PDB:-$DEFAULT_SB_KEEP_PDB}
export SB_SEED_DB=${SB_SEED_DB:-$DEFAULT_SB_SEED_DB}
export SB_SECBENCH_DB=${SB_SECBENCH_DB:-$DEFAULT_SB_SECBENCH_DB}
export SB_PASSWORD=${SB_PASSWORD:-$DEFAULT_SB_PASSWORD}
export SB_DBA_PASSWORD=${SB_DBA_PASSWORD:-$DEFAULT_SB_DBA_PASSWORD}
export SB_DBA_USER=${SB_DBA_USER:-$DEFAULT_SB_DBA_USER}
export SB_USER=${SB_USER:-$DEFAULT_SB_USER}
export SB_SCALE=${SB_SCALE:-$DEFAULT_SB_SCALE}

# convert to upper case
export SB_SEED_DB=${SB_SEED_DB^^}
export SB_SECBENCH_DB=${SB_SECBENCH_DB^^}

# get secbench password
if [ -z "$SB_PASSWORD" ]; then
    if [ -f "$SB_ETC_DIR/.${SB_BASE_NAME}_password.txt" ]; then
        echo "INFO : found pwd file $SB_ETC_DIR/.${SB_BASE_NAME}_password.txt"
        SB_PASSWORD=$(cat $SB_ETC_DIR/.${SB_BASE_NAME}_password.txt)
    else
        clean_quit 28 "SOE Schema"
    fi
fi

# get OS user password
if [ -z "$SB_OS_PWD" ]; then
    if [ -f "$SB_ETC_DIR/.${SB_OS_USER}_password.txt" ]; then
        echo "INFO : found pwd file $SB_ETC_DIR/.${SB_OS_USER}_password.txt"
        SB_OS_PWD=$(cat $SB_ETC_DIR/.${SB_OS_USER}_password.txt)
    else
        clean_quit 28 "SOE $SB_OS_USER"
    fi
fi

# create output folder
mkdir -p $SB_OUTPUT_DIR

# - EOF Initialization ---------------------------------------------------------

# - Main -----------------------------------------------------------------------

set +o errexit                              # temporary disable errexit
echo "INFO : Run SecBench on $ORACLE_SID in $SB_SECBENCH_DB"
echo "INFO : Using the following configuration values:"
echo "INFO : SB_SEED_DB........ : $SB_SEED_DB"
echo "INFO : SB_USE_CASES...... : $SB_USE_CASES"
echo "INFO : SB_INTERVAL....... : $SB_INTERVAL"
echo "INFO : SB_KEEP_PDB....... : $SB_KEEP_PDB"
echo "INFO : SB_DBA_USER....... : $SB_DBA_USER"
echo "INFO : SB_DBA_PASSWORD... : $SB_DBA_PASSWORD"
echo "INFO : SB_USER........... : $SB_USER"
echo "INFO : SB_PASSWORD....... : $SB_PASSWORD"
echo "INFO : SB_SCALE.......... : $SB_SCALE"

for bench in $SB_USE_CASES; do
    echo "INFO : [$bench] ======================================================================="
    echo "INFO : Start Sec Bench for $bench"
    if [ -d "$SB_CONF_DIR/$bench" ] && [ -x "$SB_CONF_DIR/$bench/$SB_SETUP" ] && [ -x "$SB_CONF_DIR/$bench/$SB_REMOVE" ]; then

        if [ ${SB_KEEP_PDB} == "TRUE" ]; then
            SB_SECBENCH_DB="SBPDB_${bench^^}"
            if pdb_exists $SB_SECBENCH_DB; then
                if force_enabled; then
                    echo "INFO : recreate SecBench PDB $SB_SECBENCH_DB from $SB_SEED_DB"
                    drop_pdb $SB_SECBENCH_DB
                    create_pdb $SB_SEED_DB $SB_SECBENCH_DB
                else
                    clean_quit 40 $SB_SECBENCH_DB
                fi
            elif prepared_enabled; then
                echo "INFO : SecBench PDB $SB_SECBENCH_DB prepared. No setup performed"
            else
                echo "INFO : create SecBench PDB $SB_SECBENCH_DB from $SB_SEED_DB"
                create_pdb $SB_SEED_DB $SB_SECBENCH_DB
            fi
        else
            echo "INFO : recreate SecBench PDB $SB_SECBENCH_DB from $SB_SEED_DB"
            drop_pdb $SB_SECBENCH_DB
            create_pdb $SB_SEED_DB $SB_SECBENCH_DB
        fi

        if pdb_exists $SB_SECBENCH_DB && ! prepared_enabled; then
            echo "INFO : prepare and setup configuration for $bench"
            $SB_CONF_DIR/$bench/$SB_SETUP $SB_SECBENCH_DB $SB_OUTPUT_DIR
        elif prepared_enabled; then
            echo "INFO : SecBench PDB $SB_SECBENCH_DB prepared. No setup performed"
        elif dryrun_enabled; then
            echo "INFO : Dry run enabled, skip $SB_SETUP for $bench in $SB_SECBENCH_DB"
        else
            clean_quit 40 $SB_SECBENCH_DB
        fi

        for uc in $SB_INTERVAL; do
            echo "INFO : [$bench] - $uc ------------------------------------------------------------------------"
            echo "INFO : [$bench] create AWR snapshot in $SB_SECBENCH_DB"
            create_awr_snapshot $SB_SECBENCH_DB

            echo "INFO : [$bench] start charbench at $(date "+%H:%M:%S") for $SB_RUNTIME with $uc concurrent users"
            run_charbench $bench $uc
            
            echo "INFO : [$bench] create AWR snapshot in $SB_SECBENCH_DB"
            create_awr_snapshot $SB_SECBENCH_DB

            echo "INFO : [$bench] create AWR report for $SB_SECBENCH_DB $bench $uc"
            create_awr_report "$SB_SECBENCH_DB" "$bench" "$uc"
        done

        if pdb_exists $SB_SECBENCH_DB; then
            echo "INFO : remove configuration for $bench"
            $SB_CONF_DIR/$bench/$SB_REMOVE $SB_SECBENCH_DB $SB_OUTPUT_DIR
        elif dryrun_enabled; then
            echo "INFO : Dry run enabled, skip $SB_REMOVE for $bench in $SB_SECBENCH_DB"
        else
            clean_quit 40 $SB_SECBENCH_DB
        fi
    else
        echo_warn "WARN : can not find benchmark config folder "
        echo_warn "WARN : skip benchmark $bench"
    fi
done

clean_quit 0                                # we are done, successfully quit
# --- EOF ----------------------------------------------------------------------
