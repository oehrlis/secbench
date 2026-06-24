#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: sb_seed_setup.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
# Editor.....: Stefan Oehrli
# Date.......: 2023.05.19
# Revision...: 
# Purpose....: Script to setup a seed database for OraDBA SecBench
# Notes......: --
# Reference..: https://github.com/oehrlis/secbench
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
DEFAULT_SEED_DB="sbpdb_seed"            # default name for the SecBench seed database
DEFAULT_SB_SCALE="0.5"              # default value for the Swingbench scale
DEFAULT_SB_TBS_NAME="SOE_DATA"      # default value for the tablespace used to install SEO
DEFAULT_SB_TBS_SIZE="2048M"         # default value for the tablespace used to install SEO
DEFAULT_SB_PASSWORD=""              # default value for the default password
DEFAULT_SB_DBA_PASSWORD=""          # default value for the default password
DEFAULT_SB_DBA_USER="pdbadmin"      # default value for the default password
DEFAULT_SB_USER="soe"               # default value for the default password

# - End of Customization -------------------------------------------------------

# - Default Values -------------------------------------------------------------
# source generic environment variables and functions
export SB_SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
export SB_BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SB_LOG_DIR="$(dirname "${SB_BIN_DIR}")/log"
export SB_ETC_DIR="$(dirname "${SB_BIN_DIR}")/etc"

# define logfile and logging
export LOG_BASE=${LOG_BASE:-"${SB_LOG_DIR}"}  # Use script directory as default log base
# Define Logfile but first reset LOG_BASE if directory does not exist
if [[ ! -d "${LOG_BASE}" ]] || [[ ! -w "${LOG_BASE}" ]] ; then
    log_message "INFO" "set LOG_BASE to /tmp"
    export LOG_BASE="/tmp"
fi
TIMESTAMP=$(date "+%Y.%m.%d_%H%M%S")
readonly LOGFILE="${LOG_BASE}/$(basename "${SB_SCRIPT_NAME}" .sh)_${TIMESTAMP}.log"
# - EOF Default Values ---------------------------------------------------------

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

  Usage: ${SB_SCRIPT_NAME} [options] [setup options] [seed pdb]

  where:
    seed pdb	        Name of the seed PDB. This PDB will be create

  Common Options:
    -h                  Usage this message
    -v                  Enable verbose mode (default \$SB_VERBOSE=${SB_VERBOSE})
    -d                  Enable debug mode (default \$SB_DEBUG=${SB_DEBUG})
 
  Setup options:
    -S <SEED PDB>       Name of the seed PDB (mandatory)
    -s <SCALE>          Swingbench scale / mulitiplier for default config
                        (default \$SB_SCALE=${SB_SCALE})
    -T <TABLESPACE>     Name of the tablespace for swingbench schema.
                        (default \$DEFAULT_SB_TBS_NAME=${DEFAULT_SB_TBS_NAME}).
    -t <TBS SIZE>       Size of the tablespace for swingbench schema.
                        (default \$DEFAULT_SB_TBS_SIZE=${DEFAULT_SB_TBS_SIZE}).
    -W                  prompt for bind password. Can be specified by setting
                        TVDLDAP_BINDDN_PWDASK.
    -y <PASSWORD FILE>  Read password from file. Can be specified by setting
                        TVDLDAP_BINDDN_PWDFILE.
    -F                  Force mode to delete the seed PDB if it allready exists

  Configuration file:
    The script does load configuration files to define default values as an
    alternative for command line parameter. e.g. to set charbench configuration
    etc. The configuration files are loaded in the following order:

$((get_list_of_config && echo "Command line parameter")|cat -b)

  Logfile : ${LOGFILE}

EOI
    dump_runtime_config     # dump current tool specific environment in debug mode
    exit_with_status ${error} ${error_value}  
}
# - EOF Functions --------------------------------------------------------------

# - Initialization -------------------------------------------------------------
set -o nounset      # stop script if variables and parameters are unset
set -o errexit      # Exit immediately if a command returns a non-zero status
set -o pipefail     # The return value of a pipeline is the status of the last command to exit with a non-zero status

# initialize logfile
touch "${LOGFILE}" 2>/dev/null
exec &> >(tee -a "${LOGFILE}")                # Open standard out at `$LOGFILE` for write.  
exec 2>&1  

echo "INFO : Start ${SB_SCRIPT_NAME} on host $(hostname) at $(date)"

# source common variables and functions from sb_functions.sh
if [[ -f "${SB_BIN_DIR}/sb_functions.sh" ]]; then
    . "${SB_BIN_DIR}/sb_functions.sh"
else
    echo "ERROR: Cannot find common functions ${SB_BIN_DIR}/sb_functions.sh"
    exit 5
fi

# update PATH variable with swingbench if it is available in the secbench folder
if [ -d "$SB_BASE/swingbench" ]; then
    log_message INFO "INFO : Add local swingbench/bin folder to PATH"
    update_path $SB_BASE/swingbench/bin
