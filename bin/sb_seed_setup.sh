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
# source genric environment variables and functions
export SB_SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
export SB_BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SB_LOG_DIR="$(dirname ${SB_BIN_DIR})/log"
export SB_ETC_DIR="$(dirname ${SB_BIN_DIR})/etc"

# define logfile and logging
export LOG_BASE=${LOG_BASE:-"$SB_LOG_DIR"}  # Use script directory as default logbase
# Define Logfile but first reset LOG_BASE if directory does not exists
if [ ! -d ${LOG_BASE} ] || [ ! -w ${LOG_BASE} ] ; then
    echo "INFO : set LOG_BASE to /tmp"
    export LOG_BASE="/tmp"
fi
TIMESTAMP=$(date "+%Y.%m.%d_%H%M%S")
readonly LOGFILE="$LOG_BASE/$(basename $SB_SCRIPT_NAME .sh)_$TIMESTAMP.log"
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

# update PATH variable with swingbench if it is available in the secbench folder
if [ -d "$SB_BASE/swingbench" ]; then
    echo "INFO : Add local swingbench/bin folder to PATH"
    update_path $SB_BASE/swingbench/bin
else
    echo_warn "WARN : can not find local swingbench folder below $SB_BASE"
    echo_warn "WARN : make sure you swingbench is accessible via PATH"
    echo_warn "WARN : other wise use sb_get_swingbench.sh to download a local swingbench copy"
fi

trap on_term TERM SEGV      # handle TERM SEGV using function on_term
trap on_int INT             # handle INT using function on_int
load_config                 # load configur26ation files. File list in SB_CONFIG_FILES

check_tools             # check if we do have the required tools available
dump_runtime_config     # dump current tool specific environment in debug mode

# get options
while getopts hvdFns:S:T:t:E: CurOpt; do
    case ${CurOpt} in
        h) Usage 0;;
        v) TVDLDAP_VERBOSE="TRUE" ;;
        d) TVDLDAP_DEBUG="TRUE" ;;
        F) SB_FORCE="TRUE";; 
        n) SB_DRYRUN="TRUE";; 
        S) SB_SEED_DB="${OPTARG}";;
        s) SB_SCALE="${OPTARG}";;
        T) SB_TBS_NAME="${OPTARG}";;
        t) SB_TBS_SIZE="${OPTARG}";;
        E) clean_quit "${OPTARG}";;
        *) Usage 2 $*;;
    esac
done

