#!/bin/sh

MOUNTPOINTS=""

for I in `df|grep 10.21.225.38|awk '{print $6}'`
do
        MOUNTPOINTS="$I $MOUNTPOINTS"
done

/usr/local/bin/pdu -s  $MOUNTPOINTS | sed -ne 's/^\([0-9]\+\)\t\(.*\)$/node_directory_size_bytes{directory="\2"} \1/p' >> /root/pdu.prom.$$

for MOUNTPOINT in $MOUNTPOINTS
do
        NUM_FILES=`/usr/local/bin/pfind $MOUNTPOINT -type f | wc -l`
        echo "node_FB_file_count{directory=\"$MOUNTPOINT\"} $NUM_FILES" >>/root/pfind.prom.$$
done

mv /root/pdu.prom.$$ /var/lib/prometheus/logcollect/pdu.prom
mv /root/pfind.prom.$$ /var/lib/prometheus/logcollect/pfind.prom
