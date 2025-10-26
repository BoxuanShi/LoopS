#!/bin/bash

# Various shell functions used in some of the Makefiles and other
# scripts included with CoCoALib.

# Copyright 2006 John Abbott.
# You are free to use any part of this code in your own programs.


mktempdir()
{
    TODAY=`date "+%Y%m%d"`
    TIME=`date "+%H%M%S"`
    TMP_DIR="/tmp/CoCoALib-config/$USER-$TODAY/$1-$TIME-$$"
    /bin/rm -rf "$TMP_DIR"  &&  /bin/mkdir -p "$TMP_DIR"
    if [ $? -ne 0 ]
    then
	echo "ERROR: failed to create temporary directory \"$TMP_DIR\"   $SCRIPT_NAME"   > /dev/stderr
	exit 1
    fi
    echo "$TMP_DIR"
}


echounderline()
{
  echo "$*"
  echo "$*" | tr "\040-\377" "[-*]"
}

echobox()
{
  mesg=">>>>  $*  <<<<"
  dashes=`echo "$mesg" | tr "\040-\377" "[-*]"`
  echo "$dashes"
  echo "$mesg"
  echo "$dashes"
}

echoerror()
{
  mesg=">>>>>  $*  <<<<<"
  equals=`echo "$mesg" | tr "\040-\377" "[=*]"`
  echo "$equals"
  echo "$mesg"
  echo "$equals"
}
