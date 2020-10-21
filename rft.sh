#!/bin/sh

# to filter for files older than $NUMDAYS

NUMDAYS=90
DAYSOLDERTHAN="-amin +$(($NUMDAYS*24*60))"

# Set output temp file names

#PDU_OUT=/tmp/pdu.prom.$$
PFIND_OUT=/tmp/pfind.prom.$$
#AGE_OUT=/tmp/age.prom.$$

#  PDU, PFIND, and AGE section

MOUNTPT_COUNT=0
SUM_SUBDIR_SIZE=0
SUM_SUBDIR_COUNT=0
SUM_SUBDIR_AGED_SIZE=0
SUM_SUBDIR_AGED_COUNT=0
MOUNTPTS=$(mount | grep "type nfs " | awk '{print $1,$3}' | tr ':' ' ' | awk '{print $1,$3,$2}' | rev | sort | rev | uniq -f 2 | awk '{print $2}')
#for MOUNTPT in $(mount | grep 'type nfs ' | awk '{print $3}'); do
for MOUNTPT in $MOUNTPTS; do
    MOUNTPT_COUNT=$(($MOUNTPT_COUNT + 1))
    echo "----------------------------------------------------"
    echo "Processing mount point $MOUNTPT_COUNT: \"$MOUNTPT\""
    echo "----------------------------------------------------"

    for DIR in "$MOUNTPT"/* ; do
      # file count by subdirectory
      #NUM_FILES=`/usr/local/bin/pfind "$DIR" -type f | wc -l`
      #echo "node_FB_file_count{directory=\"$DIR\"} $NUM_FILES" >> $PFIND_OUT
      #echo "Total directory file count of: $DIR $NUM_FILES"

      # total file count and capacity by subdirectory
      SUBDIR_SIZE_COUNT=`/usr/local/bin/pfind "$DIR" -print0 -ls | awk 'BEGIN {sum=0;count=0}{sum+=$5;count++;} END {print sum,count}'`
      SUBDIR_SIZE=$(echo "$SUBDIR_SIZE_COUNT" | awk '{print $1}')
      SUBDIR_COUNT=$(echo "$SUBDIR_SIZE_COUNT" | awk '{print $2}')
      SUM_SUBDIR_SIZE=$(($SUM_SUBDIR_SIZE + $SUBDIR_SIZE))
      SUM_SUBDIR_COUNT=$(($SUM_SUBDIR_COUNT + $SUBDIR_COUNT))
      echo "node_FB_directory_size_kb{directory=\"$DIR\"} $SUBDIR_SIZE" >> $PFIND_OUT
      echo "node_FB_file_count{directory=\"$DIR\"} $SUBDIR_COUNT" >> $PFIND_OUT
      echo "Total directory size of $DIR $SUBDIR_SIZE"
      echo "Total file count of $DIR $SUBDIR_COUNT"

      # aged file count and capacity by subdirectory for files older than specified no. of days
      SUBDIR_AGED_SIZE_COUNT=`/usr/local/bin/pfind "$DIR" $DAYSOLDERTHAN -print0 -ls | awk 'BEGIN {sum=0;count=0}{sum+=$5;count++;} END {print sum,count}'`
      SUBDIR_AGED_SIZE=$(echo "$SUBDIR_AGED_SIZE_COUNT" | awk '{print $1}')
      SUBDIR_AGED_COUNT=$(echo "$SUBDIR_AGED_SIZE_COUNT" | awk '{print $2}')
      SUM_SUBDIR_AGED_SIZE=$(($SUM_SUBDIR_AGED_SIZE + $SUBDIR_AGED_SIZE))
      SUM_SUBDIR_AGED_COUNT=$(($SUM_SUBDIR_AGED_COUNT + $SUBDIR_AGED_COUNT))
      echo "node_FB_directory_aged_size_kb{directory=\"$DIR\"} $SUBDIR_AGED_SIZE" >> $PFIND_OUT
      echo "node_FB_file_aged_count{directory=\"$DIR\"} $SUBDIR_AGED_COUNT" >> $PFIND_OUT
      echo "Aged directory size of $DIR $SUBDIR_AGED_SIZE"
      echo "Aged file count of $DIR $SUBDIR_AGED_COUNT"
    done


    echo "Calculating total capacity usage of mount point $MOUNTPT..."

    echo "node_FB_directory_size_kb{directory=\"$MOUNTPT\"} $SUM_SUBDIR_SIZE" >> $PFIND_OUT
    echo "node_FB_file_count{directory=\"$MOUNTPT\"} $SUM_SUBDIR_COUNT" >> $PFIND_OUT
    echo "Total mount point size of $MOUNTPT $SUM_SUBDIR_SIZE"
    echo "Total mount point file count of $MOUNTPT $SUM_SUBDIR_COUNT"

    echo "node_FB_directory_aged_size_kb{directory=\"$MOUNTPT\"} $SUM_SUBDIR_AGED_SIZE" >> $PFIND_OUT
    echo "node_FB_file_aged_count{directory=\"$MOUNTPT\"} $SUM_SUBDIR_AGED_COUNT" >> $PFIND_OUT
    echo "Aged directory size of $MOUNTPT $SUM_SUBDIR_AGED_SIZE"
    echo "Aged file count of $MOUNTPT $SUM_SUBDIR_AGED_COUNT"
 
#    MOUNTPT_SIZE=$(/usr/local/bin/pdu -s "$MOUNTPT")
#    echo $MOUNTPT_SIZE | sed -ne 's/^\([0-9]\+\)\t\(.*\)$/node_directory_size_bytes{directory="\2"} \1/p' >> $PDU_OUT
#    echo "Capacity Usage of: $MOUNTPT $MOUNTPT_SIZE"

#    echo "Calculating capacity usage of subdirs in $MOUNTPT..."
#    /usr/local/bin/pdu -s "$MOUNTPT"/* | sed -ne 's/^\([0-9]\+\)\t\(.*\)$/node_directory_size_bytes{directory="\2"} \1/p' >> $PDU_OUT

done

if [[ $MOUNTPT_COUNT -eq 0 ]]; then
  echo "No mount points found"
  exit 1
fi

# mv $PDU_OUT /var/lib/prometheus/rftlogs/pdu.prom
mv $PFIND_OUT /var/lib/prometheus/rftlogs/pfind.prom
# mv $AGE_OUT /var/lib/prometheus/rftlogs/age.prom

