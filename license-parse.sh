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
rm -rf ${PREFNAME}.5.*

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
#
# ./license-parse* - the files making up *this* script
# ./${PREFNAME}* - the temp files created by *this* script
# ./LICENSES/ - we dont license a license
#
IGN_PATHS="^./.git/\|^./ipcore_dir/\|^./src/_unused/\|^./src/_unused2/\|^./KickAss/\|./isework/\|license-parse\|${PREFNAME}\|./LICENSES/"
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
# NOTE that for the file extn's that we DO know about,
# we will coursely grade them into sub categories for later processing.
#
KNOWN_TXT_EXTNS=" vhd vhdl c h v vh asm a65 inc s "
KNOWN_BIN_EXTNS=" pdf jpg jpeg prg png hex gif bin dat md "
KNOWN_SCR_EXTNS=" sh Makefile makerom makeslowram test_fdisk watch-m65 vivado_wrapper run_ise record-m65 vivado_timing xdc tcl "
#
cat ${PREFNAME}.3.trimmed | while read thisfile; do
  #
  # find the extn of this file
  #
  thisbasename=$(basename -- "${thisfile}")
  thisextension="${thisbasename##*.}"
  thisfilename="${thisbasename%.*}"
  #
  # check if this file has a known GOOD extension
  #
  if   [[ "$KNOWN_TXT_EXTNS" =~ " ${thisextension} " ]]; then
    #echo "YES, is a TXT, will need to check if a LICENSEHEADER already exists"
    echo "${thisfile}" >> ${PREFNAME}.4.txt
    :
  elif [[ "$KNOWN_BIN_EXTNS" =~ " ${thisextension} " ]]; then
    #echo "YES, is a BIN, but need to simply create a file with filename.license containing the LICENSEHEADER instead"
    echo "${thisfile}" >> ${PREFNAME}.4.bin
    :
  elif [[ "$KNOWN_SCR_EXTNS" =~ " ${thisextension} " ]]; then
    #echo "YES, is a SCR, but need to insert LICENSEHEADER after the hashbang (if HASHBANG exists)"
    echo "${thisfile}" >> ${PREFNAME}.4.scr
    :
  else
    echo "WARNING - this is a file we dont know what to do with, and we will NOT process it"
    echo "${thisfile} basename=${thisbasename} extension=${thisextension} filename=${thisfilename}"
    echo " "
    echo "${thisfile}" >> ${PREFNAME}.4.unk
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
    echo "${thisfile}"
  done
  echo " "
fi

###################################################
###################################################
###################################################
###################################################

if [ 1 == 1 ]; then #KNOWN_BIN_EXTNS
  #
  echo "Processing the BIN's: ${KNOWN_BIN_EXTNS}"
  #
  cat ${PREFNAME}.4.bin | while read thisfile; do
    #
    echo -e "\n==== Processing: ${thisfile}"
    #
    # For the BIN-files, we add a "filename.license"-file containing the LICENSE info
    #

    # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to BIN-files)
    # we could use just plain text, but will use HASH prepended to each line as in the SCRs)
    #
    LICENSEHEADER_BIN="#\n# SPDX-FileCopyrightText: 2020 MEGA\n#\n# Contributors:"
    LICENSEFOOTER_BIN="#\n# SPDX-License-Identifier: LGPL-3.0-or-later\n#"
    #

    # check if the file already has some kind of license/copyright
    if [[ "$(grep -i 'copyright\|licence' ${thisfile} | wc -l)" -ne "0" ]]; then
      echo    "${thisfile} has some kind of existing copyright/license"
      echo "${thisfile}" >> ${PREFNAME}.5.hasCopyLic
    fi
    #

    # get a list of the contributors
    #
    # 1. get a complete git-log of the file, use '--follow' to continue listing history beyond file-renames (git)
    # 2. pull out the string "Author:..." of each commit (grep)
    # 3. normalise the list where an author has multiple names and/or email addresses (sed)
    # 4. de-duplicate the names by leaving only unique entries (awk)
    CONTRIBUTORS=`git log --follow "${thisfile}" | grep Author | sed -f ./license-parse-norm.dat | awk '!a[$0]++' `
    #
    # DEBUG
    echo "git log --follow  <filename>   | grep Author"
    git       log --follow "${thisfile}" | grep Author
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

    # add it to git
    git add "${thisfile}.license"

    # show the newly added text
    echo "===="
    git diff --cached "${thisfile}.license"

    # remove temporary files
    rm "${thisfile}.temp.contrib"

    git reset "${thisfile}.license"
    rm -f     "${thisfile}.license"

    echo "==== File done."
    #
  done

  echo " "
  #
