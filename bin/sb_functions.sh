#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: SB_functions.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2023.05.19
# Version....: 
# Purpose....: Common functions used by the SecBench bash scripts.
# Notes......: --
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

# - Customization --------------------------------------------------------------
# - just add/update any kind of customized environment variable here
SB_DEFAULT_KEEP_LOG_DAYS=90
DEFAULT_TOOLS=${DEFAULT_TOOLS:-"sqlplus oewizard charbench java"} # List of default tools
SWINGBENCH_BASE=
# - End of Customization -------------------------------------------------------

# Define a bunch of bash option see 
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# https://www.davidpashley.com/articles/writing-robust-shell-scripts/
# set -o nounset                      # exit if script try to use an uninitialised variable
# set -o errexit                      # exit script if any statement returns a non-true return value
# set -o pipefail                     # pipefail exit after 1st piped commands failed

# - Environment Variables ------------------------------------------------------
# define generic environment variables
VERSION=v0.0.0
SB_VERBOSE=${SB_VERBOSE:-"FALSE"}                     # enable verbose mode
SB_DEBUG=${SB_DEBUG:-"FALSE"}                         # enable debug mode
SB_QUIET=${SB_QUIET:-"FALSE"}                         # enable quiet mode
TEMPFILE=${TEMPFILE:-""}
LOCAL_SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
export SB_BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SB_LOG_DIR="$(dirname ${SB_BIN_DIR})/log"
export SB_SQL_DIR="$(dirname ${SB_BIN_DIR})/sql"
export SB_OUT_DIR="$(dirname ${SB_BIN_DIR})/output"
export SB_CONF_DIR="$(dirname ${SB_BIN_DIR})/conf"
export SB_OUTPUT_DIR="$SB_OUT_DIR/$(basename ${SB_SCRIPT_NAME} .sh)_$TIMESTAMP"
export SB_BASE=$(dirname ${SB_BIN_DIR})
export SB_BASE_NAME="secbench"
export SB_CONFIG_FILES=""
export SB_BASE_SHORT_NAME="sb"
export SB_KEEP_LOG_DAYS=${SB_KEEP_LOG_DAYS:-$SB_DEFAULT_KEEP_LOG_DAYS}
padding='............................'

# initialize common variables
export HOME=${HOME:-~}
export SB_DRYRUN=${SB_DRYRUN:-"FALSE"}
export SB_FORCE=${SB_FORCE:-"FALSE"}
# Define the color for the output 
export SB_ANSI_INFO="\e[96m%b\e[0m" 
export SB_ANSI_SUCCESS="\e[92m%b\e[0m" 
export SB_ANSI_WARNING="\e[93m%b\e[0m" 
export SB_ANSI_DEBUG="\e[94m%b\e[0m" 
export SB_ANSI_ERROR="\e[91m%b\e[0m" 
# - EOF Environment Variables --------------------------------------------------

