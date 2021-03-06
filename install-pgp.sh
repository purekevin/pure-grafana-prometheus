#!/bin/bash

INST_DIR=`pwd`
DEFAULT_MANAGEMENT_IP="10.21.225.35"
DEFAULT_NFS_VIP="10.21.225.38"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

printf "${GREEN}-----------------  Collecting IP addresses ... ------------------------${NC}\n"
SUBNET=`netstat -r|grep ^10|awk -F . '{print $1"."$2"."$3}'`
IP_ADDR=`ifconfig | grep $SUBNET | awk '{print $2}'`

echo "Verify the FlashBlade's mangement ip address via the gui:"
echo ' - Go to PureTec, launch the FlashBlade GUI interface by clicking on the block titled "FlashBlade"'
echo ' - Click on "Login" to login as "pureuser"'
echo ' - Click on "Settings" on the left left navigation panel'
echo ' - Click on "Network" on the top menu bar'
echo ' - Search for "Management" in the "Services" column'
echo ' - The managment IP address will be in the column to the left of word "Management"'
echo
echo
echo 'While on this screen, verify the NFS VIP ip address as well:'
echo ' - Look in the "Services" column for an entry that says "Data"'
echo '   and the "Interface" column says "nfs01" - should be 10.21.225.38'
echo
echo
echo

echo "Please enter the IP address of the FlashBlade management interface:"
printf "(Press enter to accept default of $DEFAULT_MANAGEMENT_IP):"
read ANSWER

if [ -z "$ANSWER" ]
then
        MANAGEMENT_IP=$DEFAULT_MANAGEMENT_IP
else
        MANAGEMENT_IP=$ANSWER
fi
echo
echo
echo "Please enter the IP address of the NFS VIP:"
printf "(Press enter to accept default of $DEFAULT_NFS_VIP):"
read ANSWER

if [ -z "$ANSWER" ]
then
        NFS_VIP=$DEFAULT_NFS_VIP
else
        NFS_VIP=$ANSWER
fi

echo
echo
echo
echo "Summary:"
echo "------------------------------"
printf "Flashblade Management IP address: ${GREEN}$MANAGEMENT_IP${NC}\n"
printf "Flashblade NFS VIP IP address: ${GREEN}$NFS_VIP${NC}\n"
printf "Dashboard VM IP address: ${GREEN}$IP_ADDR${NC}\n"
echo
printf "Press ${GREEN}<CR>${NC} to continue, or ${RED}<CNTL-C>${NC} to abort:"
read foo

echo
echo
printf "${GREEN}-----------------  Beginning install ------------------------${NC}\n"

printf "${GREEN}Updating system rpms....${NC}\n"
yum update -y -q

echo
printf "${GREEN}Installing wget${NC}\n"
yum -y -q install wget

echo
printf "${GREEN}Installing sshpass...${NC}\n"
yum -y -q install sshpass

echo
printf "${GREEN}Creating users: prometheus, node_exporter, pure_exporter${NC}\n"

useradd --no-create-home --shell /usr/sbin/nologin prometheus
useradd --no-create-home --shell /usr/sbin/nologin node_exporter
useradd --no-create-home --shell /usr/sbin/nologin pure_exporter

printf "${GREEN}Creating diretories...${NC}\n"
mkdir /etc/prometheus
mkdir /var/lib/prometheus
mkdir /var/lib/prometheus/logcollect
mkdir /tmp/prometheus

printf "${GREEN}Downloading prometheus installer....${NC}\n"
cd /tmp/prometheus
curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest \
| grep browser_download_url  \
| grep linux-amd64 \
| cut -d '"' -f 4 \
| wget -qi -

echo
printf "${GREEN}Untarring Prometheus...${NC}\n"
cd /tmp/prometheus
tar xzf `ls *gz`


printf "${GREEN}Moving prometheus to /var/lib...${NC}\n"
cd /tmp/prometheus/`ls /tmp/prometheus|grep -v gz`

mv * /var/lib/prometheus
mv /var/lib/prometheus/prometheus.yml /etc/prometheus
ln -s /var/lib/prometheus/prometheus /usr/local/bin/prometheus

chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus

printf "${GREEN}Downloading node_exporter......${NC}\n"
cd /tmp/prometheus
mkdir node_exporter
cd node_exporter
wget -q https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz 
tar xzf `ls *gz`

mv node_exporter-0.18.1.linux-amd64/node_exporter /var/lib/prometheus
chown prometheus:prometheus /var/lib/prometheus/node_exporter


echo "[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online-target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus \
--web.console.templates=/var/lib/prometheus/consoles \
--web.console.libraries=/var/lib/prometheus/console_libraries 

[Install]
WantedBy=multi-user.target

" >/etc/systemd/system/prometheus.service

printf "${GREEN}Starting up Prometheus......${NC}\n"
systemctl daemon-reload
systemctl enable --now prometheus


echo "[Unit]
Description=Node Exporter

[Service]
User=prometheus
ExecStart=/var/lib/prometheus/node_exporter --collector.textfile.directory /var/lib/prometheus/logcollect 

[Install]
WantedBy=default.target

" >/etc/systemd/system/node_exporter.service

printf "${GREEN}Starting up node_exporter...${NC}\n"
systemctl daemon-reload
systemctl enable --now node_exporter
systemctl start node_exporter
sleep 5
systemctl status node_exporter.service | grep "Active:"



