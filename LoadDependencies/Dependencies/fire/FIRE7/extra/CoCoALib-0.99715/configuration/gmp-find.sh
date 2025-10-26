#!/bin/bash

SCRIPT_NAME=[[`basename "$0"`]]

# This script looks for a GMP library in a standard location.
# If a single GMP library is found, it prints out the full path of
# the (static) library and returns with exit code 0.
# If none is found or several are found, it prints out an error message
# and returns with a non-zero exit code.

##################################################################
# Use find to search through various standard directories.
# NB look through all directories, even if a GMP has already been found.

# List of directories under which libgmp.a and/or libgmp.so is normally found.
STD_GMP_LIBDIRS="/usr/lib  /usr/lib/x86_64-linux-gnu  /usr/lib/i386-linux-gnu  /usr/lib64  /usr/lib32  /usr/local/lib  /opt/local/lib  /sw/lib  /usr/sfw/lib"
# # Some versions of Linux put libgmp.a in an immediate subdirectory of /usr/lib/
# for file in /usr/lib/*
# do
#   if [ -d "$file" ]
#   then
#     STD_GMP_LIBDIRS="$STD_GMP_LIBDIRS:$file"
#   fi
# done

LIBGMPPATHS=libgmp-paths
/bin/rm -rf $LIBGMPPATHS
for directory in $STD_GMP_LIBDIRS
do
  if [ -d "$directory" ]
  then
    if [ -f "$directory/libgmp.a" ];  then echo "$directory/libgmp.a"  >> $LIBGMPPATHS; continue; fi
    if [ -f "$directory/libgmp.so" ]; then echo "$directory/libgmp.so" >> $LIBGMPPATHS; fi
# # could use -maxdepth=1 instead of lines above
#    find "$directory" -name  libgmp.a   -print >> $LIBGMPPATHS  2> /dev/null
#    find "$directory" -name  libgmp.so  -print >> $LIBGMPPATHS  2> /dev/null
  fi
done

if [ \! -s $LIBGMPPATHS ]
then
  # Did not find any plausible GMP installation, so return empty handed.
    echo "ERROR: No GMP installation found; looked inside $STD_GMP_LIBDIRS   $SCRIPT_NAME"   > /dev/stderr
    echo ">>>>> HINT:  try installing the linux package libgmp-dev  <<<<<"  > /dev/stderr
    echo ">>>>> HINT:  or get sources from https://www.gmplib.org/  <<<<<"  > /dev/stderr
  /bin/rm $LIBGMPPATHS
  exit 1
fi

# Slightly odd call to wc is to avoid it printing out the file name.
if [ `wc -l < $LIBGMPPATHS` -ne 1 ]
then
  echo "ERROR:  Found multiple GMP libraries   $SCRIPT_NAME"   > /dev/stderr
  cat $LIBGMPPATHS                                             > /dev/stderr
  /bin/rm $LIBGMPPATHS
  exit 2
fi

# We have found a single file called libgmp.a or libgmp.so; do a couple of quick
# sanity checks before declaring our search successful...
GMP_LIB=`cat $LIBGMPPATHS`
/bin/rm $LIBGMPPATHS
if [ -f "$GMP_LIB" -a -r "$GMP_LIB" ]
then
  echo "$GMP_LIB"
  exit 0
else
  echo "ERROR: Trouble reading GMP library file $GMP_LIB   $SCRIPT_NAME"   > /dev/stderr
  exit 4
fi