# - Functions ------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Function...: force_enabled
# Purpose....: Check if FORCE mode is enabled
# ------------------------------------------------------------------------------
function force_enabled () {
    if [ "${SB_FORCE^^}" == "TRUE" ]; then
        return 0
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Function...: dryrun_enabled
# Purpose....: Check if DRYRUN mode is enabled
# ------------------------------------------------------------------------------
function dryrun_enabled () {
    if [ "${SB_DRYRUN^^}" == "TRUE" ]; then
        return 0
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Function...: command_exists
# Purpose....: Check if a command does exists
# ------------------------------------------------------------------------------
function command_exists () {
    command -v $1 >/dev/null 2>&1;
}

# ------------------------------------------------------------------------------
# Function...: check_tools
# Purpose....: Check if the required tools are installed
# ------------------------------------------------------------------------------
function check_tools() {
    TOOLS="$DEFAULT_TOOLS ${1:-""}"
    echo_debug "DEBUG: List of tools to check: ${TOOLS}"
    for i in ${TOOLS}; do
        if ! command_exists ${i}; then
            clean_quit 10 ${i} 
            exit 1
        fi
    done
}

# ------------------------------------------------------------------------------
# Function...: echo_debug
# Purpose....: Echo only if SB_DEBUG variable is true
# ------------------------------------------------------------------------------
function echo_debug () {
    text=${1:-""}
    if [ "${SB_DEBUG^^}" == "TRUE" ]; then
        printf $SB_ANSI_DEBUG'\n' "$text" 1>&2
    fi
}

# ------------------------------------------------------------------------------
# Function...: echo_warn
# Purpose....: Echo with color
# ------------------------------------------------------------------------------
function echo_warn () {
    text=${1:-""}
    printf $SB_ANSI_WARNING'\n' "$text" 1>&2
}

# ------------------------------------------------------------------------------
# Function...: echo_stderr
# Purpose....: Echo errors to STDERR
# ------------------------------------------------------------------------------
function echo_stderr () {
    text=${1:-""}
    echo $text 1>&2
}

# ------------------------------------------------------------------------------
# Function...: echo_secret
# Purpose....: mask secret variable
# ------------------------------------------------------------------------------
function echo_secret () {
    string=${1:-""}
    if [ -n "${string}" ]; then
        echo "xxxxxxxx"
    else
        echo "undef"
    fi
}

# ------------------------------------------------------------------------------
# Function...: clean_quit
# Purpose....: Clean exit for all scripts
# ------------------------------------------------------------------------------
function clean_quit() {

    # define default values for function arguments
    error=${1:-"0"}
    error_value=${2:-""}
    SB_SCRIPT_NAME=${SB_SCRIPT_NAME:-${LOCAL_SCRIPT_NAME}}

    # remove tempfiles
    if [ -f "$TEMPFILE" ]; then rm $TEMPFILE; fi
    rotate_logfiles             # rotate old logfiles

    case ${error} in

        0)  printf $SB_ANSI_SUCCESS'\n' "INFO : Successfully finish ${SB_SCRIPT_NAME}";;
        1)  printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Wrong amount of arguments. See usage for correct one." ;;
        2)  printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Wrong arguments (${error_value}). See usage for correct one." >&2;;
        3)  printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Missing mandatory argument (${error_value}). See usage ..." >&2;;
        5)  printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Missing common function file (${error_value}) to source." >&2;;
        10) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Command ${error_value} isn't installed/available on this system..." >&2;;
        20) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. File ${error_value} already exists..." >&2;;
        21) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Directory ${error_value} is not writeable..." >&2;;
        22) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Can not read file ${error_value} ..." >&2;;
        23) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Can not write file ${error_value} ..." >&2;;
        24) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Can not create skip/reject files in ${error_value} ..." >&2;;
        25) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Can not read file password file ${error_value} ..." >&2;;
        26) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Can not write tempfile file ${error_value} ..." >&2;;
        27) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Invalid password file ${error_value} ..." >&2;;
        28) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Missing password for ${error_value:-'n/a'} ..." >&2;;
        33) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Error running ${error_value} ..." >&2;;
        40) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. PDB ${error_value} does exits ..." >&2;;
        41) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. PDB ${error_value} does not exits ..." >&2;;
        90) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Received signal SIGINT / Interrupt / CTRL-C ..." >&2;;
        91) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Received signal TERM to terminate the script ..." >&2;;
        92) printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${error}. Received signal ..." >&2;;
        99) printf $SB_ANSI_INFO'\n'  "INFO : Just wanna say hallo.";;
        ?)  printf $SB_ANSI_ERROR'\n' "ERROR: Exit Code ${1}. Unknown Error.";;
    esac

    exit ${error}
}

# ------------------------------------------------------------------------------
# Function...: on_int
# Purpose....: function to handle interupt by CTRL-C
# ------------------------------------------------------------------------------
function on_int() {
  printf $SB_ANSI_ERROR'\n' "You hit CTRL-C, are you sure ? (y/n)"
  read answer
  if [[ ${answer} = "y" ]]; then
    printf $SB_ANSI_ERROR'\n' "OK, lets quit then"
    clean_quit 90
  else
    printf $SB_ANSI_ERROR'\n' "OK, lets continue then"
  fi
}

# ------------------------------------------------------------------------------
# Function...: on_term
# Purpose....: function to handle TERM signal
# ------------------------------------------------------------------------------
function on_term() {
  printf $SB_ANSI_ERROR'\n' "I have recived a terminal signal. Terminating script..."
  clean_quit 91
}

