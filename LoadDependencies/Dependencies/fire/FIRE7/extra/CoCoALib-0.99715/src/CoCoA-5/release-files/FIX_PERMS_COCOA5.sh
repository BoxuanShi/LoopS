#! /bin/bash

#  ~/shell-scripts/FIX_PERMS.sh  <cocoa-release-dir>
######################################################################
COCOAPATH=$1
######################################################################

pushd $COCOAPATH
# Quick sanity check that we are in CoCoA-5 release dir
if [ \! -f cocoa5 -o \! -d bin -o \! -f bin/CoCoAInterpreter -o \! -d packages -o \! -d CoCoAManual ]
then
    echo "ERROR: $0 expects to be run on CoCoA-5 release directory"
    exit 1
fi

# >>>ASSUMES<<< that find and chmod behave normally!
# FIND=/usr/bin/find
# CHMOD=/usr/bin/chmod

# Remove MacOS X files
# find . -name ._\* -exec /bin/rm {} \;

# dirs should be 755
find . -type d  -exec chmod 755 {} \;

# most normal files should be 644
find . -type f  -exec chmod 644 {} \;

# executables should be 755
chmod 755 cocoa5
chmod 755 bin/CoCoAInterpreter
find . -name \*.sh    -exec chmod 755 {} \;
find . -name \*.command    -exec chmod 755 {} \;

popd
