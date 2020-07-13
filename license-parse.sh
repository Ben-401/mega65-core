#!/bin/bash

# This script is intended to automate the implementation of the REUSE specification
# to the files in the mega65-core repo,

# we add a prefix to each of the output files (to group them together)
PREFNAME="LICPARSE"

# clear the output files
rm -rf ${PREFNAME}.1.files
rm -rf ${PREFNAME}.2.*
rm -rf ${PREFNAME}.3.*
rm -rf ${PREFNAME}.4.*

# generate a list of files found in this repo
# get all files, and then we then remove some below
find . -name "*" -type f > ${PREFNAME}.1.files

# now sort the list
sort ${PREFNAME}.1.files > ${PREFNAME}.2.sorted

# and remove some files/directories
#
# we will remove/ignore all files in the following locations:
#
# ./.git/ - as we dont have source files here
# ./ipcore_dir/ - lots of junk in here we dont want to mess with
# ./src/_unused*/ - these should be deleted from the repo ??
# ./KickAss/ - unsure who has copyright/license for these files
# ./isework/ - dont think these files are used anymore
# ./license-parse* - the files making up *this* script
# ./${PREFNAME}* - the temp files created by *this* script
#
IGN_PATHS="^./.git/\|^./ipcore_dir/\|^./src/_unused/\|^./src/_unused2/\|^./KickAss/\|./isework/\|license-parse\|${PREFNAME}"
#
cat ${PREFNAME}.2.sorted | grep -v $IGN_PATHS > ${PREFNAME}.3.trimmed
#
# DEBUG
#echo "Removed the following"
#diff ${PREFNAME}.2.sorted ${PREFNAME}.3.trimmed


# output file-#3 contains URLs of files to process

# we will process each file listed in the file-#3
#
# processing performs the following:
# - check see if the file extension is something that we know about
# - if we DO   know the file extn, save the URL in an output file for later processing,
# - if we DONT know the file extn, save the URL in a different output file, to be reported at the end of this script.
#
KNOWN_TXT_EXTNS="vhd vhdl c h md asm a65 sh inc txt cfg ucf xise xdc tcl"
KNOWN_BIN_EXTNS="pdf jpg jpeg prg png hex gif bin dat"
KNOWN_SCR_EXTNS="Makefile makerom makeslowram test_fdisk watch-m65 vivado_wrapper run_ise record-m65 vivado_timing"
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
    #echo "YES, is a TXT, will need to check if a LICENSEHEADER already exists"
    echo $thisfile >> ${PREFNAME}.4.txt
    :
  elif [[ "$KNOWN_BIN_EXTNS" =~ $thisextension ]]; then
    #echo "YES, is a BIN, but need to simply create a file with filename.license containing the LICENSEHEADER instead"
    echo $thisfile >> ${PREFNAME}.4.bin
    :
  elif [[ "$KNOWN_SCR_EXTNS" =~ $thisextension ]]; then
    #echo "YES, is a SCR, but need to insert LICENSEHEADER after the hashbang (if HASHBANG exists)"
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
# At this stage, we have got a list(s) of files to process (ie file.4.* )
###################################################
###################################################

if [ 0 == 1 ]; then
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
    echo -e "\n==== Processing: $thisfile"
    #
    echo "We will create  \"${thisfile}.license\" containing the LICENSE info"

    # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to BIN-files)
    # we could use just plain text, but will use HASH prepended to each line as in the SCRs)
    #
    LICENSEHEADER_BIN="#\n# SPDX-FileCopyrightText: 2020 MEGA\n#\n# Contributors:"
    LICENSEFOOTER_BIN="#\n# SPDX-License-Identifier: LGPL-3.0-or-later\n#"
    #
    # DEBUG
    #echo -e   $LICENSEHEADER_BIN
    #echo "==^^ LICENSEHEADER_BIN"
    #echo -e   $LICENSEFOOTER_BIN
    #echo "==^^ LICENSEFOOTER_BIN"


    # get a list of the contributors
    #
    # 1. get a complete git-log of the file, use '--follow' to continue listing history beyond file-renames (git)
    # 2. pull out the string "Author:..." of each commit (grep)
    # 3. normalise the list where an author has multiple names and/or email addresses (sed)
    # 4. de-duplicate the names by leaving only unique entries (awk)
    CONTRIBUTORS=`git log --follow "$thisfile" | grep Author | sed -f ./license-parse-norm.dat | awk '!a[$0]++' `
    #
    # DEBUG
    echo "git log --follow  <filename> | grep Author"
    git       log --follow "$thisfile" | grep Author
    #echo "and the processed:"
    #echo "$CONTRIBUTORS"
    #echo "==^^CONTRIBUTORS"
    #
    # write out a temporary file, as I cant get SED to parse VARIABLES
    #
    echo -e "$CONTRIBUTORS" > "${thisfile}.temp.contrib"
    #
    # now, remove the leading "Author:   " in each entry, and align as appropriate
    sed -i 's/Author: /#   /g' "${thisfile}.temp.contrib"
    #

    # now join the LICENSEHEADER, CONTRIBUTORS-file, and LICENSEFOOTER
    echo -e $LICENSEHEADER_BIN     >  "${thisfile}.license" # yes, overwrite if it exists
    cat "${thisfile}.temp.contrib" >> "${thisfile}.license"
    echo -e $LICENSEFOOTER_BIN     >> "${thisfile}.license"

    # show the new file, and add it to git
    echo "===="
    cat "${thisfile}.license"
    echo "==^^ new file addded"
    #
    git add "${thisfile}.license"

    # remove temporary files
    rm "${thisfile}.temp.contrib"
    #rm "${thisfile}.license"

  done
  echo " "