echo
printf "${GREEN}-----------------  Installing grafana ------------------------${NC}\n"
echo
echo
echo "[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt" >/etc/yum.repos.d/grafana.repo
yum -y -q install grafana

/bin/systemctl daemon-reload
/bin/systemctl enable grafana-server.service

echo
echo
printf "${GREEN}-----------------  Installing go ------------------------${NC}\n"

cd $INST_DIR
wget -q https://dl.google.com/go/go1.13.8.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.13.8.linux-amd64.tar.gz

printf "${GREEN}============================================================================${NC}\n"
printf "${GREEN}Installing zip and unzip .....${NC}\n"
yum -y -q install zip
yum -y -q install unzip
echo
printf "${GREEN}============================================================================${NC}\n"
printf "${GREEN}Downloading prometheus-flashblade-exporter .....${NC}\n"
wget -q https://github.com/man-group/prometheus-flashblade-exporter/archive/master.zip
printf "${GREEN}Unzipping prometheus-flashblade-exporter .....${NC}\n"
unzip master.zip 2>/dev/null 1>/dev/null
cd prometheus-flashblade-exporter-master
PATH=$PATH:/usr/local/go/bin
export PATH
printf "${GREEN}Compiling prometheus-flashblade-exporter .....${NC}\n"
make >/dev/null 2>/dev/null
cp prometheus-flashblade-exporter /usr/local/bin
cd ..
rm master.zip
rm go1.13.8.linux-amd64.tar.gz
rm -r prometheus-flashblade-exporter-master
chown prometheus:prometheus /usr/local/bin/prometheus-flashblade-exporter
chmod 755 /usr/local/bin/prometheus-flashblade-exporter

wget -q --no-check-certificate https://raw.githubusercontent.com/purekevin/pure-grafana-prometheus/master/start-fb-exporter.sh
mkdir /var/lib/prometheus/flashblade-exporter
mv start-fb-exporter.sh /var/lib/prometheus/flashblade-exporter
chown -R prometheus.prometheus /var/lib/prometheus/flashblade-exporter
chmod 755 /var/lib/prometheus/flashblade-exporter/start-fb-exporter.sh

echo "[Unit]
Description=Flashblade Exporter

[Service]
User=pure_exporter
Group=pure_exporter
ExecStart=/var/lib/prometheus/flashblade-exporter/start-fb-exporter.sh
Type=forking

[Install]
WantedBy=default.target

" >/etc/systemd/system/flashblade-exporter.service

systemctl daemon-reload
systemctl enable --now flashblade-exporter
systemctl start flashblade-exporter

printf "${GREEN}-----------------  Beginning install of pure_exporter ------------------------${NC}\n"
wget -q https://github.com/PureStorage-OpenConnect/pure-exporter/archive/master.zip
unzip -q master.zip
rm master.zip
mv pure-exporter-master /var/lib/prometheus/pure-exporter
yum -y -q install python3
python3 -m pip install gunicorn
python3 -m pip install virtualenv

cd /var/lib/prometheus/pure-exporter
echo '#!/bin/sh
python3 -m venv /var/lib/prometheus/pure-exporter/env
source /var/lib/prometheus/pure-exporter/env/bin/activate

# install dependencies
python3 -m pip install -r /var/lib/prometheus/pure-exporter/requirements.txt

# run the application in debug mode
python3 /var/lib/prometheus/pure-exporter/pure_exporter.py
' >/var/lib/prometheus/pure-exporter/start-pure-exporter.sh


chmod 755 /var/lib/prometheus/pure-exporter/start-pure-exporter.sh

sed 's/8080/9491/g' pure_exporter.py >pure_exporter.tmp
mv pure_exporter.py pure_exporter_8080.py
mv pure_exporter.tmp pure_exporter.py

echo '[Unit]
Description=Pure Exporter

[Service]
User=pure_exporter
Group=pure_exporter
ExecStart=/var/lib/prometheus/pure-exporter/start-pure-exporter.sh

[Install]
WantedBy=default.target

' >/etc/systemd/system/pure-exporter.service

chown -R pure_exporter /var/lib/prometheus/pure-exporter
systemctl daemon-reload
systemctl enable --now pure-exporter
systemctl start pure-exporter
sleep 5
systemctl status pure-exporter | grep "Active:"

wget -q --no-check-certificate https://raw.githubusercontent.com/purekevin/pure-grafana-prometheus/master/prometheus-all.yml
mv /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.old.yml
mv prometheus-all.yml /etc/prometheus/prometheus.yml

printf "${GREEN}Restarting Prometheus after updating the /etc/prometheus/prometheus.yml file...${NC}\n"
systemctl restart prometheus
sleep 5
systemctl status prometheus | grep "Active"

wget --no-check-certificate -q https://github.com/purekevin/pure-grafana-prometheus/raw/master/grafana-all.db
chown grafana:grafana grafana-all.db
mv /var/lib/grafana/grafana.db /var/lib/grafana/grafana.db.orig 2>/dev/null >/dev/null
mv grafana-all.db /var/lib/grafana/grafana.db
/bin/systemctl start grafana-server.service



printf "${GREEN}-----------------  Beginning install nfs utils ------------------------${NC}\n"
yum -y -q install nfs-utils

systemctl restart grafana-server

printf "${GREEN}-----------------  Installation complete ------------------------${NC}\n"
echo
printf "Please point browser to ${GREEN}http://$IP_ADDR:3000${NC}\n"
printf "Login with the username ${GREEN}admin${NC}\n"
printf "and the password is ${GREEN}admin${NC}\n"

echo
echo
echo
