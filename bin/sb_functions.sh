#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: sb_functions.sh
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
VERBOSE=''                  # enable verbose mode
QUIET=''                    # enable quiet mode
DEBUG=''                    # enable debug mode
KEEP=''                     # Flag to keep temporary files

# default values also read from environment
SB_VERBOSE=${SB_VERBOSE:-"FALSE"}       # Set verbose mode based on environment or default value
SB_DEBUG=${SB_DEBUG:-"FALSE"}           # Set debug mode based on environment or default value
SB_QUIET=${SB_QUIET:-"FALSE"}           # Set quiet mode based on environment or default value
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

# Define color codes for various log levels
SB_ANSI_SUCCESS='\033[0;32m'    # Green for success messages
SB_ANSI_WARNING='\033[0;33m'    # Yellow for warning messages
SB_ANSI_ERROR='\033[0;31m'      # Red for error messages
SB_ANSI_INFO='\033[0;30m'       # Black for info messages
SB_ANSI_DEBUG='\033[0;34m'      # Blue for debug messages
NC='\033[0m'                    # No color/reset

# initialize common variables
HOME=${HOME:-~}
SB_DRYRUN=${SB_DRYRUN:-"FALSE"}
SB_FORCE=${SB_FORCE:-"FALSE"}
SB_PREPARED=${SB_PREPARED:-"FALSE"}
SB_WORK_DIR=${SB_WORK_DIR:-""}
SB_DBA_USER=""
SB_DBA_PASSWORD=""
SB_DBA_COMMENT=""
SB_STATS="full"

# set the default value for the internal VERBOSE, DEBUG and QUIET variables
[[ "${SB_VERBOSE^^}" == "TRUE" ]]  && VERBOSE=1
[[ "${SB_DEBUG^^}" == "TRUE" ]]    && DEBUG=1  && VERBOSE=1
[[ "${SB_QUIET^^}" == "TRUE" ]]    && QUIET=1  && VERBOSE=''
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
# Function...: prepared_enabled
# Purpose....: Check if PREPARED mode is enabled
# ------------------------------------------------------------------------------
function prepared_enabled () {
    if [ "${SB_PREPARED^^}" == "TRUE" ]; then
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
    log_message DEBUG "DEBUG: List of tools to check: ${TOOLS}"
    for i in ${TOOLS}; do
        if ! command_exists ${i}; then
            exit_with_status 10 ${i} 
            exit 1
        fi
    done
}

