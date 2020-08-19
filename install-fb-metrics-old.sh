#!/bin/sh

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
useradd --no-create-home --shell /bin/false node_exporter
useradd --no-create-home --shell /usr/sbin/nologin pure_exporter

printf "${GREEN}Creating diretories...${NC}\n"
mkdir /etc/prometheus
mkdir /var/lib/prometheus
mkdir /var/lib/prometheus/logcollect
mkdir /tmp/prometheus

printf "${GREEN}Downloading prometheus tarball....${NC}\n"
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
systemctl start prometheus
sleep 5
systemctl status prometheus.service | grep "Active:"


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


echo "
  - job_name: 'node_exporter'
    static_configs:
    - targets: ['localhost:9100']
" >> /etc/prometheus/prometheus.yml 

systemctl restart prometheus
sleep 5
systemctl status prometheus | grep "Active:"

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

wget --no-check-certificate -q https://10.21.224.167/pureuser/rft-prometheus-dashboard/-/raw/master/grafana.db
chown grafana:grafana grafana.db
mv /var/lib/grafana/grafana.db /var/lib/grafana/grafana.db.orig 2>/dev/null >/dev/null
mv grafana.db /var/lib/grafana
/bin/systemctl start grafana-server.service

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

wget --no-check-certificate -q https://10.21.224.167/pureuser/rft-prometheus-dashboard/-/raw/master/start-fb-exporter.sh
mkdir /var/lib/prometheus/flashblade-exporter
mv start-fb-exporter.sh /var/lib/prometheus/flashblade-exporter
chown -R prometheus.prometheus /var/lib/prometheus/flashblade-exporter
chmod 755 /var/lib/prometheus/flashblade-exporter/start-fb-exporter.sh

echo "[Unit]
Description=Flashblade Exporter

[Service]
User=prometheus
ExecStart=/var/lib/prometheus/flashblade-exporter/start-fb-exporter.sh
Type=forking

[Install]
WantedBy=default.target

" >/etc/systemd/system/flashblade-exporter.service

systemctl daemon-reload
systemctl enable --now flashblade-exporter
systemctl start flashblade-exporter
sleep 5
systemctl status flashblade-exporter | grep "Active:"

echo "
  - job_name: 'fb_exporter'
    static_configs:
    - targets: ['localhost:9130']
" >> /etc/prometheus/prometheus.yml 
printf "${GREEN}Restarting Prometheus after updating the /etc/prometheus/prometheus.yml file...${NC}\n"
systemctl restart prometheus
sleep 5
systemctl status prometheus | grep "Active"
printf "${GREEN}-----------------  Beginning install of rapidfile toolkit ------------------------${NC}\n"
wget --no-check-certificate -q https://10.21.224.167/pureuser/rapidfiletoolkit/-/raw/master/rapidfile-1.0.0-beta.5.tar
tar xf rapidfile-1.0.0-beta.5.tar
rm rapidfile-1.0.0-beta.5.tar
rpm -U rapidfile-1.0.0-beta.5/rapidfile-1.0.0-beta.5-Linux.rpm

printf "${GREEN}-----------------  Beginning install nfs utils ------------------------${NC}\n"
yum -y -q install nfs-utils

mkdir /mnt1 /mnt2
echo "${NFS_VIP}:/da-dashboard-1   /mnt1     nfs    rw,sync,hard,intr 0 0" >>/etc/fstab
echo "${NFS_VIP}:/da-dashboard-2   /mnt2     nfs    rw,sync,hard,intr 0 0" >>/etc/fstab
mount /mnt1
mount /mnt2
echo
echo
printf "${GREEN}-----------------  Installing crontab ------------------------${NC}\n"
wget --no-check-certificate -q  https://10.21.224.167/pureuser/rft-prometheus-dashboard/-/raw/master/crontab
wget --no-check-certificate -q  https://10.21.224.167/pureuser/rft-prometheus-dashboard/-/raw/master/rft.sh


chmod 755 rft.sh
mv rft.sh /var/lib/prometheus/logcollect/
crontab -l >crontab.tmp
cat crontab >>crontab.tmp
crontab crontab.tmp
crontab -l
echo
echo
printf "${GREEN}-----------------  Downloading additional tools ------------------------${NC}\n"
wget --no-check-certificate -q https://10.21.224.167/pureuser/rft-prometheus-dashboard/-/raw/master/mk-empty-files.sh
wget --no-check-certificate -q https://10.21.224.167/pureuser/rft-prometheus-dashboard/-/raw/master/mk-data-files.sh


chmod 755 mk-empty-files.sh mk-data-files.sh
echo
echo

printf "${GREEN}-----------------  Installation complete ------------------------${NC}\n"
echo
printf "Please point browser to ${GREEN}http://$IP_ADDR:3000${NC}\n"
printf "Login with the username ${GREEN}admin${NC}\n"
printf "and the password is ${GREEN}admin${NC}\n"

echo
echo
echo
