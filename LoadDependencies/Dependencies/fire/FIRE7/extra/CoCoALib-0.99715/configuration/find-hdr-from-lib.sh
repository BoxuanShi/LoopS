#!/bin/bash

SCRIPT_NAME=[[`basename "$0"`]]

# This script looks  for the full path of the header for
# a given library (which is supposed to be in a system directory).
# It expects 2 args:
#   $1 is the tail of the path to the header file (e.g. cdd/cdd.h)
#   $2 is the full path of the library

# If the full path of the header is found, it prints out the dir
# in which the header was found, and the script exist with code 0.
# If not, it prints out a warning and returns with exit code 1.


##################################################################
# Check we have 2 args

if [ "$#" != "2" -o -z "$1" -o -z "$2" ]
then
  echo "ERROR: expected 2 args (name of header, full path of lib archive)   $SCRIPT_NAME"   > /dev/stderr
    exit 1
fi

HDR_NAME=$1
LIB=$2

#######################################################

LIB_DIR=`dirname "$LIB"`

PREFIX="$LIB_DIR/include"

if [ -f "$PREFIX/$HDR_NAME" ]
then
    echo $PREFIX
    exit 0
fi

LIB_DIR_DIR=`dirname "$LIB_DIR"`
PREFIX="$LIB_DIR_DIR/include"

if [ -f "$PREFIX/$HDR_NAME" ]
then
    echo $PREFIX
    exit 0
fi


echo "ERROR: Did not find header $HDR_NAME for library $LIB   $SCRIPT_NAME"   > /dev/stderr
exit 1