# ------------------------------------------------------------------------------
# Function...: get_param
# Purpose....: Function to get a parameter only if its value is defined
# ------------------------------------------------------------------------------
get_param() {
    local param_name="$1"
    local param_value="$2"

    if [ -n "$param_value" ]; then
        echo "-$param_name $param_value"
    fi
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
# Function:     log_message
# Purpose:      Log messages with optional levels and newline control.
# Usage:        log_message [-n] [LOG_LEVEL] "message"
# Options:
#   -n          Omit newline at message end.
# Arguments:
#   LOG_LEVEL   One of INFO, WARN, ERROR, SUCCESS, DEBUG (default: INFO).
# Environment:
#   LOGFILE     Required. File for logging messages.
#   VERBOSE     If set, echoes to both stdout and log file.
#   QUIET       If set, echoes only to log file.
#   DEBUG       If set, logs DEBUG messages to stdout and file.
# Examples:
#   log_message -n INFO "Process started"
#   log_message ERROR "Error occurred"
#   log_message DEBUG "Debug info"
# Notes:
#   LOGFILE must be set. LOG_LEVEL is case-insensitive.
# Returns:      0 on success, non-zero on error.
# ------------------------------------------------------------------------------
function log_message() {
    local newline=true      # Local variable for newline flag
    local message           # Local variable for message
    local level="INFO"      # Local variable for log level
    local color             # Local variable for color
    local OPTIND flag       # Local variable for options parsed by getopts

    # Parse options: if the first argument is '-n', do not append newline.
    while getopts ":n" flag; do
        case "$flag" in
            n) newline=false ;;
            *) ;;
        esac
    done
    shift $((OPTIND-1))

    # Check if the next argument is a log level
    if [[ "$1" =~ ^(INFO|WARN|ERROR|SUCCESS|DEBUG)$ ]]; then
        level=$1
        shift
    fi

    # Remaining arguments are the message
    message="$*"

    # Assign the color code based on the level
    case "${level^^}" in
        INFO)       color=${SB_ANSI_INFO:-'\033[0;30m'} ;;      # Black for info messages
        WARN)       color=${SB_ANSI_WARNING:-'\033[0;33m'} ;;      # Yellow for warning messages
        ERROR)      color=${SB_ANSI_ERROR:-'\033[0;31m'} ;;     # Red for error messages
        SUCCESS)    color=${SB_ANSI_SUCCESS:-'\033[0;32m'} ;;   # Green for info messages
        DEBUG)      color=${SB_ANSI_DEBUG:-'\033[0;36m'} ;;     # Blue for debug messages
        *)          color=${NC:-'\033[0m'} ;;                  # No color/reset
    esac

    # Function to handle appending message with or without a newline
    append_log() {
        if [ "$newline" = true ]; then
            echo -e "$color$1$NC"
        else
            echo -n -e "$color$1$NC"
        fi
    }

    # Check if LOGFILE variable is set or not empty
    if [ -z "${LOGFILE}" ]; then
        echo "Error: LOGFILE is not set." >&2
        return 1
    fi

    # If neither VERBOSE nor QUIET is set, send ERROR to stderr and logfile
    if [[ "${level^^}" == "ERROR" ]]; then
        append_log "$message" >&2 | tee -a "${LOGFILE}"
    elif [[ "${level^^}" == "WARN" && ! -n "${QUIET}" ]]; then
        append_log "$message" >&2 | tee -a "${LOGFILE}"
    # Handle DEBUG level when DEBUG variable is set
    elif [[ "${level^^}" == "DEBUG" && -n "${DEBUG}" ]]; then
        append_log "$message" | tee -a "${LOGFILE}"
    # If VERBOSE is set, echo to both stdout and logfile DEBUG message will be skipped
    elif  [[ "${level^^}" != "DEBUG" && -n "${VERBOSE}" ]]; then
        append_log "$message" | tee -a "${LOGFILE}"
    # If QUIET is set, echo only to logfile. DEBUG message will be skipped
    elif [[ "${level^^}" != "DEBUG" && -n "${QUIET}" ]]; then
        append_log "$message" >> "${LOGFILE}"
    # If neither VERBOSE nor QUIET is set, default to only logfile. DEBUG message will be skipped
    elif [[ "${level^^}" != "DEBUG" ]]; then
        append_log "$message" >> "${LOGFILE}"
    fi
}

