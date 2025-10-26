#! /bin/bash

SCRIPT_NAME=[[`basename "$0"`]]
SCRIPT_DIR=`dirname "$0"`

# Script which extracts the version number from GMP header file (gmp.h)

if [ $# -ne 1 ]
then
  echo "ERROR: expected 1 arg (full path of gmp.h)   $SCRIPT_NAME" > /dev/stderr
  exit 1
fi

# Assume the file exists and is readable -- already checked in configure script.
GMP_H="$1"
GMP_INC_DIR=`dirname "$GMP_H"`

# Below we create a small C++ program for printing out the GMP version number.

umask 22
source "$SCRIPT_DIR/shell-fns.sh"
TMP_DIR=`mktempdir gmp-version-from-hdr`

pushd "$TMP_DIR"  > /dev/null
/bin/cat > prog.C <<EOF
#include "gmp.h"
#include <iostream>

int main()
{
  std::cout << __GNU_MP_VERSION << "." << __GNU_MP_VERSION_MINOR << "." << __GNU_MP_VERSION_PATCHLEVEL << std::endl;
}
EOF

$CXX -I"$GMP_INC_DIR" prog.C -o prog  2> /dev/null
if [ $? -ne 0 ]
then
  # Compilation failed
  echo "ERROR: Failed to find GMP version number; perhaps your GMP is too old?    $SCRIPT_NAME"    > /dev/stderr
  echo "ERROR: Are you sure that \"$GMP_H\" really is a recent GMP header file?   $SCRIPT_NAME"    > /dev/stderr
  exit 1
fi
GMP_VER=`./prog`

# CoCoALib source assumes existence of some fns which appeared only in GMP 4.2.
if [ "$GMP_VER" \< "4.2.1" ]
then
  echo "ERROR: GMP IS TOO OLD                       $SCRIPT_NAME"  > /dev/stderr
  echo "ERROR: Your version of GMP is too old: you have $GMP_VER"  > /dev/stderr
  echo "ERROR: but CoCoALib requires version 4.2.1 or newer."      > /dev/stderr
  echo "ERROR: Header file is $GMP_HDR"                            > /dev/stderr
  echo "ERROR: Library file is $GMP_LIB"                           > /dev/stderr
  echo "ERROR: The latest GMP can be found at http://gmplib.org/"  > /dev/stderr
  exit 1
fi

popd  > /dev/null
/bin/rm -rf "$TMP_DIR"
echo $GMP_VER
