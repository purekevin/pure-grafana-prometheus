#/bin/sh

I=1
MOUNTPOINTS=""

for I in `df|grep 10.21.225.38|awk '{print $6}'`
do
        MOUNTPOINTS="$I $MOUNTPOINTS"
done

echo
echo

echo "These are the filesystems mounted and the space used in each:"
echo "-----------------------------------------------------------------------"

for MOUNTPOINT in $MOUNTPOINTS
do
        /usr/local/bin/pdu -sh $MOUNTPOINT 
done

echo
echo  "Select filesystem you want to add data to:"

I=1
for FS in $MOUNTPOINTS
do
        echo "     $I - $FS"
        I=`expr $I + 1`
done
printf "Enter number of the filesystem/mountpoint: "
read ANSWER

I=1

for FS in $MOUNTPOINTS
do
        if [ "$ANSWER" = "$I" ]
        then
                TARGET_DIR=$FS
                break
        fi
        I=`expr $I + 1`
done
echo
echo
printf "Enter number of files to make in ${TARGET_DIR}? "
read NUM_FILES

echo
printf "Enter size of files to make in ${TARGET_DIR}? (MB) "
read FILE_SIZE

echo
echo

printf "Generate $NUM_FILES $FILE_SIZE MB new files in ${TARGET_DIR}?\n"
printf "<CR> to continue, <CNTL-C>"
read FOO

echo
echo

printf "Creating files..."

CNT=1
while [ "$CNT" != "$NUM_FILES" ]
do
	fallocate -x -v -l ${FILE_SIZE}m /$TARGET_DIR/full_file.${CNT}.$$
        CNT=`expr $CNT + 1`
	printf "."
done
printf "..Done!\n"
echo "Complete - created $NUM_FILES $FILE_SIZE MB new files in $TARGET_DIR"
echo
echo
