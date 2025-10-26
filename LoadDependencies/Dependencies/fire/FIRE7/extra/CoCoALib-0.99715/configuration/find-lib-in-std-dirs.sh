#!/bin/bash

SCRIPT_NAME=[[`basename "$0"`]]

# This script looks for the given library in the usual system dirs;
# the arg should be something like "libXYZ".
# If found, it prints out the full path of the library, and exits with code 0.
# If not, it prints out a warning and returns with exit code 1.


# CHEAP HACK: prefer lib/x86_64-linux-gnu over lib64 over lib
# Remember: GMP probably chose 64-bits
TOP_DIRS="/usr  /usr/local"
STD_DIRS="lib/x86_64-linux-gnu  lib64  lib  lib/i386-linux-gnu"

# ##################################################################
# # Check we have 1 arg

if [ "$#" != "1" -o -z "$1" ]
then
    echo "ERROR: expected 1 arg (name of library to look for, e.g. libgmp)   $SCRIPT_NAME"   > /dev/stderr
    exit 1
fi

LIB=$1

#######################################################

STATIC_LIB=
DYNAMIC_LIB=

for prefix in $TOP_DIRS
do
  for subdir in  $STD_DIRS
  do
    file="$prefix/$subdir/$LIB.a"
    if [ -f "$file" ]
    then
	if [ -n "$STATIC_LIB" ]
	then
	    echo "ERROR:  Multiple static libraries:   $SCRIPT_NAME"   > /dev/stderr
	    echo "$STATIC_LIB"                                         > /dev/stderr
	    echo "$file"                                               > /dev/stderr
	    exit 1
	fi
	STATIC_LIB="$file"
    fi

    file="$prefix/$subdir/$LIB.so"
    if [ -f "$file" ]
    then
	if [ -n "$DYNAMIC_LIB" ]
	then
	    echo "ERROR:  Multiple dynamic libraries:   $SCRIPT_NAME"   > /dev/stderr
	    echo "$DYNAMIC_LIB"                                         > /dev/stderr
	    echo "$file"                                                > /dev/stderr
	    exit 1
	fi
	DYNAMIC_LIB="$file"
    fi

    file="$prefix/$subdir/$LIB.dylib"
    if [ -f "$file" ]
    then
	if [ -n "$DYNAMIC_LIB" ]
	then
	    echo "ERROR:  Multiple dynamic libraries:   $SCRIPT_NAME"   > /dev/stderr
	    echo "$DYNAMIC_LIB"                                         > /dev/stderr
	    echo "$file"                                                > /dev/stderr
	    exit 1
	fi
	DYNAMIC_LIB="$file"
    fi
  done
done


# Error exit if found neither static nor dynamic libs
if [ -z "$STATIC_LIB" -a -z "$DYNAMIC_LIB" ]
then
  exit 1
fi


# Prefer static lib if both exist.
if [ -n "$STATIC_LIB" ]
then
  echo "$STATIC_LIB"
else
  echo "$DYNAMIC_LIB"
fi

exit 0