# ------------------------------------------------------------------------------
# Function...: exit_with_status
# Purpose....: Gracefully exits the script with an optional error code and message.
# Usage......: exit_with_status [ERROR_CODE [ERROR_VALUE]]
# Arguments..: ERROR_CODE  Exit status (default 0).
#              ERROR_VALUE Context for the error (e.g., filename or command).
# Env........: SB_SUCCESS, SB_ERROR for message formatting.
#              SCRIPT_NAME for the script's name in messages.
#              TEMPFILE, TNSPING_TEMPFILE for cleanup.
# Notes......: Set message format vars and SCRIPT_NAME. Un/comment cleanup as
#              needed. Exits with ERROR_CODE or 0 by default. Ensure SB_SUCCESS
#              and SB_ERROR are set.
# Examples...: exit_with_status                      # exit cleanly
#              exit_with_status 1                    # exit with generic error
#              exit_with_status 2 "bad input"        # exit with custom message
# ------------------------------------------------------------------------------
function exit_with_status() {
    # define default values for function arguments
    error=${1:-"0"}
    error_value=${2:-""}
    SB_SCRIPT_NAME=${SB_SCRIPT_NAME:-${LOCAL_SCRIPT_NAME}}

    case ${error} in
        0)  log_message SUCCESS "SUCCESS : Successfully finish ${SB_SCRIPT_NAME}" ;;
        1)  log_message ERROR "ERROR: Exit Code ${error}. Wrong amount of arguments. See usage for correct one." >&2;;
        2)  log_message ERROR "ERROR: Exit Code ${error}. Wrong arguments (${error_value}). See usage for correct one." >&2;;
        3)  log_message ERROR "ERROR: Exit Code ${error}. Missing mandatory argument (${error_value}). See usage ..." >&2;;
        5)  log_message ERROR "ERROR: Exit Code ${error}. Variable ${error_value} not defined ..." >&2;;
        6)  log_message ERROR "ERROR: Exit Code ${error}. Exit Code ${error}. Missing common function file (${error_value}) to source." >&2;;
        10) log_message ERROR "ERROR: Exit Code ${error}. Command ${error_value} isn't installed/available on this system..." >&2;;
        20) log_message ERROR "ERROR: Exit Code ${error}. File ${error_value} already exists..." >&2;;
        21) log_message ERROR "ERROR: Exit Code ${error}. Directory ${error_value} is not writeable..." >&2;;
        22) log_message ERROR "ERROR: Exit Code ${error}. Can not read file ${error_value} ..." >&2;;
        23) log_message ERROR "ERROR: Exit Code ${error}. Can not write file ${error_value} ..." >&2;;
        24) log_message ERROR "ERROR: Exit Code ${error}. Can not create files in ${error_value} ..." >&2;;
        25) log_message ERROR "ERROR: Exit Code ${error}. Can not read file password file ${error_value} ..." >&2;;
        26) log_message ERROR "ERROR: Exit Code ${error}. Can not write tempfile file ${error_value} ..." >&2;;
        27) log_message ERROR "ERROR: Exit Code ${error}. Invalid password file ${error_value} ..." >&2;;
        28) log_message ERROR "ERROR: Exit Code ${error}. Missing password for ${error_value:-'n/a'} ..." >&2;;
        33) log_message ERROR "ERROR: Exit Code ${error}. Error running ${error_value} ..." >&2;;
        40) log_message ERROR "ERROR: Exit Code ${error}. PDB ${error_value} does exits ..." >&2;;
        41) log_message ERROR "ERROR: Exit Code ${error}. PDB ${error_value} does not exits ..." >&2;;
        50) log_message ERROR "ERROR: Exit Code ${error}. Missing mandatory values ${error_value} ..." >&2;;
        90) log_message ERROR "ERROR: Exit Code ${error}. Received signal SIGINT / Interrupt / CTRL-C ..." >&2;;
        91) log_message ERROR "ERROR: Exit Code ${error}. Received signal TERM to terminate the script ..." >&2;;
        92) log_message ERROR "ERROR: Exit Code ${error}. Received signal ..." >&2;;
        99) log_message INFO "INFO : Just wanna say hallo." ;;
        ?)  log_message ERROR "ERROR: Exit Code ${1}. Unknown Error.";;
    esac

    cleanup_temp_files  # Call to the cleanup function
    rotate_logfiles     # rotage log files
    exit ${error}
}

# ------------------------------------------------------------------------------
# Function...: cleanup_temp_files
# Purpose....: clean up tempfiles 
# ------------------------------------------------------------------------------
cleanup_temp_files() {
    if [ -z "${KEEP}" ]; then
        if [ -n "$TEMPFILE" ]; then
            log_message DEBUG "DEBUG: Clean up tempfile $TEMPFILE"
            [[ -f "$TEMPFILE" ]] && rm "$TEMPFILE"
        else
            log_message DEBUG "DEBUG: Nothing to clean up"
        fi
    else
        log_message DEBUG "DEBUG: Keep enabled, do not remove any thing"
    fi
}

# ------------------------------------------------------------------------------
# Function...: on_int
# Purpose....: function to handle interupt by CTRL-C
# ------------------------------------------------------------------------------
function on_int() {
  log_message ERROR "     : You hit CTRL-C, are you sure ? (y/n)"
  read answer
  if [[ ${answer} = "y" ]]; then
    log_message ERROR "     : OK, lets quit then"
    exit_with_status 90
  else
    log_message ERROR "     : OK, lets continue then"
  fi
}