else
    log_message WARN "WARN : can not find local swingbench folder below $SB_BASE"
    log_message WARN "WARN : make sure you swingbench is accessible via PATH"
    log_message WARN "WARN : other wise use sb_get_swingbench.sh to download a local swingbench copy"
fi

trap on_term TERM SEGV      # handle TERM SEGV using function on_term
trap on_int INT             # handle INT using function on_int
load_config                 # load configur26ation files. File list in SB_CONFIG_FILES

check_tools                 # check if we do have the required tools available
dump_runtime_config         # dump current tool specific environment in debug mode

# get options
while getopts "hvqdf:S:s:T:t:E:" CurOpt; do
    case "${CurOpt}" in
        h) Usage 0;;
        v) VERBOSE=1;;
        d) DEBUG=1 && VERBOSE=1;;
        q) QUIET=1 && VERBOSE='' && DEBUG='' ;;
        F) SB_FORCE="TRUE";; 
        n) SB_DRYRUN="TRUE";; 
        S) SB_SEED_DB="${OPTARG}";;
        s) SB_SCALE="${OPTARG}";;
        T) SB_TBS_NAME="${OPTARG}";;
        t) SB_TBS_SIZE="${OPTARG}";;
        E) exit_with_status "${OPTARG}";;
        *) Usage 2 "$*";;
    esac
done

