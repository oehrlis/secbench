#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: remove.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
# Editor.....: Stefan Oehrli
# Date.......: 2023.05.20
# Revision...: 
# Purpose....: Script to remove configuraton for specific benchmark
# Notes......: --
# Reference..: https://github.com/oehrlis/secbench
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
DEFAULT_SB_SECBENCH_DB="sbregular"      # default name for the SecBench PDB
# - End of Customization -------------------------------------------------------

# - Default Values -------------------------------------------------------------
# source genric environment variables and functions
export SB_SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
export SB_WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SB_BIN_DIR="$(dirname $(dirname ${SB_WORK_DIR}))/bin"
export SB_ETC_DIR="$(dirname $(dirname ${SB_WORK_DIR}))/etc"
export SB_LOG_DIR="$(dirname $(dirname ${SB_WORK_DIR}))/log"
export SB_BENCHMARK="$(basename ${SB_WORK_DIR})"

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

# - Initialization -------------------------------------------------------------
# initialize logfile
touch $LOGFILE 2>/dev/null
exec &> >(tee -a "$LOGFILE")                # Open standard out at `$LOG_FILE` for write.  
exec 2>&1  

echo "INFO : Start $SB_SCRIPT_NAME for $SB_BENCHMARK on host $(hostname) at $(date)"

# source common variables and functions from sb_functions.sh
if [ -f ${SB_BIN_DIR}/sb_functions.sh ]; then
    . ${SB_BIN_DIR}/sb_functions.sh
else
    echo "ERROR: Can not find common functions ${SB_BIN_DIR}/sb_functions.sh"
    exit 5
fi

# get some variables from calling script
SB_SECBENCH_DB=${1:-$DEFAULT_SB_SECBENCH_DB}

trap on_term TERM SEGV      # handle TERM SEGV using function on_term
trap on_int INT             # handle INT using function on_int
load_config                 # load configur26ation files. File list in SB_CONFIG_FILES

check_tools             # check if we do have the required tools available
dump_runtime_config     # dump current tool specific environment in debug mode
# - EOF Initialization ---------------------------------------------------------
# - Main -----------------------------------------------------------------------

echo "INFO : Set legacy audit parameter in ${ORACLE_SID}"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    ALTER SYSTEM RESET audit_trail SCOPE=SPFILE;
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Stop Database ${ORACLE_SID}:"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    SELECT value FROM v\$option WHERE parameter = 'Unified Auditing';
    SHUTDOWN IMMEDIATE;
    EXIT;
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Relink Database ${ORACLE_SID} to enable unified audit:"
cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk uniaud_on ioracle

echo "INFO : Start Database ${ORACLE_SID}:"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    STARTUP;
    SELECT value FROM v\$option WHERE parameter = 'Unified Auditing';
    EXIT;
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    ALTER SESSION SET CONTAINER=$SB_SECBENCH_DB;
    @$SB_WORK_DIR/remove.sql
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

clean_quit 0
# --- EOF ----------------------------------------------------------------------