# ------------------------------------------------------------------------------
# Function...: get_list_of_config
# Purpose....: create a list of configuration files
# ------------------------------------------------------------------------------
function get_list_of_config() {
    ETC_PATH=""
    if [ "${SB_ETC_DIR}" == "${ETC_BASE}" ]; then
        ETC_PATH=${SB_ETC_DIR}
    else
        ETC_PATH="${SB_ETC_DIR} ${ETC_BASE}"
    fi
    DEFAULT_SB_CONFIG_FILES=""
    for i in $ETC_PATH; do
        for n in ${SB_BASE_NAME}; do
            for m in ".conf" "_custom.conf"; do
                echo $i/$n$m
            done
        done
    done
}

# ------------------------------------------------------------------------------
# Function...: get_db_host
# Purpose....: get the host name / ip of the database server
# ------------------------------------------------------------------------------
function get_db_host() {
    echo $(lsnrctl status|grep -iv xdb|grep -i host |sed 's/.*(HOST=\(.*\))(.*/\1/')
}

# ------------------------------------------------------------------------------
# Function...: get_db_port
# Purpose....: get the port database server
# ------------------------------------------------------------------------------
function get_db_port() {
    echo $(lsnrctl status|grep -iv xdb|grep -i host |sed 's/.*(PORT=\([0-9]*\).*/\1/')
}

