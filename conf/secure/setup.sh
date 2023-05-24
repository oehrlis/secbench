#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: setup.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
# Editor.....: Stefan Oehrli
# Date.......: 2023.05.20
# Revision...: 
# Purpose....: Script to setup configuration for specific benchmark
# Notes......: --
# Reference..: https://github.com/oehrlis/secbench
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
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

SB_DBV_PWD=${SB_DBV_PWD:-""}
# generate a default swingbench schema password
if [ -n "$SB_DBV_PWD" ]; then
    echo_debug "DEBUG: use password from config file as DBV password..."
    echo $SB_DBV_PWD > "$SB_ETC_DIR/.dbv_password.txt"
else
    if [ -f "$SB_ETC_DIR/.dbv_password.txt" ]; then
        echo "INFO : found pwd file $SB_ETC_DIR/.dbv_password.txt"
        SB_DBV_PWD=$(cat $SB_ETC_DIR/.dbv_password.txt)
    else
        echo "INFO : generate random password using gen_password"
        SB_DBV_PWD=$(gen_password)
        echo $SB_DBV_PWD > "$SB_ETC_DIR/.dbv_password.txt"
    fi
fi
# - EOF Initialization ---------------------------------------------------------
# - Main -----------------------------------------------------------------------

echo "INFO : Update sqlnet.ora $TNS_ADMIN/sqlnet.ora"
sed -i 's/^#SQLNET.ENCRYPTION_TYPES/SQLNET.ENCRYPTION_TYPES/' $TNS_ADMIN/sqlnet.ora
sed -i 's/^#SQLNET.ENCRYPTION/SQLNET.ENCRYPTION/' $TNS_ADMIN/sqlnet.ora
sed -i 's/^#SQLNET.CRYPTO_CHECKSUM_TYPES/SQLNET.CRYPTO_CHECKSUM_TYPES/' $TNS_ADMIN/sqlnet.ora
sed -i 's/^#SQLNET.CRYPTO_CHECKSUMT/SQLNET.CRYPTO_CHECKSUM/' $TNS_ADMIN/sqlnet.ora

echo "INFO : Run network.sql script"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    ALTER SESSION SET CONTAINER=$SB_SECBENCH_DB;
    @$SB_WORK_DIR/network.sql
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Configure Audit in the PDB $SB_SECBENCH_DB"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    ALTER SESSION SET CONTAINER=$SB_SECBENCH_DB;
    @$SB_WORK_DIR/create_audit_policies_loc.sql
    @$SB_WORK_DIR/enable_audit.sql
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Configure TDE in the PDB $SB_SECBENCH_DB"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    ALTER SESSION SET CONTAINER=$SB_SECBENCH_DB;
    ADMINISTER KEY MANAGEMENT SET KEY FORCE KEYSTORE IDENTIFIED BY EXTERNAL STORE WITH BACKUP;
    ALTER SYSTEM SET encrypt_new_tablespaces = ALWAYS;
    @$SB_WORK_DIR/enable_ts_enc_a256.sql
EOFSQL

echo "INFO : Create common DB Vault users $ORACLE_SID:"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    CREATE USER c##sb_dv_owner IDENTIFIED BY $SB_DBV_PWD;
    GRANT CREATE SESSION, SET CONTAINER TO c##sb_dv_owner CONTAINER = ALL;
    CREATE USER c##sb_dv_accmgr IDENTIFIED BY $SB_DBV_PWD;
    GRANT CREATE SESSION, SET CONTAINER TO c##sb_dv_accmgr CONTAINER = ALL;
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Enable DB Vault in $ORACLE_SID:"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    EXEC dvsys.configure_dv('c##sb_dv_owner','c##sb_dv_accmgr');
    CONNECT c##sb_dv_owner/$SB_DBV_PWD@$(get_db_host):$(get_db_port)/$(get_db_service $ORACLE_SID) 
    EXEC dbms_macadm.enable_dv;
    CONN / AS SYSDBA
    STARTUP FORCE;
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Enable DB Vault in $SB_SECBENCH_DB:"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    ALTER SESSION SET CONTAINER=$SB_SECBENCH_DB;
    EXEC dvsys.configure_dv('c##sb_dv_owner','c##sb_dv_accmgr');
    CONNECT c##sb_dv_owner/$SB_DBV_PWD@$(get_db_host):$(get_db_port)/$(get_db_service $SB_SECBENCH_DB) 
    EXEC dbms_macadm.enable_dv;
    CONN / AS SYSDBA
    ALTER SESSION SET CONTAINER=$SB_SECBENCH_DB;
    STARTUP FORCE;
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Verify DB Vault in $ORACLE_SID CDB\$ROOT and $SB_SECBENCH_DB:"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONN / AS SYSDBA
    COL DESCRIPTION FOR A60
    SELECT * FROM DBA_DV_STATUS;
    SELECT * FROM DBA_OLS_STATUS;
    SELECT * FROM CDB_DV_STATUS;
    SELECT * FROM CDB_OLS_STATUS;
EOFSQL

echo "INFO : Config DB Vault Realms in $SB_SECBENCH_DB:"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT c##sb_dv_owner/$SB_DBV_PWD@$(get_db_host):$(get_db_port)/$(get_db_service $SB_SECBENCH_DB)
    @$SB_WORK_DIR/config_dbvault.sql
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

echo "INFO : Configure Audit for DB Vault the PDB $SB_SECBENCH_DB"
${ORACLE_HOME}/bin/sqlplus -S -L /nolog <<EOFSQL
    CONNECT / AS SYSDBA
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    ALTER SESSION SET CONTAINER=$SB_SECBENCH_DB;
    @$SB_WORK_DIR/config_dbv_audit.sql
EOFSQL
if [ $? != 0 ]; then clean_quit 33 "sqlplus error in $SB_BENCHMARK $SB_SCRIPT_NAME"; fi 

clean_quit 0
# --- EOF ----------------------------------------------------------------------
