#!/usr/bin/bash
#Name: Global workflow nightly build script
#Purpose: Clone and build the global workflow and report any issues via email.  Intended to run nightly via cron.
#Author: David Huber (dhuber@redlineperf.com)
#Date: 5/19/2021

die() { echo "$@" >&2; exit 1; }
usage() {
  set +x
  echo
  echo "Usage: $0 -p | -b | -c | -n | -h"
  echo
  echo "  -p <URL>         URL to global workflow repository (default: git@github.com:NOAA-EMC/global-workflow)"
  echo "  -b <branch name> Git branch name (default: gfsv16b_port_2_s4)"
  echo "  -c <script path> Specify a checkout script. If not specified the script in the global-workflow is used."
  echo "  -n <test name>   Name of the test (default: gw_nightly_build)"
  echo "  -h               Display this help"
  echo
  set -x
  exit 1
}

get_abs_dirname() {
  # get the path to the absolute directory of a given file (relative path)
  # $1 : relative filename
  _here=$(pwd)

  echo "$(cd "$(dirname "$1")" && pwd)"
  cd ${_here}
}

if [ -f /etc/bashrc ]; then
   . /etc/bashrc
   source /etc/profile
fi

SCRIPT_DIR=$(get_abs_dirname "${0}")

#set -x

#Defined paths
export HOMEDIR="/data/users/isouopgui"
export TEST_NAME="gw_nightly_build"
#Repo/branch paths
#Set defaults
export GITHUB_PATH="git@github.com:NOAA-EMC/global-workflow"
export GITHUB_PATH="https://github.com/NOAA-EMC/global-workflow"
export GW_BRANCH="develop"
export SPECIFY_CHECKOUT="No"
#Modify if specified
while getopts ":p:b:" opt; do
   case $opt in
      p)
         export GITHUB_PATH=$OPTARG
         ;;
      b)
         export GW_BRANCH=$OPTARG
         ;;
      c)
         export CHECKOUT_SCRIPT=$OPTARG
         if [[ -e $CHECKOUT_SCRIPT ]]; then
            #Get the full path
            export CHECKOUT_SCRIPT=`readlink -f $OPTARG`
         else
            die "File does not exist: $OPTARG"
         fi
         export SPECIFY_CHECKOUT="Yes"
         ;;
      n)
         export TEST_NAME=$OPTARG
         ;;
      h)
         usage
         ;;
      \?)
         usage
         die "Invalid option: -$opt"
         ;;
      :)
         usage
         die "Option -$opt requires an argument"
         ;;
   esac
done

#Build directory path names
export GW_ROOT_PATH="${HOMEDIR}/$TEST_NAME"
export SOURCE_DIR="${GW_ROOT_PATH}/sorc"

#Notification email address
export EMAIL_ADDR="isouopgui@redlineperf.com"

#

SEND_CMD="sendmail -F '(<GW>Nightly-Build)' ${EMAIL_ADDR}"

#Navigate to the root directory
cd $HOMEDIR

#Check if the nightly build folder exists (indicates yesterday's attempt failed)
if [ -e $GW_ROOT_PATH ]; then
   #Send out an email if the directory already exists
   message="$GW_ROOT_PATH already exists!  Cannot perform nightly build!"
   echo $message
   cat > email.txt << EOF
Subject: Nightly build failure

$message
EOF
   ${SEND_CMD} < email.txt
   rm -f email.txt
   exit 1
fi

#Clone the repository
# git clone --recurse-submodules $GITHUB_PATH $GW_ROOT_PATH
# load git module to have a newer version of git
module load git
git clone --recursive  $GITHUB_PATH $GW_ROOT_PATH
if [[ $? -ne 0 ]]; then
   message="Failed to checkout $GITHUB_PATH to $GW_ROOT_PATH, aborting nightly build!"
   echo $message
   cat > email.txt << EOF
Subject: Nightly build failure

$message
EOF
   ${SEND_CMD} < email.txt
   rm -f email.txt
   exit 2
fi

# content of the replacement script

REPLACEMENT_SCRIPT=${SCRIPT_DIR}/replace.sh
printf "SCRIPT_DIR = ${SCRIPT_DIR} \n"
ls ${SCRIPT_DIR}
printf "REPLACEMENT_SCRIPT = ${REPLACEMENT_SCRIPT} \n"
ls -lh ${REPLACEMENT_SCRIPT}

# replace files that need replacement
#if [[ -f ${REPLACEMENT_SCRIPT} ]] ; then
   ${REPLACEMENT_SCRIPT} "${GW_ROOT_PATH}"
#fi
# cd $SOURCE_DIR
# ./build_ufs.sh
# exit

#Build the workflow
cd $SOURCE_DIR
timeout 10800 ./build_all.sh -g 2>&1 | tee build.log

#Check for errors
ERR=$?
timeout_err=0
script_err=0

#Check for a timeout error 124
if [[ $ERR -eq 124 ]]; then
   timeout_err=1
   echo "The build timed out"
#Check for any other error
elif [[ $ERR -ne 0 ]]; then
   script_err=1
   echo "A problem occurred with the build script, code: $ERR"
fi

#Also check the logs for errors; treat warnings as errors
log_err=0
if grep -iq "fatal\|fail\|error\|warning" build.log; then
   echo Found an error in the log file
   log_err=1
   if [[ $ERR -eq 0 ]]; then
      ERR=1
   fi
fi

#If an error was found, then report it
if [[ $ERR -ne 0 ]]; then

   echo "One or more builds failed"
   cat > email.txt << EOF
Subject: Nightly build failure

During the nightly build, one or more programs failed to build.  The log from the build follows.
EOF

   cat build.log >> email.txt

   if [[ $timeout_err -eq 1 ]] ; then
      echo "<The compilation then timed out>" >> email.txt
   fi

   if [[ $log_err -eq 1 ]] ; then
      echo "<One or more of the builds reported an error>" >> email.txt
   fi

   if [[ $script_err -ne 0 ]] ; then
      echo "<A problem occurred with the build script>" >> email.txt
   fi
   ${SEND_CMD} < email.txt
   rm -f email.txt
   exit $ERR

#If everything went OK, then delete the test build directory
else
   cd $HOMEDIR
   rm -rf ${GW_ROOT_PATH}
   exit 0
fi
