#!/usr/bin/bash

R_ROOT=$(dirname "${0}")
source ${R_ROOT}/parse_arg.sh

R_GW_ROOT=${R_ROOT}/gw-replacements
GW_ROOT=${_arg_path}
printf " -------------------------------------------------\n"
printf "R_ROOT is ${R_ROOT}\n"
printf "ls R_ROOT --------------------\n"
ls ${R_ROOT}
printf " -------------------------------------------------\n"
printf "GW_ROOT is ${GW_ROOT}\n"
printf "ls GW_ROOT --------------------\n"
ls ${GW_ROOT}
# ==================== s4 module file for ufs_model.fd
F_DIR="sorc/ufs_model.fd/modulefiles"
b_name=ufs_s4.intel.lua
echo "copying  ${F_DIR}/${b_name}"
# cp ${R_GW_ROOT}/${F_DIR}/${b_name} ${GW_ROOT}/${F_DIR}/
