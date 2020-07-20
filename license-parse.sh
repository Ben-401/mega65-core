#!/bin/bash

#
# SPDX-FileCopyrightText: 2020 MEGA
#
# Contributors:
#   Ben-401 <ben.0x0401@gmail.com>
#
# SPDX-License-Identifier: LGPL-3.0-or-later
#

# This script is intended to automate the implementation of the REUSE specification
# (ie by adding copyright and license information)
# to each file in the mega65-core repo.

# Three modes exist, please modify to suit.
# (only one enabled at a time, is best to allow review of results)
#
#LICMODE="TXT"
LICMODE="BIN"
#LICMODE="SCR"



# This script has only one function
#
function FN_processFile {
  #
  echo "1=$1 2=$2 3=$3 4=$4"
  FN_THISFILE=$1
  LICENSEHEADER_XXX="$2"
  LICENSEFOOTER_XXX="$3"
  LICENSECOMMEN_XXX="$4"

  # get a list of the contributors
  #
  # 1. get a complete git-log of the file, use '--follow' to continue listing history beyond file-renames (git)
  # 2. pull out the string "Author:..." of each commit (grep)
  # 3. normalise the list where an author has multiple names and/or email addresses (sed)
  # 4. de-duplicate the names by leaving only unique entries (awk)
  CONTRIBUTORS=`git log --follow "${FN_THISFILE}" | grep Author | sed -f ./license-parse-norm.dat | awk '!a[$0]++' `
  #
  # DEBUG
#  echo "git log --follow  <filename>      | grep Author"
#  git       log --follow "${FN_THISFILE}" | grep Author
  #echo "and the processed:"
  #echo "$CONTRIBUTORS"
  #echo "==^^CONTRIBUTORS"
  #
  # write out a temporary file, as I cant get SED to parse VARIABLES
  #
  echo -e "$CONTRIBUTORS" > "${FN_THISFILE}.temp.contrib"
  #
  # now, remove the leading "Author:   " in each entry, and align as appropriate
  sed -i "s,Author: ,${LICENSECOMMEN_XXX}  ,g" "${FN_THISFILE}.temp.contrib"
  #

  # now join the LICENSEHEADER, CONTRIBUTORS-file, and LICENSEFOOTER
  echo -e ${LICENSEHEADER_XXX}      >  "${FN_THISFILE}.temp" # yes, overwrite if it exists
  cat "${FN_THISFILE}.temp.contrib" >> "${FN_THISFILE}.temp"
  echo -e ${LICENSEFOOTER_XXX}      >> "${FN_THISFILE}.temp"
  #
  # and place the rest of the contents of the original file into this temp-file
  cat "${thisfile}"                 >> "${FN_THISFILE}.temp"

  # and now replace the original file with the temp file, and add to git
  mv "${thisfile}.temp" "${thisfile}"
  git add "${thisfile}"

  # show the newly added text
  echo "===="
  git diff --cached "${thisfile}"

  # remove temporary files
  rm "${thisfile}.temp.contrib"

# remove/comment the lines below after DRYRUN
  git reset    "${thisfile}"
  git checkout "${thisfile}"


  echo "==== File done."

  #
}


# THE MAIN SCRIPT/CODE IS BELOW

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
    #echo "Will also need to consider file-extn to use the correct 'comment'-character(s)"
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

# DEBUG, record some stats and print out at the end of the script
NUMTXT="$(cat ${PREFNAME}.4.txt | wc -l)" && echo "Number of TXT: ${NUMTXT} " >  ${PREFNAME}.6.stats
NUMBIN="$(cat ${PREFNAME}.4.bin | wc -l)" && echo "Number of BIN: ${NUMBIN} " >> ${PREFNAME}.6.stats
NUMSCR="$(cat ${PREFNAME}.4.scr | wc -l)" && echo "Number of SCR: ${NUMSCR} " >> ${PREFNAME}.6.stats
NUMUNK="$(cat ${PREFNAME}.4.unk | wc -l)" && echo "Number of UNK: ${NUMUNK} " >> ${PREFNAME}.6.stats