# display usage and exit if parameter is null
if [ $# -eq 0 ]; then
   Usage 1
fi

# Default values
export SB_SEED_DB=${SB_SEED_DB:-""}
export SB_TBS_NAME=${SB_TBS_NAME:-$DEFAULT_SB_TBS_NAME}
export SB_TBS_SIZE=${SB_TBS_SIZE:-$DEFAULT_SB_TBS_SIZE}
export SB_PASSWORD=${SB_PASSWORD:-$DEFAULT_SB_PASSWORD}
export SB_DBA_PASSWORD=${SB_DBA_PASSWORD:-$DEFAULT_SB_DBA_PASSWORD}
export SB_DBA_USER=${SB_DBA_USER:-$DEFAULT_SB_DBA_USER}
export SB_USER=${SB_USER:-$DEFAULT_SB_USER}
export SB_SCALE=${SB_SCALE:-$DEFAULT_SB_SCALE}

# check for Service and Arguments
if [ -z "$SB_SEED_DB" ] && [ $# -ne 0 ]; then
    echo "parameter $i"
    if [[ "$1" = \-*  ]]; then
        echo "set default"
        SB_SEED_DB=${DEFAULT_SEED_DB:-""}  # default service to ORACLE_SID if Argument starting with dash 
    else
        echo "use üaram"
        SB_SEED_DB=$1           # default service to Argument if not starting with dash
    fi

fi

# check for mandatory parameters
if [ -z "${SB_SEED_DB}" ]; then clean_quit 3 "-S"; fi

# generate a default swingbench schema password
if [ -n "$SB_PASSWORD" ]; then
    echo_debug "DEBUG: use password from config file as default password..."
    echo $SB_PASSWORD > "$SB_ETC_DIR/.${SB_BASE_NAME}_password.txt"
else
    if [ -f "$SB_ETC_DIR/.${SB_BASE_NAME}_password.txt" ]; then
        echo "INFO : found pwd file $SB_ETC_DIR/.${SB_BASE_NAME}_password.txt"
        SB_PASSWORD=$(cat $SB_ETC_DIR/.${SB_BASE_NAME}_password.txt)
    else
        echo "INFO : generate random password using gen_password"
        SB_PASSWORD=$(gen_password)
        echo $SB_PASSWORD > "$SB_ETC_DIR/.${SB_BASE_NAME}_password.txt"
    fi
fi

# generate a default swingbench schema password
if [ -n "$SB_DBA_PASSWORD" ]; then
    echo_debug "DEBUG: use password from config file as default password..."
    echo $SB_DBA_PASSWORD > "$SB_ETC_DIR/.${SB_BASE_NAME}_dba_password.txt"
else
    if [ -f "$SB_ETC_DIR/.${SB_BASE_NAME}_dba_password.txt" ]; then
        echo "INFO : found pwd file $SB_ETC_DIR/.${SB_BASE_NAME}_dba_password.txt"
        SB_DBA_PASSWORD=$(cat $SB_ETC_DIR/.${SB_BASE_NAME}_dba_password.txt)
    else
        echo "INFO : generate random password using gen_password"
        SB_DBA_PASSWORD=$(gen_password)
        echo $SB_DBA_PASSWORD > "$SB_ETC_DIR/.${SB_BASE_NAME}_dba_password.txt"
    fi
fi
# - EOF Initialization ---------------------------------------------------------

# - Main -----------------------------------------------------------------------
set +o errexit                              # temporary disable errexit
# check if we already have a seed PDB
if pdb_exists; then
    if force_enabled; then
        echo_warn "INFO : PDB $SB_SEED_DB does exists will drop it as force mode is set"
        if ! dryrun_enabled; then
            drop_pdb $SB_SEED_DB
        else
            echo "INFO : Dry run enabled, skip drop of PDB $SB_SEED_DB"
        fi
    else
        clean_quit 40 $SB_SEED_DB
    fi 
fi

echo "INFO : Create PDB $SB_SEED_DB as clone from PDB\$SEED in current Oracle environment $ORACLE_SID"
echo "INFO : Whereby the PDB is created using the script $SB_SQL_DIR/sb_sbseed_create.sql"
echo "INFO : For customization update the script beforehand."
echo "INFO : Using the following configuration values:"
echo "INFO : SB_SEED_DB........ : $SB_SEED_DB"
echo "INFO : SB_TBS_NAME....... : $SB_TBS_NAME"
echo "INFO : SB_TBS_SIZE....... : $SB_TBS_SIZE"
echo "INFO : SB_DBA_USER....... : $SB_DBA_USER"
echo "INFO : SB_DBA_PASSWORD... : $SB_DBA_PASSWORD"
echo "INFO : SB_USER........... : $SB_USER"
echo "INFO : SB_PASSWORD....... : $SB_PASSWORD"
echo "INFO : SB_SCALE.......... : $SB_SCALE"

if ! dryrun_enabled; then
    ${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
        WHENEVER OSERROR EXIT 9;
        WHENEVER SQLERROR EXIT SQL.SQLCODE;
        CONNECT / AS SYSDBA
        SPOOL $SB_LOG_DIR/sb_sbseed_create_$TIMESTAMP.log
        @$SB_SQL_DIR/sb_sbseed_create.sql $SB_SEED_DB $SB_TBS_NAME $SB_TBS_SIZE $SB_DBA_PASSWORD
EOFSQL
    if [ $? != 0 ]; then clean_quit 33 "sqlplus $SB_SQL_DIR/sb_sbseed_create.sql"; fi 
else
    echo "INFO : Dry run enabled, skip create seed PDB $SB_SEED_DB"
fi

if ! dryrun_enabled; then
    echo "INFO : Initialize Audit infrastructure in $SB_SEED_DB"
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
    if [ $? != 0 ]; then clean_quit 33 "sqlplus audit initialisation"; fi 
else
    echo "INFO : Dry run enabled, skip audit initialisation in PDB $SB_SEED_DB"
fi

if ! dryrun_enabled; then
    echo "INFO : Install swingbench schema in $SB_SEED_DB using oewizard with scale $SB_SCALE"
    oewizard -cs //$(get_db_host):$(get_db_port)/$(get_db_service $SB_SEED_DB) \
        -dba $SB_DBA_USER -dbap $SB_DBA_PASSWORD -create \
        -scale $SB_SCALE -ts $SB_TBS_NAME -allindexes -nopart \
        -u $SB_USER -p $SB_PASSWORD -cl
    if [ $? != 0 ]; then clean_quit 33 "oewizard"; fi 
else
    echo "INFO : Dry run enabled, skip swingbench schema deployment in PDB $SB_SEED_DB"
fi

clean_quit 0                                # we are done, successfully quit
# --- EOF ----------------------------------------------------------------------
