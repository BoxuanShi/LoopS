#!/bin/bash

# This script looks for the necessary BOOST sub-libraries.
# If found, it prints out two SHELL assignments (to be processed
# using the eval commmand) to BOOST_LIB_DIR & BOOST_LDLIBS.
# If not, it prints out a warning and returns with exit code 1.

SCRIPT_NAME=[[`basename "$0"`]]

SUBLIBS="system thread filesystem"

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

##################################################################
# Check we have 1 arg

if [ "$#" \!= "1" -o -z "$1" ]
then
    echo "ERROR: expected 1 arg (full path of BOOST_HDR_DIR)   $SCRIPT_NAME"   > /dev/stderr
    exit 1
fi

if [ \! -d "$1" -o \! -d "$1/boost" ]
then
  echo "ERROR: arg must be a directory containing subdir \"boost\"   $SCRIPT_NAME"   > /dev/stderr
  exit 2
fi

BOOST_HDR_DIR="$1"

# Check environment variable COCOA_EXTLIB_DIR

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



#############################################################################
# Find directory of this script (taken from link below)
# http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself

pushd . > /dev/null
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]
do
  cd "`dirname "$SCRIPT_PATH"`"
  SCRIPT_PATH="$(readlink "`basename "$SCRIPT_PATH"`")"
done
cd "`dirname "$SCRIPT_PATH"`" > /dev/null
SCRIPT_DIR="`pwd`"
popd  > /dev/null


has_libboost_mt ()
{
    MISSING_SUBLIBS=
    for sublib in $SUBLIBS
    do
	/bin/ls "${1}"/libboost_$sublib-mt.* >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
	    MISSING_SUBLIBS="libboost_$sublib-mt $MISSING_SUBLIBS"
	fi
    done
    test -z "$MISSING_SUBLIBS"
}

has_libboost ()
{
    MISSING_SUBLIBS=
    for sublib in $SUBLIBS
    do
	/bin/ls "${1}"/libboost_$sublib.* >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
	    MISSING_SUBLIBS="libboost_$sublib $MISSING_SUBLIBS"
	fi
    done
    test -z "$MISSING_SUBLIBS"
}


# Special handling if BOOST is not fully installed...
if [ -d "$BOOST_HDR_DIR/stage" -a -r "$BOOST_HDR_DIR/stage" -a -d "$BOOST_HDR_DIR/stage/lib" -a -r "$BOOST_HDR_DIR/stage/lib" ]
then
    BOOST_LIB_DIR="$BOOST_HDR_DIR/stage/lib"
else
    # CHEAP HACK: prefer lib/x86_64-linux-gnu over lib64 over lib
    # Remember: GMP probably chose 64-bits
    BOOST_LIB_DIR_DIR="`dirname \"$BOOST_HDR_DIR\"`"
    for subdir in  lib/x86_64-linux-gnu  lib64  lib  lib/i386-linux-gnu
    do
      DIR="$BOOST_LIB_DIR_DIR/$subdir"
      if [ -d "$DIR" ]
      then
        if has_libboost_mt "$DIR"
        then
          TAIL="-mt"
          BOOST_LIB_DIR="$DIR"
          break
	fi
        if has_libboost "$DIR"
        then
          TAIL=
          BOOST_LIB_DIR="$DIR"
          break
	fi
      fi
    done
fi

if [ -z "$BOOST_LIB_DIR" ]
then
    echo "WARNING: BOOST headers found, but not the required BOOST libs ($SUBLIBS)   $SCRIPT_NAME"   > /dev/stderr
    echo > /dev/stderr
  exit 1
fi

# Heuristic for recognizing standard installation of BOOST
BOOST_LIB_DIR_DIR=`dirname "$BOOST_LIB_DIR"`
if [ "$BOOST_LIB_DIR_DIR" = /usr -o "$BOOST_LIB_DIR_DIR" = /usr/local ]
then
    BOOST_IS_STANDARD=yes  ## not currently used
else
    TAIL="-symlink"
    for sublib in $SUBLIBS
    do
	BOOST_LIB_ORIG=`/bin/ls "$BOOST_LIB_DIR"/libboost_$sublib$THREADED.* | head -1`
	BOOST_LIB_EXTN=`"$SCRIPT_DIR/extn.sh" "$BOOST_LIB_ORIG"`
	/bin/ln -s "$BOOST_LIB_ORIG" $COCOA_EXTLIB_DIR/lib/libboost_$sublib-symlink.$BOOST_LIB_EXTN
    done
fi

BOOST_LDLIBS=
for sublib in $SUBLIBS
do
    BOOST_LDLIBS="-lboost_$sublib$TAIL $BOOST_LDLIBS"
done
echo "BOOST_LIB_DIR=\"$BOOST_LIB_DIR\""
echo "BOOST_LDLIBS=\"$BOOST_LDLIBS\""
exit 0
