#!/bin/bash
#  choose one: --> with 0 or 1 arg, second arg must be CoCoALib dir
#  src/CoCoA-5/release-files/release-linux.sh .
#  release-files/release-linux.sh ../..
#  cd release-files/; release-linux.sh
#--------------------------------------

# WEBSITE="www.dima.unige.it:/Volumes/WWW/webcocoa"
# WEBSITE="130.251.60.18:/Volumes/WWW/webcocoa"
WEBSITE="WWW/webcocoa"

#--------------------------------------
# CVS directory with latest version (either arg or default value)
if [ $# -gt 1 ]
then
    echo "$0: expected 0 or 1 arg (path of CoCoA ROOT dir)"
    exit 1
fi
if [ $# = 0 ]
then
  COCOALIBDIRWithCVS=`cd ../../..; pwd`
else
  COCOALIBDIRWithCVS=`cd "$1"; pwd`
fi

#--------------------------------------
# Check that cocoa5-linux is up-to-date.
if [ "$COCOALIBDIRWithCVS/src/CoCoA-5/cocoa5"  -nt  "$COCOALIBDIRWithCVS/src/CoCoA-5/release-files/cocoa5-linux" ]
then
    echo "ERROR: cocoa5-linux is older than src/CoCoA-5/cocoa5 script"  > /dev/stderr
    exit 1;
fi


#--------------------------------------
source "$COCOALIBDIRWithCVS/src/CoCoA-5/release-files/release-common.sh"

#--------------------------------------
# names for release directories
COCOA_TEXT=cocoa-$VER

FULLPATH_RELEASE_TEXT_DIR=$RELEASE_DIR/$COCOA_TEXT

#------------------------------------------------------------
cd $RELEASE_DIR/   # <------------ always assume we are here
#------------------------------------------------------------
### currently disabled
# echo " --======-- CoCoA for linux 32/64 --======--"
# echo " --REMEMBER to copy the executables in ~/bin: --vvvvvvvvvvvvvvvvv"
# echo "cp $COCOALIBDIRWithCVS/src/CoCoA-5/CoCoAInterpreter ~/bin/CoCoAInterpreter-64"
# echo " --REMEMBER! --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

#check-file "$HOME/bin/CoCoAInterpreter-32"
#check-file "$HOME/bin/CoCoAInterpreter-64"
check-file "$COCOALIBDIRWithCVS/src/CoCoA-5/CoCoAInterpreter"

cd ..
make texdoc
make htmldoc
cd $RELEASE_DIR/   # <------------ always assume we are here

#------------------------------------------------------------
echo " --vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv--"
echo " GENERATING RELEASE from sources in"
echo "   $COCOALIBDIRWithCVS"
echo " HAVE YOU CHECKED OUT AND COMPILED?  If not, do it with either:"
echo "   cd $COCOALIBDIRWithCVS; ./configure --again; make"
echo "   cd $COCOALIBDIRWithCVS; make"
echo " RELEASE DIR(s) will be:"
echo "   $FULLPATH_RELEASE_TEXT_DIR"
echo " --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--"
#make -j3 library; make -j3

#------------------------------------------------------------
rename-existing-release "$FULLPATH_RELEASE_TEXT_DIR"

#------------------------------------------------------------
copy-packages    $FULLPATH_RELEASE_TEXT_DIR
copy-CoCoAManual $FULLPATH_RELEASE_TEXT_DIR
copy-emacs       $FULLPATH_RELEASE_TEXT_DIR

mkdir -p $FULLPATH_RELEASE_TEXT_DIR/bin
#/bin/cp ~/bin/CoCoAInterpreter-32  $FULLPATH_RELEASE_TEXT_DIR/bin/.
#/bin/cp ~/bin/CoCoAInterpreter-64  $FULLPATH_RELEASE_TEXT_DIR/bin/.
/bin/cp "$COCOALIBDIRWithCVS/src/CoCoA-5/CoCoAInterpreter"  $FULLPATH_RELEASE_TEXT_DIR/bin/.
strip $FULLPATH_RELEASE_TEXT_DIR/bin/CoCoAInterpreter
/bin/cp cocoa5-linux                                        $FULLPATH_RELEASE_TEXT_DIR/cocoa5
/bin/cp ConfigEmacs-linux.sh                                $FULLPATH_RELEASE_TEXT_DIR/emacs/ConfigEmacs.sh
chmod +x  $FULLPATH_RELEASE_TEXT_DIR/cocoa5
chmod +x  $FULLPATH_RELEASE_TEXT_DIR/emacs/ConfigEmacs.sh

# check permissions
find $FULLPATH_RELEASE_TEXT_DIR -type f -perm /022 -print > /tmp/cocoa-release-check
if [ -s /tmp/cocoa-release-check ]; then echo "SOME FILES WRITABLE:"; cat /tmp/cocoa-release-check; exit 1; fi
/bin/rm /tmp/cocoa-release-check

REL_NAME=`MakeRelName linux`
echo "release file is $REL_NAME.tgz"

MakeTGZ "$COCOA_TEXT"
mv "$COCOA_TEXT.tgz" "$REL_NAME.tgz"

shasum -a 256 -b "$REL_NAME.tgz"  >  "$REL_NAME.SHA"
echo "...done"

#------------------------------------------------------------
echo " --======-- suggest-sftp --======--"
echo "sftp storage1.dima.unige.it"
suggest-sftp $REL_NAME tgz
echo "exit"
echo "touch $WEBSITE/download/download5.shtml"
echo " --======-- end --======--"

# echo " --======-- CoCoA for linux 32/64 --======-- --REMEMBER! --"
