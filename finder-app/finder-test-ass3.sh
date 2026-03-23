#!/bin/sh
# Tester script for assignment 1 and assignment 2
# Author: Siddhant Jajoo

set -eu

NUMFILES=10
WRITESTR=AELD_IS_FUN
WRITEDIR=/tmp/aeld-data
username=$(cat conf/username.txt)

if [ $# -lt 3 ]
then
	echo "Using default value ${WRITESTR} for string to write"
	if [ $# -lt 1 ]
	then
		echo "Using default value ${NUMFILES} for number of files to write"
	else
		NUMFILES=$1
	fi	
else
	NUMFILES=$1
	WRITESTR=$2
	WRITEDIR=/tmp/aeld-data/$3
fi

MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Writing ${NUMFILES} files containing string ${WRITESTR} to ${WRITEDIR}"

rm -rf "${WRITEDIR}"

# create $WRITEDIR if not assignment1
assignment=`cat conf/assignment.txt`

if [ $assignment != 'assignment1' ]
then
	mkdir -p "$WRITEDIR"

	#The WRITEDIR is in quotes because if the directory path consists of spaces, then variable substitution will consider it as multiple argument.
	#The quotes signify that the entire string in WRITEDIR is a single string.
	#This issue can also be resolved by using double square brackets i.e [[ ]] instead of using quotes.
	if [ -d "$WRITEDIR" ]
	then
		echo "$WRITEDIR created"
	else
		exit 1
	fi
fi

echo "Removing the old writer utility and compiling as a native application"
#make clean
#make

# Execute writer
for i in $( seq 1 $NUMFILES)
do
	./writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

# Test that NUMFILES files exist
COUNT=$(ls "$WRITEDIR" | wc -l)

if [ "$COUNT" -ne "$NUMFILES" ]; then
    echo "Failed: expected $NUMFILES but found $COUNT in $WRITEDIR"
    exit 1
fi

# Test all files content
for FILE in "$WRITEDIR"/*; do
    CONTENT=$(cat "$FILE")

    if [ "$CONTENT" != "$WRITESTR" ]; then
        echo "Failed: wrong content in $FILE"
        exit 1
    fi
done

echo "Successfully created $NUMFILES files with $WRITESTR string."
