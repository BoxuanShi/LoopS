#!/bin/bash
#  cd release-files/; release-win-fromMac.sh
#--------------------------------------

# WEBSITE="www.dima.unige.it:/Volumes/WWW/webcocoa"
# WEBSITE="130.251.60.18:/Volumes/WWW/webcocoa"
WEBSITE="WWW/webcocoa"

#--------------------------------------
# CVS directory with latest version (either arg or default value)
if [ $# = 0 ]
then
  COCOALIBDIRWithCVS=`cd ../../..; pwd`
else
  COCOALIBDIRWithCVS=`cd "$1"; pwd`
fi

#--------------------------------------
# Check that cocoa5-microsoft is up-to-date.
# if [ "$COCOALIBDIRWithCVS/src/CoCoA-5/cocoa5"  -nt  "$COCOALIBDIRWithCVS/src/CoCoA-5/release-files/cocoa5-microsoft" ]
# then
#     echo "ERROR: cocoa5-microsoft is older than src/CoCoA-5/cocoa5 script"  > /dev/stderr
#     exit 1;
# fi


#--------------------------------------
source "$COCOALIBDIRWithCVS/src/CoCoA-5/release-files/release-common.sh"

#--------------------------------------
# names for release directories
COCOA_TEXT=cocoa-$VER

WIN_RELEASE_DIR=$RELEASE_DIR/Windows
FULLPATH_RELEASE_TEXT_DIR=$WIN_RELEASE_DIR/$COCOA_TEXT
#FULLPATH_RELEASE_TEXT_DIR=$RELEASE_DIR/$COCOA_TEXT

#------------------------------------------------------------
cd $RELEASE_DIR/   # <------------ always assume we are here
#------------------------------------------------------------
echo " --======================--CoCoA-for-WINDOWS--======================--"
echo " --send-$COCOALIB.tgz:"
echo "cp ~/tmp/$COCOALIB.tgz /Volumes/SharedFolder/"
echo " --compile: ~/shell-scripts/cocoa5-win"
echo " --check emacs files in $FULLPATH_RELEASE_TEXT_DIR/../ToBeCopied"
echo " --copy-CoCoAInterpreter.exe:"
echo "cp /Volumes/SharedFolder/CoCoAInterpreter.exe $BINARY_DIR/"
echo " --REMEMBER! --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

mkdir -p $FULLPATH_RELEASE_TEXT_DIR
check-file "$FULLPATH_RELEASE_TEXT_DIR/../ToBeCopied/CoCoAInterpreter.exe"

cd ../CoCoAManual
make pdf-and-html-doc
cd $RELEASE_DIR/   # <------------ always assume we are here

#------------------------------------------------------------
echo " --vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv--"
echo " GENERATING RELEASE from sources in"
echo "   $COCOALIBDIRWithCVS"
echo " HAVE YOU CHECKED OUT AND COMPILED on WINDOWS?  If not, do it:"
echo " RELEASE DIR(s) will be:"
echo "   $FULLPATH_RELEASE_TEXT_DIR"
echo " --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--"

#------------------------------------------------------------
rename-existing-release "$FULLPATH_RELEASE_TEXT_DIR"

#------------------------------------------------------------
echo " --======-- text CoCoA for Windows  --======--"
copy-packages    $FULLPATH_RELEASE_TEXT_DIR
copy-CoCoAManual $FULLPATH_RELEASE_TEXT_DIR
copy-emacs-el    $FULLPATH_RELEASE_TEXT_DIR

cd $FULLPATH_RELEASE_TEXT_DIR/..

/bin/cp ToBeCopied/CoCoAInterpreter.exe $FULLPATH_RELEASE_TEXT_DIR/
/bin/cp ToBeCopied/cyg* $FULLPATH_RELEASE_TEXT_DIR/
/bin/cp ToBeCopied/*emacs $FULLPATH_RELEASE_TEXT_DIR/emacs

REL_NAME=`MakeRelName text-win`
echo "release file is $REL_NAME.zip"

MakeZIP "$COCOA_TEXT"
mv "$COCOA_TEXT.zip" "$REL_NAME.zip"

shasum -a 256 -b "$REL_NAME.zip"  >  "$REL_NAME.SHA"
echo "...done"

#------------------------------------------------------------
echo " --======-- suggest-sftp --======--"
echo "sftp storage1.dima.unige.it"
suggest-sftp-win $WIN_RELEASE_DIR/$REL_NAME zip
echo "exit"
echo "touch /Volumes/$WEBSITE/download/download5.shtml"
echo " --======-- end --======--"

