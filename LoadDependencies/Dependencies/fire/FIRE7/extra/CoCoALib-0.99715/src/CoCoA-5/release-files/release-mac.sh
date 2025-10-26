#!/bin/bash
#  choose one: --> with 0 or 1 arg, second arg must be CoCoALib dir
#  src/CoCoA-5/release-files/release-mac.sh .
#  release-files/release-mac.sh ../..
#  cd release-files/; release-mac.sh
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
# Check that cocoa5-mac is up-to-date.
if [ "$COCOALIBDIRWithCVS/src/CoCoA-5/cocoa5"  -nt  "$COCOALIBDIRWithCVS/src/CoCoA-5/release-files/cocoa5-mac" ]
then
    echo "ERROR: cocoa5-mac is older than src/CoCoA-5/cocoa5 script"  > /dev/stderr
    exit 1;
fi


#--------------------------------------
source "$COCOALIBDIRWithCVS/src/CoCoA-5/release-files/release-common.sh"

#--------------------------------------
# names for release directories
COCOA_TEXT=CoCoA-$VER
#COCOA_GUI=MacCoCoA-$VER.app

FULLPATH_RELEASE_TEXT_DIR=$RELEASE_DIR/$COCOA_TEXT
#FULLPATH_RELEASE_GUI_DIR=$RELEASE_DIR/$COCOA_GUI

set-mac-icon()
{
    SetFile -a C $2
    DeRez -only icns $1 > MyIcon.rsrc
    if [ -f $2 ]; then    # Destination is a file
	Rez -append MyIcon.rsrc -o $2
	SetFile -a C $2
    elif [ -d $2 ]; then
    # Create the magical Icon\r file
	touch $2/$'Icon\r'
	Rez -append MyIcon.rsrc -o $2/Icon?
	SetFile -a V $2/Icon?
    fi
    rm MyIcon.rsrc
    osascript -e "tell application \"Finder\" to set label index of alias POSIX file \"$2\" to 1"
#    osascript -e "tell application \"Finder\" to set label index of alias POSIX file \"`cd -P -- "$(dirname -- "$2")" && printf '%s\n' "$(pwd -P)/$(basename -- "$2")"`\" to 1"
}

#------------------------------------------------------------
cd $RELEASE_DIR/   # <------------ always assume we are here
#------------------------------------------------------------

check-file "$RELEASE_DIR/../CoCoAInterpreter"

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
#echo "   $FULLPATH_RELEASE_GUI_DIR"
echo " --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--"
#make -j3 library; make -j3

#------------------------------------------------------------
rename-existing-release "$FULLPATH_RELEASE_TEXT_DIR"
#rename-existing-release "$FULLPATH_RELEASE_GUI_DIR"

#------------------------------------------------------------
# echo " --======-- GUI MacCoCoA --======--"
# /bin/cp -R ../C5.app/ $FULLPATH_RELEASE_GUI_DIR # all done by make-gui-finish.sh
# set-mac-icon icons/cocoa-icon.txt $FULLPATH_RELEASE_GUI_DIR
# MakeTGZ "$COCOA_GUI" "gui-mac"
# echo "...done"

#------------------------------------------------------------
echo " --======-- text CoCoA for Mac --======--"
mkdir -p $FULLPATH_RELEASE_TEXT_DIR
copy-packages    $FULLPATH_RELEASE_TEXT_DIR
copy-CoCoAManual $FULLPATH_RELEASE_TEXT_DIR
copy-emacs       $FULLPATH_RELEASE_TEXT_DIR

mkdir -p $FULLPATH_RELEASE_TEXT_DIR/bin
/bin/cp ../CoCoAInterpreter $FULLPATH_RELEASE_TEXT_DIR/bin/.
/bin/cp cocoa5-mac  $FULLPATH_RELEASE_TEXT_DIR/cocoa5
/bin/cp ConfigEmacs-mac.command  $FULLPATH_RELEASE_TEXT_DIR/emacs/ConfigEmacs.command
chmod +x  $FULLPATH_RELEASE_TEXT_DIR/cocoa5
chmod +x  $FULLPATH_RELEASE_TEXT_DIR/emacs/ConfigEmacs.command
#--------------- Mac icons --------------------
set-mac-icon icons/cocoa-dir-icon.txt $FULLPATH_RELEASE_TEXT_DIR
set-mac-icon icons/cocoa-icon.txt $FULLPATH_RELEASE_TEXT_DIR/cocoa5
osascript -e "tell application \"Finder\" to set label index of alias POSIX file \"$FULLPATH_RELEASE_TEXT_DIR/emacs\" to 5"
osascript -e "tell application \"Finder\" to set label index of alias POSIX file \"$FULLPATH_RELEASE_TEXT_DIR/emacs/ConfigEmacs.command\" to 5"
#--------------- Mac icons - end --------------
find $FULLPATH_RELEASE_TEXT_DIR -type f -perm +022 -print > /tmp/cocoa-release-check
if [ -s /tmp/cocoa-release-check ]; then echo "SOME FILES WRITABLE:"; cat /tmp/cocoa-release-check; exit 1; fi
/bin/rm /tmp/cocoa-release-check

REL_NAME=`MakeRelName text-mac`
echo "release file is $REL_NAME.tgz"

MakeTGZ "$COCOA_TEXT"
mv "$COCOA_TEXT.tgz" "$REL_NAME.tgz"

shasum -a 256 -b "$REL_NAME.tgz"  >  "$REL_NAME.SHA"
echo "...done"

# #------------------------------------------------------------
# echo " --======-- text CoCoA for Mac 10.5 --======--"
# echo "COPY CoCoAInterpreter to release directory and compress:"
# echo " -cp /Applications/CoCoA-5.1.0-mac10.5/CoCoAInterpreter $FULLPATH_RELEASE_TEXT_DIR/bin"
# echo " -cd $FULLPATH_RELEASE_TEXT_DIR/..; tar -czf $COCOA_TEXT-text-mac10.5.tgz $COCOA_TEXT;"

#------------------------------------------------------------
echo " --======-- suggest-sftp --======--"
echo "sftp -oHostKeyAlgorithms=+ssh-dss storage1.dima.unige.it"
suggest-sftp $REL_NAME tgz
#suggest-sftp $FULLPATH_RELEASE_GUI_DIR  "gui-mac" tgz
echo "exit"
echo "touch /Volumes/$WEBSITE/download/download5.shtml"
echo " --======-- end --======--"
