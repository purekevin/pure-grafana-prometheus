#/bin/sh

I=1
MOUNTPOINTS=""

for I in `df|grep 10.21.225.38|awk '{print $6}'`
do
        MOUNTPOINTS="$I $MOUNTPOINTS"
done

echo
echo

echo "These are the filesystems mounted and the number of files in each:"
echo "-----------------------------------------------------------------------"

for MOUNTPOINT in $MOUNTPOINTS
do
        NUM_FILES=`/usr/local/bin/pfind $MOUNTPOINT -type f | wc -l`
        echo "$MOUNTPOINT - $NUM_FILES files"
done

echo
echo  "Select filesystem you where want to make more files:"

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

printf "Generate $NUM_FILES new files in ${TARGET_DIR}?\n"
printf "<CR> to continue, <CNTL-C>"
read FOO

echo
echo

CNT=1
while [ "$CNT" != "$NUM_FILES" ]
do
        touch /$TARGET_DIR/file.${CNT}.$$
        CNT=`expr $CNT + 1`
done
echo "Complete - created $NUM_FILES new files in $TARGET_DIR"
echo
echo
