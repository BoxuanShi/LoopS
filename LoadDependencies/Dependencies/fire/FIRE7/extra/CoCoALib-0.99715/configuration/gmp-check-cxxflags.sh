#!/bin/bash

SCRIPT_NAME=[[`basename "$0"`]]
SCRIPT_DIR=`dirname "$0"`

# This script checks compatibility of user supplied CXXFLAGS with
# the GMP library.
# Exit code is 0 iff CXXFLAGS and GMP are compatible, o/w non-zero.

# This script expects 1 arg: the CXXFLAGS used to compile GMP
# Also expects that CXX and CXXFLAGS have been exported from caller.
# Also expects that the ExternalLibs/ subtree has been created.

# taken from StackExchange 256434
is_absolute()
{
    case "$1" in
	///* | //) true;;
	//*) false;;
	/*) true;;
	*) false;;
    esac
}


if [ $# -ne 0 ]
then
  echo "ERROR: expected no args                    $SCRIPT_NAME"   > /dev/stderr
  exit 1
fi

# Check environment variables CXX and COCOA_EXTLIB_DIR
if [ -z "$CXX" ]
then
  echo "ERROR: environment variable CXX not set.   $SCRIPT_NAME"   > /dev/stderr
  exit 1
fi

if [ -z "$COCOA_EXTLIB_DIR" ]
then
    echo "ERROR: environment variable COCOA_EXTLIB_DIR not set.   $SCRIPT_NAME"   > /dev/stderr
    exit 1
fi

# The following is a cryptic if...then block
is_absolute "$COCOA_EXTLIB_DIR" ||
(
  echo "ERROR: environment variable COCOA_EXTLIB_DIR is not absolute: \"$COCOA_EXTLIB_DIR\"   $SCRIPT_NAME"   > /dev/stderr
  exit 1
)


if [ \! -d "$COCOA_EXTLIB_DIR" -o \! -d "$COCOA_EXTLIB_DIR/include" -o \! -d "$COCOA_EXTLIB_DIR/lib" ]
then
  echo "ERROR: environment variable COCOA_EXTLIB_DIR is implausible: \"$COCOA_EXTLIB_DIR\"   $SCRIPT_NAME"   > /dev/stderr
  exit 1
fi



GMP_LDLIB=-lgmp
if [ -f "$COCOA_EXTLIB_DIR"/lib/libgmp-symlink.a ]
then
  GMP_LDLIB=-lgmp-symlink
fi


# Create tmp directory, put test prog in it, compile and run.
umask 22
source "$SCRIPT_DIR/shell-fns.sh"
TMP_DIR=`mktempdir gmp-check-cxxflags`

pushd "$TMP_DIR" > /dev/null
/bin/cat > test-gmp-cxxflags.c <<EOF
#include "gmp.h"

int main()
{
  mpz_t A; mpz_init_set_ui(A,1);
  mpz_t B; mpz_init_set_ui(B,1);
  mpz_add(A, A, B);
  if (mpz_cmp_ui(A, 2) != 0)
    return 1;
  return 0;
}
EOF


# Compile test prog using given CXX and CXXFLAGS, and GMP header and library
echo "$CXX $CXXFLAGS  test-gmp-cxxflags.c -o test-gmp-cxxflags -I\"$COCOA_EXTLIB_DIR/include\" -L\"$COCOA_EXTLIB_DIR/lib\" $GMP_LDLIB"  > LogFile
$CXX $CXXFLAGS  test-gmp-cxxflags.c -o test-gmp-cxxflags -I"$COCOA_EXTLIB_DIR/include" -L"$COCOA_EXTLIB_DIR/lib" $GMP_LDLIB  >> LogFile 2>&1

# Check whether compilation failed; if so, complain.
if [ $? -ne 0 ]
then
  # Deliberately leave $TMP_DIR to assist debugging.
  echo "ERROR: failed to compile/link test-gmp-cxxflags --> see LogFile.   $SCRIPT_NAME"   > /dev/stderr
  exit 2
fi

# Compilation succeeded, so try running $PROG.
echo "Run ./test-gmp-cxxflags" >> LogFile
./test-gmp-cxxflags  >> LogFile 2>&1

# Check whether execution failed; if so, complain (probably linker problems).
if [ $? -ne 0 ]
then
  # Deliberately leave $TMP_DIR to assist debugging.
  echo "ERROR: test-gmp-cxxflags crashed (probably linker problem for libgmp)   $SCRIPT_NAME"   > /dev/stderr
  exit 3
fi

# Clean up TMP_DIR
popd  > /dev/null
/bin/rm -rf "$TMP_DIR"
exit 0