fi

###################################################
###################################################
###################################################
###################################################

if [ 0 == 1 ]; then
  echo "Processing the SCR's: ${KNOWN_SCR_EXTNS}"
  #
  # For the SCRipt files, we add the LICENSEHEADER to the top of the file,
  # but below the hashbang (if it exists)
  #
  cat ${PREFNAME}.4.scr | while read thisfile; do
    echo -e "\n==== Processing: $thisfile"
    #
    # check for hashbang, as we want the header to go BELOW the first line
    #
    FIRSTLINE=`head -n 1 $thisfile`
    #
    if [[ "$FIRSTLINE" =~ ^#! ]] ; then
      echo "detected hashbang, firstline=\"${FIRSTLINE}\""
      HASHBANG="Y"
    else
      echo "no hashbang"
      HASHBANG="N"
    fi
    #
    # DEBUG
    #head $thisfile
    #
    echo "===="

    # for scripts with hashbang, keep the first line
    # then add LICENSEHEADER
    if [[ $HASHBANG == "Y" ]] ; then
      #
      echo $FIRSTLINE > ${thisfile}.temp
    fi

    # construct the LICENSEHEADER template (specific to SCR-files, ie use HASH for comment)
    #
    LICENSEHEADER_SCR="#\n# SPDX-FileCopyrightText: 2020 MEGA\n#\n# Contributors:\n# __CONTRIBUTORS__\n#\n# SPDX-License-Identifier: LGPL-3.0-or-later\n#"
    #
    # DEBUG
    #echo   -e $LICENSEHEADER_SCR
    #echo "==^^ LICENSEHEADER_SCR"
    #
    # write out a temporary file
    #
    echo -e $LICENSEHEADER_SCR > ${thisfile}.temp.header



    # get a list of the contributors
    #
    # 1. get a complete git-log of the file, use '--follow' to continue listing history beyond file-renames (git)
    # 2. pull out the string "Author:..." of each commit (grep)
    # 3. normalise the list where an author has multiple names and/or email addresses (sed)
    # 4. de-duplicate the names by leaving only unique entries (awk)
    CONTRIBUTORS=`git log --follow "$thisfile" | grep Author | sed -f ./license-parse-norm.dat | awk '!a[$0]++' `
    #
    # DEBUG
    echo "git log --follow  <filename> | grep Author"
    git       log --follow "$thisfile" | grep Author
    #echo "and the processed:"
    #echo "$CONTRIBUTORS"
    #echo "==^^CONTRIBUTORS"
    #
    # write out a temporary file, as I cant get SED to parse VARIABLES
    #
    echo -e "$CONTRIBUTORS" > "${thisfile}.temp.contrib"
    #
    # now, remove the leading "Author:   " in each entry, and align as appropriate
    sed -i 's/Author: /#   /g' "${thisfile}.temp.contrib"
    #

    # now join the LICENSEHEADER with the CONTRIBUTORS
    # 1. top of LICENSEHEADER downto "__CONTRIBUTORS__"
    # 2. contents of CONTRIBUTORS
    # 3. botton of LICENSEHEADER starting after "__CONTRIBUTORS__"
    #
    # 1: "grep -B" says 9999 lines BEFORE the matched text (ie the top of the file downto match)
    #    "head -1" removes the matched line
    cat ${thisfile}.temp.header | grep -B 9999 "__CONTRIBUTORS__" | head -n -1 >> ${thisfile}.temp
    # 2: all of the contributors
    cat ${thisfile}.temp.contrib >> ${thisfile}.temp
    # 3: "grep -A" says 9999 lines AFTER the matched text (ie the bottom of the file upto match)
    #    "tail -1" removes the matched line
    cat ${thisfile}.temp.header | grep -A 9999 "__CONTRIBUTORS__" | tail -n +2 >> ${thisfile}.temp

    # show the newly added text
    echo "===="
    cat ${thisfile}.temp
    echo "==^^ added text to the top of the file"

    # now place the rest of the contents of the original file into this temp-file
    #
    # for the SCR-files with HASHBANG, we have already put in the first line, so just lines 2-onwards
    if [[ $HASHBANG == "Y" ]] ; then
      cat ${thisfile} | tail -n +2 >> ${thisfile}.temp
    else
      cat ${thisfile}              >> ${thisfile}.temp
    fi

    # and now replace the original file with the temp file
    mv ${thisfile}.temp ${thisfile}
    #rm ${thisfile}.temp

    # remove temporary files
    rm ${thisfile}.temp.header
    rm ${thisfile}.temp.contrib

  done
  echo " "


fi

###################################################
###################################################
###################################################
###################################################

# show a warning of the files that were not processed
#
echo "The following files were NOT procesed:"
cat ${PREFNAME}.4.unknown