# ------------------------------------------------------------------------------
# Function...: on_term
# Purpose....: function to handle TERM signal
# ------------------------------------------------------------------------------
function on_term() {
  log_message ERROR "     : I have recived a terminal signal. Terminating script..."
  exit_with_status 91
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
    echo $(lsnrctl status|grep -iv xdb|grep -i $pdb|sed 's/.*"\(.*\)".*/\1/'|head -1|cut -d' ' -f1)
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
    log_message DEBUG "DEBUG: Start to source configuration files"
    for config in $(get_list_of_config); do
        if [[ "$SB_CONFIG_FILES" == *"${config}"* ]]; then
            log_message DEBUG "DEBUG: configuration file ${config} already loaded"
        else
            if [ -f "${config}" ]; then
                log_message DEBUG "DEBUG: source configuration file ${config}"
                . ${config}
                export SB_CONFIG_FILES="$SB_CONFIG_FILES,${config}"
            else
                log_message DEBUG "DEBUG: skip configuration file ${config} as it does not exists"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# Function...: dump_runtime_config
# Purpose....: Dump / display runtime configuration and variables
# ------------------------------------------------------------------------------
function dump_runtime_config() {
    log_message DEBUG "DEBUG: Dump current ${SB_BASE_NAME} specific environment variables"
    log_message DEBUG "DEBUG: ---------------------------------------------------------------------------------"
    if [ "${SB_DEBUG^^}" == "TRUE" ]; then
        for i in $(env|grep -i "${SB_BASE_SHORT_NAME}_"|sort); do
        variable=$(echo "$i"|cut -d= -f1)
        value=$(echo "$i"|cut -d= -f2-)
        value=${value:-"undef"}
        log_message DEBUG "$(printf '%s%s %s\n' "DEBUG: ${variable}" "${padding:${#variable}}: " "${value}")" 1>&2
        done
    fi
    log_message DEBUG "DEBUG: ---------------------------------------------------------------------------------"   
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
    log_message DEBUG "DEBUG: purge files older for ${SB_SCRIPT_NAME} than $SB_KEEP_LOG_DAYS"
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
            CONNECT / AS SYSDBA
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            ALTER SESSION SET CONTAINER=$pdb;
            SELECT to_char(sysdate, 'YYYY-MM-DD HH24:MI') AS tstamp,
                dbms_workload_repository.create_snapshot() AS snap_id FROM dual;
EOFSQL
        if [ $? != 0 ]; then exit_with_status 33 "sqlplus AWR snapshot"; fi 
    else
        log_message INFO "INFO : Dry run enabled, skip create AWR snapshot for PDB $pdb"
    fi
}

# ------------------------------------------------------------------------------
# Function...: create_awr_report
# Purpose....: create AWR report for the last two snapshots in SecBench PDB
# ------------------------------------------------------------------------------
function create_awr_report() {
    SB_WORK_DIR=${SB_WORK_DIR:-$SB_OUT_DIR}
    pdb=${1:-$SB_SECBENCH_DB}
    benchmark=${2:-$pdb}
    uc=${3:-""}
    if ! dryrun_enabled; then
        ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            CONNECT / AS SYSDBA

            ALTER SESSION SET CONTAINER=$pdb;
            SET FEEDBACK OFF
            SET VERIFY OFF
            DEFINE  num_days     = 3;
            DEFINE  report_type  = 'html';
            DEFINE  awr_location = 'AWR_PDB';

            COLUMN inst_num NEW_VALUE inst_num NOPRINT
            SELECT instance_number inst_num FROM v\$instance;
            COLUMN inst_name NEW_VALUE inst_name NOPRINT
            SELECT upper(instance_name) inst_name FROM v\$instance;

            COLUMN db_name NEW_VALUE db_name NOPRINT
            SELECT upper(name) db_name FROM v\$pdbs;
            COLUMN dbid NEW_VALUE dbid NOPRINT
            SELECT upper(dbid) dbid FROM v\$pdbs;

            COLUMN begin_snap NEW_VALUE begin_snap NOPRINT
            SELECT max(snap_id)-1 begin_snap FROM dba_hist_snapshot WHERE dbid=&dbid;
            COLUMN end_snap NEW_VALUE end_snap NOPRINT
            SELECT max(snap_id) end_snap FROM dba_hist_snapshot WHERE dbid=&dbid;

            DEFINE  report_name  = $SB_OUTPUT_DIR/soe-${benchmark}-${uc}-awrrpt.html
            @@?/rdbms/admin/awrrpti
EOFSQL
        if [ $? != 0 ]; then exit_with_status 33 "sqlplus AWR report "; fi 
    else
        log_message INFO "INFO : Dry run enabled, skip create AWR report for PDB $pdb"
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
            CONNECT / AS SYSDBA
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            SPOOL $SB_LOG_DIR/sb_drop_${target}_$(date "+%Y.%m.%d_%H%M%S").log
            @$SB_SQL_DIR/sb_secbench_drop_pdb.sql $target
EOFSQL
        if [ $? != 0 ]; then exit_with_status 33 "sqlplus clone $source to $target "; fi 
    else
        log_message INFO "INFO : Dry run enabled, skip drop of PDB $target"
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
        CONNECT / AS SYSDBA
        WHENEVER SQLERROR EXIT SQL.SQLCODE;

        SET HEADING OFF
        SELECT count(*) FROM v\$pdbs WHERE upper(name)='$target'; 
EOFSQL
)
    if [ $pdb -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

# ------------------------------------------------------------------------------
# Function...: component_exists
# Purpose....: check if a db component is installed
# ------------------------------------------------------------------------------
function component_exists() {
    component=${1:-""}
    target=${2:-"CDB\$ROOT"}
    target=${target^^}
    comp=$(${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
        CONNECT / AS SYSDBA
        WHENEVER SQLERROR EXIT SQL.SQLCODE;
        SET HEADING OFF
        SET FEEDBACK OFF
        ALTER SESSION SET CONTAINER=$target;
        SELECT count(*) FROM dba_registry WHERE comp_name='$component'; 
EOFSQL
)
    if [ $comp -eq 0 ]; then
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
            CONNECT / AS SYSDBA
            WHENEVER SQLERROR EXIT SQL.SQLCODE;
            SPOOL $SB_LOG_DIR/sb_secbench_create_pdb_$(date "+%Y.%m.%d_%H%M%S").log
            @$SB_SQL_DIR/sb_secbench_create_pdb.sql $source $target 
EOFSQL
        if [ $? != 0 ]; then exit_with_status 33 "sqlplus clone $source to $target "; fi
    else
        log_message INFO "INFO : Dry run enabled, skip create PDB $target"
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

    # Construct the command with required parameters
    command="charbench -cs //$DBHOST:$DBPORT/$DBSERVICE"

    # Append optional parameters if they are defined
    command+=" $(get_param "rt" "$SB_RUNTIME")"
    command+=" $(get_param "min" "$SB_MIN")"
    command+=" $(get_param "max" "$SB_MAX")"
    command+=" $(get_param "u" "$SB_USER")"
    command+=" $(get_param "p" "$SB_PASSWORD")"
    command+=" $(get_param "dbau" "$SB_DBA_USER")"
    command+=" $(get_param "dbap" "$SB_DBA_PASSWORD")"
    command+=" $(get_param "com" "$SB_DBA_COMMENT")"
    command+=" $(get_param "uc" "${users}")"
    command+=" $(get_param "c" "$SB_SWINGBENCH_CONF")"
    command+=" $(get_param "v" "$SB_OPTIONS")"
    command+=" $(get_param "cpupass" "$SB_OS_PWD")"
    command+=" $(get_param "cpuuser" "$SB_OS_USER")"
    command+=" $(get_param "stats" "$SB_STATS")"
    command+=" $(get_param "cpuloc" "$HOSTNAME")"
    command+=" $(get_param "r" "$SB_OUTPUT_DIR/soe-${benchmark}-${users}.xml")"
    command+=" > $SB_OUTPUT_DIR/soe-${benchmark}-${users}.log"

    # Log the command to be executed
    log_message DEBUG "DEBUG: Executing command: $command"

    if ! dryrun_enabled; then
        # Execute the command
        eval "$command"
        exit_status=$?
        if [[ ${exit_status} -ne 0 ]]; then exit_with_status 33 "oewizard"; fi 
    else
        log_message INFO "INFO : Dry run enabled, skip to run charbench PDB $pdb"
    fi
}
# - EOF Functions --------------------------------------------------------------

# - Initialization -------------------------------------------------------------

# - EOF Initialization ---------------------------------------------------------
 
# - Main -----------------------------------------------------------------------
# check if script is sourced and return/exit
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    log_message DEBUG "DEBUG: Script ${BASH_SOURCE[0]} is sourced from ${0}"
else
    log_message INFO "INFO : Script ${BASH_SOURCE[0]} is executed directly. No action is performed."
    exit_with_status
fi
# --- EOF ----------------------------------------------------------------------