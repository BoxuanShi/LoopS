# !/bin/bash

# This script looks for a BOOST installation in a standard location.
# If a single BOOST installation is found, it prints out the full path of
# the dir containing subdir "boost" and returns with exit code 0.
# If none is found, it prints out an appropriate message (on /dev/stdout)
# and exits with code 1 (used by "configure" in CoCoA root dir).
# If several are found, it prints out an appropriate message (on stdout)
# and returns with exit code 2 (used by "configure" in CoCoA root dir).

# When a single directory is found, only a few basic sanity checks are performed.

SCRIPT_NAME=[[`basename "$0"`]]
SCRIPT_DIR=`dirname "$0"`

##################################################################
# List of most common directories in which boost header dir is normally found.
STD_BOOST_HDR_DIRS="/usr/local/include  /usr/include  /opt/local/include  /sw/include  /usr/sfw/include"

if [ $# -ne 0 ]
then
  echo "ERROR: expecting no args   $SCRIPT_NAME"  > /dev/stderr
  exit 2
fi


# We create a temp dir and work in there.
umask 22
source "$SCRIPT_DIR/shell-fns.sh"
TMP_DIR=`mktempdir boost-find-hdrs`
/bin/rm -rf "$TMP_DIR"  &&  /bin/mkdir -p "$TMP_DIR"
if [ $? -ne 0 ]
then
  echo "ERROR: failed to create temporary directory \"$TMP_DIR\"   $SCRIPT_NAME"   > /dev/stderr
  exit 2
fi

/bin/rm -rf "$TMP_DIR/BOOST-HDR-DIR"
for dir in $STD_BOOST_HDR_DIRS
do
  if [ -d "$dir" -a -r "$dir" -a -d "$dir/boost" -a -r "$dir/boost" ]
  then
    echo "$dir" >> "$TMP_DIR/BOOST-HDR-DIR"
  fi
done

if [ \! -e "$TMP_DIR/BOOST-HDR-DIR" ]
then
  # Did not find any plausible BOOST installation, so return empty handed.
  echo "ERROR: No BOOST installation found; looked inside $STD_BOOST_HDR_DIRS   $SCRIPT_NAME"   > /dev/stderr
  exit 1
fi

# Slightly odd call to wc is to avoid it printing out the file name.
if [ `wc -l < $TMP_DIR/BOOST-HDR-DIR` -ne 1 ]
then
  echo "ERROR: Found multiple BOOST libraries   $SCRIPT_NAME"   > /dev/stderr
  /bin/cat "$TMP_DIR/BOOST-HDR-DIR"                             >> /dev/stderr
  /bin/rm -rf "$TMP_DIR"
  exit 2
fi

# We have found a single suitable directory (it exists & is readable,
# and contains readable subdir called "boost"), so return it.
BOOST_HDR_DIR=`cat "$TMP_DIR/BOOST-HDR-DIR"`
/bin/rm -rf "$TMP_DIR"
echo "$BOOST_HDR_DIR"
