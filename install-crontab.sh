#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

printf "${GREEN}-----------------  Installing crontab ------------------------${NC}\n"
wget -q https://raw.githubusercontent.com/purekevin/dashboard/master/crontab
wget -q https://raw.githubusercontent.com/purekevin/dashboard/master/rft.sh
chmod 755 rft.sh
mv rft.sh /var/lib/prometheus/logcollect/
crontab -l >crontab.tmp
cat crontab >>crontab.tmp
crontab crontab.tmp
crontab -l
echo
echo