###################################################
###################################################
# At this stage, we have got a list(s) of files to process (ie file.4.* )
###################################################
###################################################

if [ "${LICMODE}" == "TXT" ]; then #KNOWN_TXT_EXTNS
  #
  echo "Pre-Processing the TXT's: ${KNOWN_TXT_EXTNS}"
  #
  cat ${PREFNAME}.4.txt | while read thisfile; do
    #
    echo -e "\n==== Sorting: ${thisfile}"
    #
    # sort files depending on known extension types
    # this is because different file-extn-types require different comment-chars
    #
    thisbasename=$(basename -- "${thisfile}")
    thisextension="${thisbasename##*.}"
    thisfilename="${thisbasename%.*}"
    #
    # we add a 'space' before & after the extn to ensure a complete match of file-extn
    # else, "vhd" =~ "h" is TRUE(bad), but "vhd " =~ "h " is FALSE(GOOD)
    #
    if   [[ " vhd \| vhdl " =~ " ${thisextension} " ]]; then
      # will use "--" for the comment-block
      echo "${thisfile}" >> ${PREFNAME}.4.txt.dashdash
      :
    elif [[ " c \| h \| v \| vh \| asm " =~ " ${thisextension} " ]]; then
      # will use "//" for the comment-block
      echo "${thisfile}" >> ${PREFNAME}.4.txt.slashslash
      :
    elif [[ " a65 \| inc \| s " =~ " ${thisextension} " ]]; then
      # will use "; " for the comment-block
      echo "${thisfile}" >> ${PREFNAME}.4.txt.semicolonspace
      :
    else
      echo "WARNING - this is a file we dont know what to do with, and we will NOT process it"
      echo "${thisfile} basename=${thisbasename} extension=${thisextension} filename=${thisfilename}"
      echo "${thisfile}" >> ${PREFNAME}.4.txt.unk
    fi
    #
    echo "==== File sorted."

    # check if the file already has some kind of license/copyright
    if [[ "$(grep -i 'copyright\|licence' ${thisfile} | wc -l)" -ne "0" ]]; then
      echo    "${thisfile} has some kind of existing copyright/license"
      echo "${thisfile}" >> ${PREFNAME}.5.hasCopyLic
    fi
    #
  done

  # now continue below and do the actual processing of the sorted files.

  #
  ###################
  ################### txt / dashdash
  ###################
  ###################
  #
  # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to comment-type)
  #
  LICENSEHEADER_TXT_DASH="--\n-- SPDX-FileCopyrightText: 2020 MEGA\n--\n-- Contributors:"
  LICENSEFOOTER_TXT_DASH="--\n-- SPDX-License-Identifier: LGPL-3.0-or-later\n--\n"
  LICENSECOMMEN_TXT_DASH="-- "
  #
  cat ${PREFNAME}.4.txt.dashdash | while read thisfile; do
    echo -e "\n==== Processing dashdash: ${thisfile}"
    FN_processFile "${thisfile}" \
                   "${LICENSEHEADER_TXT_DASH}" \
                   "${LICENSEFOOTER_TXT_DASH}" \
                   "${LICENSECOMMEN_TXT_DASH}"
    #
    echo "===="
  done
  #

  #
  ###################
  ################### txt / slashslash
  ###################
  ###################
  #
  # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to comment-type)
  #
  LICENSEHEADER_TXT_SLASH="//\n// SPDX-FileCopyrightText: 2020 MEGA\n//\n// Contributors:"
  LICENSEFOOTER_TXT_SLASH="//\n// SPDX-License-Identifier: LGPL-3.0-or-later\n//\n"
  LICENSECOMMEN_TXT_SLASH="// "
  #
  cat ${PREFNAME}.4.txt.slashslash | while read thisfile; do
    echo -e "\n==== Processing slashslash: ${thisfile}"
    FN_processFile "${thisfile}" \
                   "${LICENSEHEADER_TXT_SLASH}" \
                   "${LICENSEFOOTER_TXT_SLASH}" \
                   "${LICENSECOMMEN_TXT_SLASH}"
    #
    echo "===="
  done
  #

  #
  ###################
  ################### txt / semicolonspace
  ###################
  ###################
  #
  # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to comment-type)
  #
  LICENSEHEADER_TXT_SEMICOLON=";\n;  SPDX-FileCopyrightText: 2020 MEGA\n;\n;  Contributors:"
  LICENSEFOOTER_TXT_SEMICOLON=";\n;  SPDX-License-Identifier: LGPL-3.0-or-later\n;\n"
  LICENSECOMMEN_TXT_SEMICOLON="; "
  #
  cat ${PREFNAME}.4.txt.semicolonspace | while read thisfile; do
    echo -e "\n==== Processing semicolon: ${thisfile}"
    FN_processFile "${thisfile}" \
                   "${LICENSEHEADER_TXT_SEMICOLON}" \
                   "${LICENSEFOOTER_TXT_SEMICOLON}" \
                   "${LICENSECOMMEN_TXT_SEMICOLON}"
    #
    echo "===="
  done
  #

  #
