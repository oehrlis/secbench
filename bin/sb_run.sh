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
DEFAULT_SEED_DB="sbseed"            # default name for the SecBench seed database
DEFAULT_SECBENCH_DB="sbdb00"        # default name for the SecBench seed database
DEFAULT_SB_PASSWORD=""              # default value for the default password
# - End of Customization -------------------------------------------------------

# - Default Values -------------------------------------------------------------
# source genric environment variables and functions
export SB_SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
export SB_BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SB_LOG_DIR="$(dirname ${SB_BIN_DIR})/log"
export SB_SQL_DIR="$(dirname ${SB_BIN_DIR})/sql"
export SB_ETC_DIR="$(dirname ${SB_BIN_DIR})/etc"
export SB_OUT_DIR="$(dirname ${SB_BIN_DIR})/output"
export SB_CONF_DIR="$(dirname ${SB_BIN_DIR})/conf"
export SB_SEED_DB=${1:-$DEFAULT_SEED_DB}
export SECBENCH_DB=${2:-$DEFAULT_SECBENCH_DB}

# define logfile and logging
export LOG_BASE=${LOG_BASE:-"$SCRIPT_BIN_DIR"}  # Use script directory as default logbase
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
SB_KEEP_PDB="FALSE"
# - EOF Default Values ---------------------------------------------------------

# todo: Variables to check
# ORACLE_HOME
# SB_SEED_DB
# SECBENCH_DB
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

  Usage: ${SB_SCRIPT_NAME} [options]

  where:
    services	        Comma separated list of Oracle Net Service Names to search

  Common Options:
    -m                  Usage this message
    -v                  Enable verbose mode (default \$SB_VERBOSE=${SB_VERBOSE})
    -d                  Enable debug mode (default \$SB_DEBUG=${SB_DEBUG})

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
while getopts hvdE: CurOpt; do
    case ${CurOpt} in
        h) Usage 0;;
        v) TVDLDAP_VERBOSE="TRUE" ;;
        d) TVDLDAP_DEBUG="TRUE" ;;
        E) clean_quit "${OPTARG}";;
        *) Usage 2 $*;;
    esac
done

# get secbench password
if [ -z "$SB_PASSWORD" ]; then
    if [ -f "$SB_ETC_DIR/.default_secbench_password.txt" ]; then
        echo "INFO : found pwd file $SB_ETC_DIR/.default_secbench_password.txt"
        SB_PASSWORD=$(cat $SB_ETC_DIR/.default_secbench_password.txt)
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
echo "INFO : Run SecBench on $ORACLE_SID in $SECBENCH_DB"

for bench in $SB_USE_CASES; do
    echo "INFO : [$bench] ======================================================================="
    echo "INFO : Start Sec Bench for $bench"
    if [ -d "$SB_CONF_DIR/$bench" ] && [ -x "$SB_CONF_DIR/$bench/$SB_SETUP" ] && [ -x "$SB_CONF_DIR/$bench/$SB_REMOVE" ]; then

        
        if [ ${SB_KEEP_PDB} == "TRUE" ]; then
            SECBENCH_DB="SB_${bench^^}"
            echo "INFO : create SecBench PDB $SECBENCH_DB from $SB_SEED_DB"
            echo create_pdb $SB_SEED_DB $SECBENCH_DB
        else
            echo "INFO : recreate SecBench PDB $SECBENCH_DB from $SB_SEED_DB"
            echo drop_pdb $SECBENCH_DB
            echo create_pdb $SB_SEED_DB $SECBENCH_DB
        fi

        echo "INFO : prepare and setup configuration for $bench"
        $SB_CONF_DIR/$bench/$SB_SETUP

        for uc in $SB_INTERVAL; do
            echo "INFO : [$bench] - $uc ------------------------------------------------------------------------"
            echo "INFO : [$bench] create AWR snapshot in $SECBENCH_DB"
            echo create_awr_snapshot $SECBENCH_DB

            echo "INFO : [$bench] run charbench for $uc concurrent users"
            echo run_charbench $uc
            
            echo "INFO : [$bench] create AWR snapshot in $SECBENCH_DB"
            echo create_awr_snapshot $SECBENCH_DB

            echo "INFO : [$bench] create AWR report"
            echo create_awr_report
        done

        echo "INFO : remove configuration for $bench"
        $SB_CONF_DIR/$bench/$SB_REMOVE
    else
        echo_warn "WARN : can not find benchmark config folder "
        echo_warn "WARN : skip benchmark $bench"
    fi
done

clean_quit 0                                # we are done, successfully quit
# --- EOF ----------------------------------------------------------------------
