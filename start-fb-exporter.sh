#!/bin/sh

FB_IP_ADDR=$1

if [ "$FB_IP_ADDR" = "" ]
then
        FB_IP_ADDR="10.21.225.35"
fi

TOKEN=`sshpass -p pureuser ssh -o "StrictHostKeyChecking no" pureuser@${FB_IP_ADDR} pureadmin list --api-token --expose|grep pureuser | awk  '{FS=":"; gsub(/\r$/,"",$2); print $2}'`

export PUREFB_API=$TOKEN
nohup /usr/local/bin/prometheus-flashblade-exporter --insecure --filesystem-metrics $FB_IP_ADDR & >/tmp/prometheus-flashblade-exporter  2>&1