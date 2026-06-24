#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: sb_seed_clone.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
# Editor.....: Stefan Oehrli
# Date.......: 2023.11.16
# Revision...: 
# Purpose....: Script to drop the seed database of OraDBA SecBench
# Notes......: --
# Reference..: https://github.com/oehrlis/secbench
# License....: Licensed under the Apache License, Version 2.0 (the "License");
#              you may not use this file except in compliance with the License.
#              You may obtain a copy of the License at
#              http://www.apache.org/licenses/LICENSE-2.0
#              Unless required by applicable law or agreed to in writing, software
#              distributed under the License is distributed on an "AS IS" BASIS,
#              WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#              See the License for the specific language governing permissions and
#              limitations under the License.
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
DEFAULT_SEED_DB="sbpdb_seed"          # default name for the SecBench seed database
DEFAULT_TOOLS="sqlplus"
# - End of Customization -------------------------------------------------------

# - Default Values -------------------------------------------------------------
# source genric environment variables and functions
export SB_SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
export SB_BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export SB_ETC_DIR="$(dirname "${SB_BIN_DIR}")/etc"
export SB_LOG_DIR="$(dirname "${SB_BIN_DIR}")/log"

# define logfile and logging
export LOG_BASE="${LOG_BASE:-"${SB_BIN_DIR}"}"  # Use script directory as default log base
# Define Logfile but first reset LOG_BASE if directory does not exist
if [[ ! -d "${LOG_BASE}" ]] || [[ ! -w "${LOG_BASE}" ]]; then
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

  Usage: ${SB_SCRIPT_NAME} [options] [drop options] [seed pdb]

  where:
    seed pdb	        Name of the seed PDB. This PDB will be removed without
                        further notice

  Common Options:
    -h                  Usage this message
    -v                  Enable verbose mode (default \$SB_VERBOSE=${SB_VERBOSE})
    -d                  Enable debug mode (default \$SB_DEBUG=${SB_DEBUG})
 
  Delete options:
    -S <SEED PDB>       Name of the seed PDB (mandatory)
    -T <BENCH PDB>      Name of the benchmark PDB (mandatory)
    -n                  Dry run mode. Show what would be done but do not actually do it
    -F                  Force mode to delete the seed PDB

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
if [[ -f "${SB_BIN_DIR}/sb_functions.sh" ]]; then
    . "${SB_BIN_DIR}/sb_functions.sh"
else
    echo "ERROR: Cannot find common functions ${SB_BIN_DIR}/sb_functions.sh"
    exit 5
fi

trap on_term TERM SEGV      # handle TERM SEGV using function on_term
trap on_int INT             # handle INT using function on_int
load_config                 # load configur26ation files. File list in SB_CONFIG_FILES

check_tools                 # check if we do have the required tools available
dump_runtime_config         # dump current tool specific environment in debug mode

# get options
while getopts "hvqdf:S:T:nFE:" CurOpt; do
    case "${CurOpt}" in
        h) Usage 0;;
        v) VERBOSE=1;;
        d) DEBUG=1 && VERBOSE=1;;
        q) QUIET=1 && VERBOSE='' && DEBUG='' ;;
        S) SB_SEED_DB="${OPTARG}";;
        T) SB_SECBENCH_DB="${OPTARG}";;
        F) SB_FORCE="TRUE";;
        n) SB_DRYRUN="TRUE";;
        E) exit_with_status "${OPTARG}";;
        *) Usage 2 "$*";;
    esac
done

# display usage and exit if parameter is null
if [[ $# -eq 0 ]]; then
   Usage 1
fi

# Default values
export SB_SEED_DB=${SB_SEED_DB:-""}
export SB_SECBENCH_DB=${SB_SECBENCH_DB:-""}

# check for Service and Arguments
# check for Service and Arguments
if [[ -z "${SB_SEED_DB}" ]] && [[ $# -ne 0 ]]; then
    if [[ "$1" =~ ^-.*  ]]; then
        SB_SEED_DB="${DEFAULT_SEED_DB:-""}"  # default service to ORACLE_SID if Argument starts with a dash 
    else
        SB_SEED_DB="$1"                      # default service to Argument if not starting with a dash
    fi
fi

# Check for mandatory parameters
if [[ -z "${SB_SEED_DB}" ]] || [[ -z "${SB_SECBENCH_DB}" ]]; then 
    exit_with_status 3 "-S and -T are mandatory"
fi

# List of required SQL files
required_files=(
    "sb_secbench_drop_pdb.sql"
    "sb_secbench_create_pdb.sql"
)

# Loop through each required file and check for its existence
for file in "${required_files[@]}"; do
    if [[ ! -f "${SB_SQL_DIR}/${file}" ]]; then
        exit_with_status 22 "${SB_SQL_DIR}/${file}"
    fi
done

# - EOF Initialization ---------------------------------------------------------

# - Main -----------------------------------------------------------------------
log_message WARN "WARN : Proceed PDB $SB_SECBENCH_DB in current Oracle environment $ORACLE_SID"
# Stuff to be checked
# - if SID is an oracle database and if it is availabe

# Main logic for cloning the PDB
set +o errexit  # temporary disable errexit
if pdb_exists "${SB_SEED_DB}"; then
    log_message "INFO" "Clone PDB ${SB_SEED_DB} from ${SB_SEED_DB}"
    if pdb_exists "${SB_SECBENCH_DB}"; then
        if force_enabled; then
            drop_pdb "${SB_SECBENCH_DB}"
            create_pdb "${SB_SEED_DB}" "${SB_SECBENCH_DB}"
        else
            while true; do
                read -r -p "INFO : Do you really want to remove ${SB_SECBENCH_DB}? (y/n): " yn
                case "${yn}" in 
                    [yY] )  log_message "INFO" "OK, let's proceed and drop ${SB_SECBENCH_DB}";
                            break;;
                    [nN] )  log_message "INFO" "Stop ${SB_SCRIPT_NAME}" ;
                            exit_with_status 0;;
                    * )     log_message "WARN" "Invalid response";;
                esac
            done
            drop_pdb "${SB_SECBENCH_DB}"
            create_pdb "${SB_SEED_DB}" "${SB_SECBENCH_DB}"
        fi
    else
        create_pdb "${SB_SEED_DB}" "${SB_SECBENCH_DB}"
    fi
else
    exit_with_status 41 "${SB_SEED_DB}"
fi
exit_with_status 0  # we are done, successfully quit
# --- EOF ----------------------------------------------------------------------