#
fi #KNOWN_TXT_EXTNS

###################################################
###################################################
###################################################
###################################################

if [ "${LICMODE}" == "BIN" ]; then #KNOWN_BIN_EXTNS
  #
  echo "Processing the BIN's: ${KNOWN_BIN_EXTNS}"
  #
  # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to BIN-files)
  # we could use just plain text, but will use HASH prepended to each line as in the SCRs)
  #
  LICENSEHEADER_BIN="#\n# SPDX-FileCopyrightText: 2020 MEGA\n#\n# Contributors:"
  LICENSEFOOTER_BIN="#\n# SPDX-License-Identifier: LGPL-3.0-or-later\n#"
  #
  cat ${PREFNAME}.4.bin | while read thisfile; do
    #
    echo -e "\n==== Processing: ${thisfile}"
    #
    # For the BIN-files, we add a "filename.license"-file containing the LICENSE info
    #

    # check if the file already has some kind of license/copyright
    # doesnt really make sense on JPGs, but do it anyway for all BINs
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

# remove/comment the lines below after DRYRUN
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

if [ "${LICMODE}" == "SCR" ]; then #KNOWN_SCR_EXTNS
  #
  echo "Processing the SCR's: ${KNOWN_SCR_EXTNS}"
  #
  # For the SCRipt files, we add the LICENSEHEADER to the top of the file,
  # but below the hashbang (if it exists)
  #

  # construct the LICENSEHEADER & LICENSEFOOTER templates (specific to SCR-files)
  # seems HASH can be used for the comment as files are python/bash/etc
  #
  LICENSEHEADER_SCR="#\n# SPDX-FileCopyrightText: 2020 MEGA\n#\n# Contributors:"
  LICENSEFOOTER_SCR="#\n# SPDX-License-Identifier: LGPL-3.0-or-later\n#\n" # has extra CR

  cat ${PREFNAME}.4.scr | while read thisfile; do
    #
    echo -e "\n==== Processing: ${thisfile}"
    #
    # For the SCR-files, we append the LICENSE-info to the top of the file,
    # but below the HASHBANG (if it exists)

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

# remove/comment the lines below after DRYRUN
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


echo "========"
echo "Stats are:"
cat "${PREFNAME}.6.stats"


echo ""
echo "The Ende."




#The following files have no copyright and licensing information:
#* .gitignore1
#* .gitmodules
#* 65xx_and_c64_docs/cpu_internals.txt
#* assets/matrix_banner.txt
#* iomap.txt
#* src/keyboard.txt
#* src/tests/vicii.cfg
#* testprocedure_in.tex
