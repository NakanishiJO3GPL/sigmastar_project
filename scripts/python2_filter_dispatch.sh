#!/bin/bash
# Sgs trade secret
# Copyright (c) [2019~2025] Sgs Technology Ltd.
# All rights reserved.
#
# Unless otherwise stipulated in writing, any and all information contained
# herein regardless in any format shall remain the sole proprietary of
# Sgs and be kept in strict confidence
# (Sgs Confidential Information) by the recipient.
# Any unauthorized act including without limitation unauthorized disclosure,
# copying, use, reproduction, sale, distribution, modification, disassembling,
# reverse engineering and compiling of the contents of Sgs Confidential
# Information is unlawful and strictly prohibited. Sgs hereby reserves the
# rights to any and all damages, losses, costs and expenses resulting therefrom.
#

##############################################################################
# Purpose:                                                                   #
# This script intercepts all python2 calls and dynamically selects Python 2  #
# or Python 3 based on an allowlist. This ensures backward compatibility     #
# by preventing execution of Python2-specific code in non-allowlisted scripts.#
#                                                                            #
# Usage:                                                                     #
# 1. Symlink python2 to this script:                                         #
#    ln -sf /path/to/this_script $(readlink -f $(which python2))                      #
# 2. Configure ALLOW_LIST below with allowed paths/filenames                 #
# 3. click to https://sswiki.sgs.com.tw:8090/pages/viewpage.action?pageId=91464841
#    for more information                                                  #
#                                                                            #
##############################################################################

# allow_list configuration
ALLOW_LIST=()
VISTT_LINK="https://sswiki.sgs.com.tw:8090/pages/viewpage.action?pageId=91464841"

THIS_SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$THIS_SCRIPT_PATH")

# Calculate base directory, alkaid_code for example
BASE_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")
BASE_DIR=$(realpath -s "$BASE_DIR")

PYTHON2_REAL="python2_real"

ARGS=("$@")

# Extract target script path and filename from arguments
TARGET_SCRIPT_PATH=""
for arg in "${ARGS[@]}"; do
    if [[ "$arg" == *.py ]]; then
        TARGET_SCRIPT_PATH=$(realpath -s "$arg")
        break
    fi
done

# Only process scripts under BASE_DIR
if [[ "$TARGET_SCRIPT_PATH" == "$BASE_DIR"* ]]; then
    is_allowed=false
    for pattern in "${ALLOW_LIST[@]}"; do
        # Match either filename or relative path
        if [[ "$TARGET_SCRIPT_PATH" == *"/$pattern" ]]; then
            is_allowed=true
            break
        fi
    done

    if $is_allowed; then
        exec "$PYTHON2_REAL" "$@"
    else
        LOG_FILE="${BASE_DIR}/project/python2_filter_not_whitelist.log"
        NEW_CONTENT="[ERROR] cannot use python2 for $TARGET_SCRIPT_PATH"
        if [ ! -f "$LOG_FILE" ]; then
            echo "For resolution steps, visit ${VISTT_LINK}" > $LOG_FILE
        fi
        echo "For resolution steps, visit ${VISTT_LINK}"
        echo "${NEW_CONTENT}" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    exec "$PYTHON2_REAL" "$@"  # not alkaid_code path
fi