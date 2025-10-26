#! /bin/bash

# Script to print out cddlib version number.
# Expects env variables CXX and CXXFLAGS to be set.

echo ">>> THIS SCRIPT DOES NOT WORK YET <<<"
exit 99


SCRIPT_NAME=[[`basename "$0"`]]
SCRIPT_DIR=`dirname "$0"`

if [ -z "$CXX" ]
then
  echo "ERROR: CXX environment variable is not defined   $SCRIPT_NAME"  > /dev/stderr
  exit 1
fi

# Create tmp directory, put test prog in it, compile and run.
umask 22
source "$SCRIPT_DIR/shell-fns.sh"
TMP_DIR=`mktempdir cddlib-version`

pushd "$TMP_DIR"  > /dev/null
/bin/cat > CddlibVersion.C  <<EOF
#include <stdio.h>

extern "C"
{
  void dd_WriteProgramDescription(FILE *f);
}

int main()
{
  dd_WriteProgramDescription(stdout);
  return 0;
}
EOF


# !!!!!!!!!!!!MUST ADD LINKING ARGS!!!!!!!!!!!!
$CXX $CXXFLAGS -L/usr/local/lib -lcdd  CddlibVersion.C -o CddlibVersion  > LogFile  2>&1
if [ $? -ne 0 ]
then
  echo "ERROR: Compilation of test program failed --> see LogFile   $SCRIPT_NAME"  > /dev/stderr
  exit 3  # do not clean TMP_DIR, for possible debugging
fi
CDD_VER=`./CddlibVersion 2> LogFile`
if [ $? -ne 0 ]
then
  echo "ERROR: test program crashed --> see LogFile   $SCRIPT_NAME"  > /dev/stderr
  exit 1
fi

# Clean up TMP_DIR
popd  > /dev/null
/bin/rm -rf "$TMP_DIR"
echo $CDD_VER
exit 0
