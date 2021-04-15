#!/usr/bin/bash

#Defined paths
export GITHUB_PATH="https://github.com/DavidHuber-NOAA/global-workflow"
export GW_ROOT_PATH="/data/users/dhuber/gw_nightly_build"
export HOMEDIR="/data/users/dhuber"
export GW_BRANCH="gfsv16b_port2s4"
export SOURCE_DIR="${GW_ROOT_PATH}/sorc"
export EMAIL_ADDR="dhuber@redlineperf.com"
export COMPILER_MODULES="license_intel/S4 intel/18.0.3"

cd $HOMEDIR
if [ -e $GW_ROOT_PATH ]; then
   message="$GW_ROOT_PATH already exists!  Cannot perform nightly build!"
   echo $message
   cat > email.txt << EOF
      Subject: Nightly build failure
      $message
EOF
   sendmail $EMAIL_ADDR < email.txt
   rm -f email.txt
   exit 1
fi

#Clone the repository
git clone $GITHUB_PATH $GW_ROOT_PATH
if [ $? != 0 ]; then
   message="Failed to checkout $GITHUB_PATH to $GW_ROOT_PATH, aborting nightly build!"
   eco $message
   cat > email.txt << EOF
      Subject: Nightly build failure
      $message
EOF
   sendmail $EMAIL_ADDR < email.txt
   rm -f email.txt
   exit 2
fi

#Checkout the branch
cd $GW_ROOT_PATH
git checkout $GW_BRANCH

cd $SOURCE_DIR
./checkout.sh 2>&1 | tee checkout.log

#Check for checkout errors
ERR=$?

if [ $ERR != 0 ]; then
   echo "Failed to checkout the global workflow"
   cat > email.txt << EOF
      Subject: Nightly build failure
      During the nightly build, the script checkout.sh failed to checkout all modules.
EOF
   sendmail $EMAIL_ADDR < email.txt
   rm -f email.txt

   exit $ERR
fi

#Build the workflow
module load $COMPILER_MODULES
cd $SOURCE_DIR
./build_all.sh >& build.log

#Check for errors
ERR=$?

if [ ERR != 0 ]; then
   echo "One or more builds failed"
   cat > email.txt << EOF
      Subject: Nightly build failure
      During the nightly build, one or more programs failed to build.  The log from the build follows.
EOF

   cat build.log >> email.txt
   sendmail $EMAIL_ADDR < email.txt
   rm -f email.txt
   exit $ERR

fi
