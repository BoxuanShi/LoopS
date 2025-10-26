#!/bin/bash

SCRIPT_NAME=[[`basename "$0"`]]
SCRIPT_DIR=`dirname "$0"`

# Auxiliary script for CoCoALib configuration process.
# Expects env variable CXX to be set (to compiler's name).

# Script to see whether compiler is clang, and then link with special flags.
# If no warning is produced, the script prints -fPIC; otherwise it prints nothing.

if [ $# -ne 0 ]
then
  echo "ERROR: expected no args   $SCRIPT_NAME"  > /dev/stderr
  exit 1
fi

# Check environment variable CXX
if [ -z "$CXX" ]
then
  echo "ERROR: environment variable CXX not set.   $SCRIPT_NAME"  > /dev/stderr
  exit 1
fi


# Create tmp directory, put test prog in it, compile and run.
umask 22
source "$SCRIPT_DIR/shell-fns.sh"
TMP_DIR=`mktempdir fpic-ldflag`

pushd "$TMP_DIR"  > /dev/null

# test if it is clang:  .... a bit harsh, maybe...
/bin/cat > test-fpic-ldflag.C <<EOF
int main()
{
#ifdef __clang__
  exit(1);
#endif
}
EOF

FPIC_FLAG=-fPIC

"$CXX" -o test-fpic-ldflag  test-fpic-ldflag.C  > LogFile  2>& 1  &&  ./test-fpic-ldflag  >> LogFile  2>&1
if [ $? -ne 0 ]
then
  FPIC_LDFLAG="-Wl,-no_pie";
fi

# Clean up TMP_DIR
popd  > /dev/null
/bin/rm -rf "$TMP_DIR"
echo $FPIC_LDFLAG
