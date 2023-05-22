#!/bin/bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: sb_setup_seed.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
# Editor.....: Stefan Oehrli
# Date.......: 2023.05.19
# Revision...: 
# Purpose....: Script to download and unpack lateest swingbench
# Notes......: --
# Reference..: https://github.com/oehrlis/secbench
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# - Customization --------------------------------------------------------------
DEFAULT_SWINGBENCH_URL="https://www.dominicgiles.com/site_downloads/swingbenchlatest.zip"        # default swingbench download url
DEFAULT_TOOLS="curl unzip"
# - End of Customization -------------------------------------------------------

# - Default Values -------------------------------------------------------------
# source genric environment variables and functions
export SB_SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
export SB_BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
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
# - EOF Default Values ---------------------------------------------------------

# - Initialization -------------------------------------------------------------
# Define a bunch of bash option see 
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o nounset                              # stop script after 1st cmd failed
set -o errexit                              # exit when 1st unset variable found
set -o pipefail                             # pipefail exit after 1st piped commands failed

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

check_tools curl unzip  # check if we do have the required tools available
dump_runtime_config     # dump current tool specific environment in debug mode

# initialize default values
SB_SWINGBENCH_URL=${SB_SWINGBENCH_URL:-$DEFAULT_SWINGBENCH_URL}
export SB_SWINGBENCH_URL=${1:-$SB_SWINGBENCH_URL}

# set debug variable for commands
if [ "${SB_DEBUG^^}" == "TRUE" ]; then
    UNZIP_QUIET=""
    VERBOSE_FLAG="-v"
    CURL_SILENT=""
else
    UNZIP_QUIET="-q"
    VERBOSE_FLAG=""
    CURL_SILENT="-s"
fi
# - EOF Initialization ---------------------------------------------------------
 
# - Main -----------------------------------------------------------------------
echo "INFO : Download latest swingbench from $SB_SWINGBENCH_URL"
curl $CURL_SILENT -Lf "$SB_SWINGBENCH_URL" -o "$SB_BASE/swingbench.zip" || clean_quit 33 curl

# check if we do have a swingbench 
if [ -d "$SB_BASE/swingbench" ]; then
    echo_warn "WARN : swingbench folder already exists in $SB_BASE."
    echo_warn "WARN : archive current folder to $SB_BASE/swingbench_$TIMESTAMP.tgz"
    CURRENT_DIR=$(pwd)
    cd $SB_BASE
    tar $VERBOSE_FLAG -zcf "swingbench_$TIMESTAMP.tgz" swingbench
    rm $VERBOSE_FLAG -rf swingbench
    cd $CURRENT_DIR
fi

# unpack new swingbench
echo "INFO : Unpack swingbench to $SB_BASE"
unzip $UNZIP_QUIET "$SB_BASE/swingbench.zip" -d "$SB_BASE"  || clean_quit 33 unzip

rm "$SB_BASE/swingbench.zip"                # remove download
clean_quit 0                                # we are done, successfully quit
# --- EOF ----------------------------------------------------------------------