# ------------------------------------------------------------------------------
# Function...: get_db_service
# Purpose....: get the service name of the PDB
# ------------------------------------------------------------------------------
function get_db_service() {
    pdb=${1:-$SB_SEED_DB}
    echo $(lsnrctl status|grep -iv xdb|grep -i $pdb|sed 's/.*"\(.*\)".*/\1/')
}
# ------------------------------------------------------------------------------
# Function...: update_path
# Purpose....: multipurpose function to manipulate PATH variable
# Usage......: 
#   update_path /new/directory              Prepend the directory to the beginning of PATH variable
#   update_path /new/directory after        Append the directory to the end of PATH variable
#   update_path /new/directory remove       Removes the directory from PATH variable
#   update_path                             Removes any dublicates from PATH variable
# ------------------------------------------------------------------------------
function update_path () {
    directory=${1:-""}
    task=${2:-""}
    case ":${PATH}:" in
        *:"$directory":*)
            if [ "$task" = "remove" ]; then
                # remove directory from PATH
                PATH=:$PATH:
                PATH=${PATH//:$directory:/:}
                PATH=${PATH#:}; PATH=${PATH%:}
            fi;;
        *)
            if [ -d "$directory" ]; then
                if [ "$task" = "after" ] ; then
                    # append directory to PATH
                    PATH=$PATH:$directory
                else
                    # prepend directory to PATH
                    PATH=$directory:$PATH
                fi
            fi
    esac
    # make sure PATH values are in any case unique
    PATH=$(echo -n $PATH | awk -v RS=: '!($0 in a) {a[$0]; printf("%s%s", length(a) > 1 ? ":" : "", $0)}')
    # remove any leading / trailing :
    PATH=${PATH#:}; PATH=${PATH%:}
}

# ------------------------------------------------------------------------------
# Function...: load_config
# Purpose....: Load package specific configuration files
# ------------------------------------------------------------------------------
function load_config() {
    echo_debug "DEBUG: Start to source configuration files"
    for config in $(get_list_of_config); do
        if [[ "$SB_CONFIG_FILES" == *"${config}"* ]]; then
            echo_debug "DEBUG: configuration file ${config} already loaded"
        else
            if [ -f "${config}" ]; then
                echo_debug "DEBUG: source configuration file ${config}"
                . ${config}
                export SB_CONFIG_FILES="$SB_CONFIG_FILES,${config}"
            else
                echo_debug "DEBUG: skip configuration file ${config} as it does not exists"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# Function...: dump_runtime_config
# Purpose....: Dump / display runtime configuration and variables
# ------------------------------------------------------------------------------
function dump_runtime_config() {
    echo_debug "DEBUG: Dump current ${SB_BASE_NAME} specific environment variables"
    echo_debug "DEBUG: ---------------------------------------------------------------------------------"
    if [ "${SB_DEBUG^^}" == "TRUE" ]; then
        for i in $(env|grep -i "${SB_BASE_SHORT_NAME}_"|sort); do
        variable=$(echo "$i"|cut -d= -f1)
        value=$(echo "$i"|cut -d= -f2-)
        value=${value:-"undef"}
        echo_debug "$(printf '%s%s %s\n' "DEBUG: ${variable}" "${padding:${#variable}}: " "${value}")" 1>&2
        done
    fi
    echo_debug "DEBUG: ---------------------------------------------------------------------------------"   
}

function gen_password {
# ---------------------------------------------------------------------------
# Function...: gen_password
# Purpose....: generate a password string
# -----------------------------------------------------------------------
    Length=${1:-12}

    # make sure, that the password length is not shorter than 4 characters
    if [ ${Length} -lt 4 ]; then
        Length=4
    fi

    # generate password
    if [ $(command -v pwgen) ]; then 
        pwgen -s -1 ${Length}
    else 
        while true; do
            # use urandom to generate a random string
            s=$(cat /dev/urandom | tr -dc "A-Za-z0-9" | fold -w ${Length} | head -n 1)
            # check if the password meet the requirements
            if [[ ${#s} -ge ${Length} && "$s" == *[A-Z]* && "$s" == *[a-z]* && "$s" == *[0-9]*  ]]; then
                echo "$s"
                break
            fi
        done
    fi
}

# ------------------------------------------------------------------------------
# Function...: rotate_logfiles
# Purpose....: Rotate and purge log files
# ------------------------------------------------------------------------------
function rotate_logfiles() {
    SB_KEEP_LOG_DAYS=${1:-$SB_KEEP_LOG_DAYS}
    echo_debug "DEBUG: purge files older for ${SB_SCRIPT_NAME} than $SB_KEEP_LOG_DAYS"
    find $LOG_BASE -name "$(basename ${SB_SCRIPT_NAME} .sh)*.log" \
        -mtime +${SB_KEEP_LOG_DAYS} -exec rm {} \; 
}

# ------------------------------------------------------------------------------
# Function...: create_awr_snapshot
# Purpose....: Display Usage and exit script
# ------------------------------------------------------------------------------
function create_awr_snapshot() {
    pdb=${1:-$SB_SEED_DB}
    if ! dryrun_enabled; then
        ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
            WHENEVER OSERROR EXIT 9;
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            CONNECT / AS SYSDBA
            ALTER SESSION SET CONTAINER=$pdb;
            SELECT to_char(sysdate, 'YYYY-MM-DD HH24:MI') AS tstamp,
                dbms_workload_repository.create_snapshot() AS snap_id FROM dual;
EOFSQL
        if [ $? != 0 ]; then clean_quit 33 "sqlplus AWR snapshot"; fi 
    else
        echo "INFO : Dry run enabled, skip create AWR snapshot for PDB $pdb"
    fi
}

# ------------------------------------------------------------------------------
# Function...: create_awr_report
# Purpose....: create AWR report for the last two snapshots in SecBench PDB
# ------------------------------------------------------------------------------
function create_awr_report() {
    pdb=${1:-$SB_SECBENCH_DB}
    if ! dryrun_enabled; then
        ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
            WHENEVER OSERROR EXIT 9;
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            CONNECT / AS SYSDBA
EOFSQL
        if [ $? != 0 ]; then clean_quit 33 "sqlplus AWR report "; fi 
    else
        echo "INFO : Dry run enabled, skip create AWR report for PDB $pdb"
    fi
}

# ------------------------------------------------------------------------------
# Function...: drop_pdb
# Purpose....: drop SecBench PDB
# ------------------------------------------------------------------------------
function drop_pdb() {
    SB_SECBENCH_DB=${SB_SECBENCH_DB:-$SB_SEED_DB}
    target=${1:-$SB_SECBENCH_DB}
    if ! dryrun_enabled; then
        ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
            WHENEVER OSERROR EXIT 9;
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            CONNECT / AS SYSDBA
            SPOOL $SB_LOG_DIR/sb_drop_${target}_$(date "+%Y.%m.%d_%H%M%S").log
            @$SB_SQL_DIR/sb_secbench_drop_pdb.sql $target
EOFSQL
        if [ $? != 0 ]; then clean_quit 33 "sqlplus clone $source to $target "; fi 
    else
        echo "INFO : Dry run enabled, skip drop of PDB $target"
    fi
}

# ------------------------------------------------------------------------------
# Function...: pdb_exists
# Purpose....: check if a PDB does exists
# ------------------------------------------------------------------------------
function pdb_exists() {
    SB_SECBENCH_DB=${SB_SECBENCH_DB:-$SB_SEED_DB}
    target=${1:-$SB_SECBENCH_DB}
    target=${target^^}
    pdb=$(${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
        WHENEVER OSERROR EXIT 9;
        WHENEVER SQLERROR EXIT SQL.SQLCODE;
        CONNECT / AS SYSDBA
        SET HEADING OFF
        select count(*) from v\$pdbs where upper(name)='$target'; 
EOFSQL
)
    if [ $pdb -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

# ------------------------------------------------------------------------------
# Function...: create_pdb
# Purpose....: create SecBench PDB
# ------------------------------------------------------------------------------
function create_pdb() {
    source=${1:-$SB_SEED_DB}
    target=${2:-$SB_SECBENCH_DB}
    if ! dryrun_enabled; then
        ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
            WHENEVER OSERROR EXIT 9;
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            CONNECT / AS SYSDBA
            SPOOL $SB_LOG_DIR/sb_secbench_create_pdb_$(date "+%Y.%m.%d_%H%M%S").log
            @$SB_SQL_DIR/sb_secbench_create_pdb.sql $source $target 
EOFSQL
        if [ $? != 0 ]; then clean_quit 33 "sqlplus clone $source to $target "; fi
    else
        echo "INFO : Dry run enabled, skip create PDB $target"
    fi
}

# ------------------------------------------------------------------------------
# Function...: run_charbench
# Purpose....: run charbench in SecBench PDB
# ------------------------------------------------------------------------------
function run_charbench() {
    benchmark=${1:-"regular"}
    users=${2:-10}
    DBHOST=$(lsnrctl status|grep -iv xdb|grep -i host |sed 's/.*(HOST=\(.*\))(.*/\1/')
    DBPORT=$(lsnrctl status|grep -iv xdb|grep -i host |sed 's/.*(PORT=\([0-9]*\).*/\1/')
    DBSERVICE=$(lsnrctl status|grep -iv xdb|grep -i $SB_SECBENCH_DB|sed 's/.*"\(.*\)".*/\1/')
    # -dbap <password>  the password of admin user (used for collecting DB Stats)
    # -dbau <username>  the username of admin user (used for collecting DB stats)
    # -com <comment>    specify comment for this benchmark run (in double quotes)
    if ! dryrun_enabled; then
        charbench -cs //$DBHOST:$DBPORT/$DBSERVICE -u $SB_USER -p $SB_PASSWORD \
            -rt $SB_RUNTIME -min $SB_MIN -max $SB_MAX -uc ${users} \
            -cpuloc $HOSTNAME -cpuuser $SB_OS_USER -cpupass $SB_OS_PWD \
            -v $SB_OPTIONS -c $SB_SWINGBENCH_CONF \
            -r $SB_OUTPUT_DIR/soe-${benchmark}-${users}.xml > $SB_OUTPUT_DIR/soe-${benchmark}-${users}.log
            
        if [ $? != 0 ]; then clean_quit 33 "charbench"; fi
    else
        echo "INFO : Dry run enabled, skip to run charbench PDB $pdb"
    fi
}
# - EOF Functions --------------------------------------------------------------

# - Initialization -------------------------------------------------------------

# - EOF Initialization ---------------------------------------------------------
 
# - Main -----------------------------------------------------------------------
# check if script is sourced and return/exit
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    echo_debug "DEBUG: Script ${BASH_SOURCE[0]} is sourced from ${0}"
else
    echo "INFO : Script ${BASH_SOURCE[0]} is executed directly. No action is performed."
    clean_quit
fi
# --- EOF ----------------------------------------------------------------------