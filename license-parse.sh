#!/bin/bash

# we add a prefix to each of the output files (to group them together)
PREFNAME="LICPARSE"

# clear the output files
rm -rf ${PREFNAME}.1.files
rm -rf ${PREFNAME}.2.*
rm -rf ${PREFNAME}.3.*
rm -rf ${PREFNAME}.4.*

# generate a list of files found in this repo
# get all files, and then we then remove some below
find . -name "*" -type f >> ${PREFNAME}.1.files

# now sort the list
sort ${PREFNAME}.1.files > ${PREFNAME}.2.sorted

# and remove some files/directories
#
# we will remove/ignore all files in the following subdirs:
IGN_PATHS="^./.git/\|^./ipcore_dir/\|^./src/_unused/\|^./src/_unused2/\|^./KickAss/\|./isework/"
#
cat ${PREFNAME}.2.sorted | grep -v $IGN_PATHS > ${PREFNAME}.3.trimmed
#
echo "Removed the following"
diff ${PREFNAME}.2.sorted ${PREFNAME}.3.trimmed


# output file #3 contains URLs of files to process

# we will process each file listed in the file-#3
#
# processing performs the following:
# - check see if the file extension is something that we know about
# - thats it for now
#
KNOWN_TXT_EXTNS="vhd vhdl c h md asm a65 sh inc txt cfg ucf xise xdc tcl"
KNOWN_BIN_EXTNS="pdf jpg jpeg prg png hex gif bin dat"
KNOWN_SCR_EXTNS="Makefile makerom makeslowram test_fdisk watch-m65 vivado_wrapper run_ise record-m65"
#
cat ${PREFNAME}.3.trimmed | while read thisfile; do
  #
  # find the extn of this file
  #
  thisbasename=$(basename -- "$thisfile")
  thisextension="${thisbasename##*.}"
  thisfilename="${thisbasename%.*}"
  #
  # check if this file has a known GOOD extension
  #
  if   [[ "$KNOWN_TXT_EXTNS" =~ $thisextension ]]; then
    #echo "YES, is a TXT, will need to check if a LICENCEHEADER already exists"
    echo $thisfile >> ${PREFNAME}.4.txt
    :
  elif [[ "$KNOWN_BIN_EXTNS" =~ $thisextension ]]; then
    #echo "YES, is a BIN, but need to simply create a file with filename.license containing the LICENCEHEADER instead"
    echo $thisfile >> ${PREFNAME}.4.bin
    :
  elif [[ "$KNOWN_SCR_EXTNS" =~ $thisextension ]]; then
    #echo "YES, is a SCR, but need to insert LICENCEHEADER after the hashbang"
    echo $thisfile >> ${PREFNAME}.4.scr
    :
  else
    echo "WARNING - this is a file we dont know what to do with, and we will NOT process it"
    echo "${thisfile} basename=$thisbasename extension=$thisextension filename=$thisfilename"
    echo " "
    echo $thisfile >> ${PREFNAME}.4.unknown
  fi
  #
done;

###################################################
###################################################
# At this stage, we have got a list(s) of files to process
###################################################
###################################################

if [ 1 == 1 ]; then
  echo "Processing the TXT's: ${KNOWN_TXT_EXTNS}"
  #
  cat ${PREFNAME}.4.txt | while read thisfile; do
    echo "$thisfile"
  done
  echo " "
fi

###################################################
###################################################
###################################################
###################################################

if [ 1 == 1 ]; then
  #
  echo "Processing the BIN's: ${KNOWN_BIN_EXTNS}"
  #
  cat ${PREFNAME}.4.bin | while read thisfile; do
    echo "$thisfile"
  done
  echo " "
fi

###################################################
###################################################
###################################################
###################################################

if [ 1 == 1 ]; then
  echo "Processing the SCR's: ${KNOWN_SCR_EXTNS}"
  #
  cat ${PREFNAME}.4.scr | while read thisfile; do
    echo "$thisfile"
  done
  echo " "
fi

###################################################
###################################################
###################################################
###################################################