# display usage and exit if no parameters are given
if [[ $# -eq 0 ]]; then
   Usage 1
fi

# Set default values
export SB_SEED_DB="${SB_SEED_DB:-""}"
export SB_TBS_NAME="${SB_TBS_NAME:-"${DEFAULT_SB_TBS_NAME}"}"
export SB_TBS_SIZE="${SB_TBS_SIZE:-"${DEFAULT_SB_TBS_SIZE}"}"
export SB_PASSWORD="${SB_PASSWORD:-"${DEFAULT_SB_PASSWORD}"}"
export SB_DBA_PASSWORD="${SB_DBA_PASSWORD:-"${DEFAULT_SB_DBA_PASSWORD}"}"
export SB_DBA_USER="${SB_DBA_USER:-"${DEFAULT_SB_DBA_USER}"}"
export SB_USER="${SB_USER:-"${DEFAULT_SB_USER}"}"
export SB_SCALE="${SB_SCALE:-"${DEFAULT_SB_SCALE}"}"

# Check for Service and Arguments
if [[ -z "${SB_SEED_DB}" ]] && [[ $# -ne 0 ]]; then
    if [[ "$1" == -* ]]; then
        SB_SEED_DB="${DEFAULT_SEED_DB:-""}"  # Set default service to ORACLE_SID if argument starts with a dash
    else
        SB_SEED_DB="$1"  # Use argument as service if not starting with a dash
    fi
fi

# Check for mandatory parameters
if [[ -z "${SB_SEED_DB}" ]]; then 
    exit_with_status 3 "-S"
fi

# Check for mandatory parameters
if [[ -z "${SB_SEED_DB}" ]]; then 
    exit_with_status 3 "-S"
fi

# generate a default swingbench schema password
if [[ -n "${SB_PASSWORD}" ]]; then
    log_message "DEBUG" "Use password from config file as default password..."
    echo "${SB_PASSWORD}" > "${SB_ETC_DIR}/.${SB_BASE_NAME}_password.txt"
else
    if [[ -f "${SB_ETC_DIR}/.${SB_BASE_NAME}_password.txt" ]]; then
        log_message "INFO" "Found password file ${SB_ETC_DIR}/.${SB_BASE_NAME}_password.txt"
        SB_PASSWORD=$(cat "${SB_ETC_DIR}/.${SB_BASE_NAME}_password.txt")
    else
        log_message "INFO" "Generate random password using gen_password"
        SB_PASSWORD=$(gen_password)
        echo "${SB_PASSWORD}" > "${SB_ETC_DIR}/.${SB_BASE_NAME}_password.txt"
    fi
fi

# generate a default swingbench schema password
if [[ -n "${SB_DBA_PASSWORD}" ]]; then
    log_message "DEBUG" "Use password from config file as default DBA password..."
    echo "${SB_DBA_PASSWORD}" > "${SB_ETC_DIR}/.${SB_BASE_NAME}_dba_password.txt"
else
    if [[ -f "${SB_ETC_DIR}/.${SB_BASE_NAME}_dba_password.txt" ]]; then
        log_message "INFO" "Found DBA password file ${SB_ETC_DIR}/.${SB_BASE_NAME}_dba_password.txt"
        SB_DBA_PASSWORD=$(cat "${SB_ETC_DIR}/.${SB_BASE_NAME}_dba_password.txt")
    else
        log_message "INFO" "Generate random DBA password using gen_password"
        SB_DBA_PASSWORD=$(gen_password)
        echo "${SB_DBA_PASSWORD}" > "${SB_ETC_DIR}/.${SB_BASE_NAME}_dba_password.txt"
    fi
fi

# List of required SQL files
required_files=(
    "sb_sbseed_create.sql"
    "sb_audit_init.sql"
    "sb_audit_cleanup_policies.sql"
)

# Loop through each required file and check for its existence
for file in "${required_files[@]}"; do
    if [[ ! -f "${SB_SQL_DIR}/${file}" ]]; then
        exit_with_status 22 "${SB_SQL_DIR}/${file}"
    fi
done
# - EOF Initialization ---------------------------------------------------------

# - Main -----------------------------------------------------------------------
set +o errexit                              # temporary disable errexit
# check if we already have a seed PDB
if pdb_exists; then
    if force_enabled; then
        log_message WARN "WARN : PDB $SB_SEED_DB does exists will drop it as force mode is set"
        if ! dryrun_enabled; then
            drop_pdb $SB_SEED_DB
        else
            log_message INFO "INFO : Dry run enabled, skip drop of PDB $SB_SEED_DB"
        fi
    else
        exit_with_status 40 $SB_SEED_DB
    fi 
fi

log_message INFO "INFO : Create PDB $SB_SEED_DB as clone from PDB\$SEED in current Oracle environment $ORACLE_SID"
log_message INFO "INFO : Whereby the PDB is created using the script $SB_SQL_DIR/sb_sbseed_create.sql"
log_message INFO "INFO : For customization update the script beforehand."
log_message INFO "INFO : Using the following configuration values:"
log_message INFO "INFO : SB_SEED_DB........ : $SB_SEED_DB"
log_message INFO "INFO : SB_TBS_NAME....... : $SB_TBS_NAME"
log_message INFO "INFO : SB_TBS_SIZE....... : $SB_TBS_SIZE"
log_message INFO "INFO : SB_DBA_USER....... : $SB_DBA_USER"
log_message INFO "INFO : SB_DBA_PASSWORD... : $SB_DBA_PASSWORD"
log_message INFO "INFO : SB_USER........... : $SB_USER"
log_message INFO "INFO : SB_PASSWORD....... : $SB_PASSWORD"
log_message INFO "INFO : SB_SCALE.......... : $SB_SCALE"

# create the SB Seed database
if ! dryrun_enabled; then
    ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
        WHENEVER OSERROR EXIT 9;
        WHENEVER SQLERROR EXIT SQL.SQLCODE;
        CONNECT / AS SYSDBA
        SPOOL "${SB_LOG_DIR}/sb_sbseed_create_${TIMESTAMP}.log"
        @${SB_SQL_DIR}/sb_sbseed_create.sql "${SB_SEED_DB}" "${SB_TBS_NAME}" "${SB_TBS_SIZE}" "${SB_DBA_PASSWORD}"
EOFSQL
    exit_status=$?
    if [[ ${exit_status} -ne 0 ]]; then exit_with_status 33 "sqlplus ${SB_SQL_DIR}/sb_sbseed_create.sql"; fi 
else
    log_message "INFO" "Dry run enabled, skip create seed PDB ${SB_SEED_DB}"
fi

# config the SB Seed database
if ! dryrun_enabled; then
    log_message INFO "INFO : Initialize Audit infrastructure in $SB_SEED_DB"
    ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
        WHENEVER OSERROR EXIT 9;
        WHENEVER SQLERROR EXIT SQL.SQLCODE;
        CONNECT / AS SYSDBA
        ALTER SESSION SET CONTAINER=$SB_SEED_DB;
        SPOOL $SB_LOG_DIR/sb_audit_init_$TIMESTAMP.log
        @$SB_SQL_DIR/sb_audit_init.sql
        SPOOL $SB_LOG_DIR/sb_audit_cleanup_policies_$TIMESTAMP.log
        @$SB_SQL_DIR/sb_audit_cleanup_policies.sql
        SPOOL OFF
EOFSQL
    exit_status=$?
    if [[ ${exit_status} -ne 0 ]]; then exit_with_status 33 "sqlplus audit initialisation"; fi 
else
    log_message INFO "INFO : Dry run enabled, skip audit initialisation in PDB $SB_SEED_DB"
fi

if ! dryrun_enabled; then
    log_message INFO "INFO : Install swingbench schema in $SB_SEED_DB using oewizard with scale $SB_SCALE"
    # Construct the command with required parameters
    command="oewizard -cs //$(get_db_host):$(get_db_port)/$(get_db_service "$SB_SEED_DB") -create -allindexes -nopart -cl"

    # Append optional parameters if they are defined
    command+=" $(get_param "scale" "$SB_SCALE")"
    command+=" $(get_param "ts" "$SB_TBS_NAME")"
    command+=" $(get_param "u" "$SB_USER")"
    command+=" $(get_param "p" "$SB_PASSWORD")"
    command+=" $(get_param "dba" "$SB_DBA_USER")"
    command+=" $(get_param "dbap" "$SB_DBA_PASSWORD")"
    
    # Log the command to be executed
    log_message DEBUG "DEBUG: Executing command: $command"

    # Execute the command
    eval "$command"
    exit_status=$?
    if [[ ${exit_status} -ne 0 ]]; then exit_with_status 33 "oewizard"; fi 
else
    log_message INFO "INFO : Dry run enabled, skip swingbench schema deployment in PDB $SB_SEED_DB"
fi

exit_with_status 0                                # we are done, successfully quit
# --- EOF ----------------------------------------------------------------------
