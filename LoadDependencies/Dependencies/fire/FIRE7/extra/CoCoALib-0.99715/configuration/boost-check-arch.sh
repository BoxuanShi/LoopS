#! /bin/bash

# Script to check that the BOOST libraries are linkable to
# a program compiled with the GMP compilation flags.
# We check just libboost_filesystem.a, and if that works OK
# then we assume all the BOOST libs are fine too.
# ASSUMES enviroment variables CXX and CXXFLAGS are set correctly.

SCRIPT_NAME=[[`basename "$0"`]]
SCRIPT_DIR=`dirname "$0"`

if [ $# -ne 1 ]
then
  echo "ERROR: expecting 1 arg (LIBS for linker)   $SCRIPT_NAME"  > /dev/stderr
  exit 1
fi

if [ -z "$CXX" ]
then
  echo "ERROR: expecting environment variables CXX and CXXFLAGS to be set   $SCRIPT_NAME"  > /dev/stderr
  exit 1
fi

BOOST_LDLIBS="$1"

# We create a temp dir and work in there.
umask 22
source "$SCRIPT_DIR/shell-fns.sh"
TMP_DIR=`mktempdir boost-check-arch`

pushd "$TMP_DIR"  > /dev/null

# Here is the simple source code we shall use to test the compiler:
/bin/cat > test-boost-arch.C <<EOF
#include "boost/filesystem.hpp"
using namespace boost::filesystem;

int main()
{
  path file = "test-boost-arch.C";
  if (!exists(file) || !is_regular_file(file)) exit(2);
}
EOF

echo "$CXX $CXXFLAGS  -I\"$COCOA_EXTLIB_DIR/include\" test-boost-arch.C -o test-boost-arch -L\"$COCOA_EXTLIB_DIR/lib\" $BOOST_LDLIBS" > LogFile
$CXX $CXXFLAGS  -I"$COCOA_EXTLIB_DIR/include" test-boost-arch.C -o test-boost-arch -L"$COCOA_EXTLIB_DIR/lib" $BOOST_LDLIBS  >> LogFile  2>&1
if [ $? -ne 0 ]
then
  echo "ERROR: compilation failed --> see LogFile   $SCRIPT_NAME"   > /dev/stderr
  exit 3
fi

echo "Running ./test-boost-arch" >> LogFile
./test-boost-arch  2>> LogFile
if [ $? -ne 0 ]
then
  echo "ERROR: test-boost-arch gave run-time error --> see LogFile   $SCRIPT_NAME"   > /dev/stderr
  exit 4
fi

# Clean up and return 0 for success.
popd  > /dev/null
/bin/rm -rf "$TMP_DIR"
exit 0