fi #KNOWN_BIN_EXTNS

###################################################
###################################################
###################################################
###################################################

if [ 1 == 1 ]; then #KNOWN_SCR_EXTNS
  #
  echo "Processing the SCR's: ${KNOWN_SCR_EXTNS}"
  #
  # For the SCRipt files, we add the LICENSEHEADER to the top of the file,
  # but below the hashbang (if it exists)
  #
  cat ${PREFNAME}.4.scr | while read thisfile; do
    #
    echo -e "\n==== Processing: ${thisfile}"
    #
    # For the SCR-files, we append the LICENSE-info to the top of the file,
    # but below the HASHBANG (if it exists)

    # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to SCR-files)
    # seems HASH can be used for the comment as files are python/bash/etc
    #
    LICENSEHEADER_SCR="#\n# SPDX-FileCopyrightText: 2020 MEGA\n#\n# Contributors:"
    LICENSEFOOTER_SCR="#\n# SPDX-License-Identifier: LGPL-3.0-or-later\n#\n" # has extra CR

    # check if the file already has some kind of license/copyright
    if [[ "$(grep -i 'copyright\|licence' ${thisfile} | wc -l)" -ne "0" ]]; then
      echo    "${thisfile} has some kind of existing copyright/license"
      echo "${thisfile}" >> ${PREFNAME}.5.hasCopyLic
    fi
    #

    # check for hashbang, as we want the header to go BELOW the first line
    #
    FIRSTLINE=`head -n 1 ${thisfile}`
    #
    if [[ "$FIRSTLINE" =~ ^#! ]] ; then
      echo "detected hashbang, firstline=\"${FIRSTLINE}\""
      HASHBANG="Y"
      echo "$FIRSTLINE" >  "${thisfile}.temp"
      echo ""           >> "${thisfile}.temp" # add a break after the HASHBANG
    else
      echo "no hashbang"
      HASHBANG="N"
      rm -f "${thisfile}.temp"
    fi
    #
    # DEBUG
    #head "${thisfile}"
    #
    echo "===="


    # get a list of the contributors
    #
    # 1. get a complete git-log of the file, use '--follow' to continue listing history beyond file-renames (git)
    # 2. pull out the string "Author:..." of each commit (grep)
    # 3. normalise the list where an author has multiple names and/or email addresses (sed)
    # 4. de-duplicate the names by leaving only unique entries (awk)
    CONTRIBUTORS=`git log --follow "$thisfile" | grep Author | sed -f ./license-parse-norm.dat | awk '!a[$0]++' `
    #
    # DEBUG
    echo "git log --follow  <filename>   | grep Author"
    git       log --follow "${thisfile}" | grep Author
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
    echo -e $LICENSEHEADER_SCR     >> "${thisfile}.temp" # may already contain HASHBANG (if it existed)
    cat "${thisfile}.temp.contrib" >> "${thisfile}.temp"
    echo -e $LICENSEFOOTER_SCR     >> "${thisfile}.temp"
    #
    # and place the rest of the contents of the original file into this temp-file
    if [[ $HASHBANG == "Y" ]] ; then
      # "tail -n +2" processes from line#2 onwards (ie after the HASHBANG)
      cat "${thisfile}" | tail -n +2 >> "${thisfile}.temp"
    else
      cat "${thisfile}"              >> "${thisfile}.temp"
    fi

    # and now replace the original file with the temp file, and add to git
    mv "${thisfile}.temp" "${thisfile}"
    git add "${thisfile}"

    # show the newly added text
    echo "===="
    git diff --cached "${thisfile}"

    # remove temporary files
    rm "${thisfile}.temp.contrib"

    git reset    "${thisfile}"
    git checkout "${thisfile}"

    echo "==== File done."

  done
  #
  echo " "

  #
fi #KNOWN_SCR_EXTNS

echo " "
echo "We have finished processing"

###################################################
###################################################
###################################################
###################################################

# show a warning of the files that were not processed
#
echo "========"
echo "The following files were NOT procesed as their file-extn was NOT known:"
echo "from: ${PREFNAME}.4.unk"
cat        "${PREFNAME}.4.unk"


echo "========"
echo "The following files were NOT procesed as their file-extn was NOT known:"
echo "from: ${PREFNAME}.4.txt.unk"
cat        "${PREFNAME}.4.txt.unk"


echo "========"
echo "WARNING, The following files may have an existing copyright/license."
echo "WARNING, Please check the validity of the MEGA65 copyright/licence before commit"
echo "from: ${PREFNAME}.5.hasCopyLic"
cat        "${PREFNAME}.5.hasCopyLic"


echo ""
echo "The Ende."



