#!/bin/sh
yum install -y -q nfs-utils
mount 10.21.225.38:/da-datastore /mnt

yum install -y -q unzip
yum install -y -q python3
yum install -y -q epel-release

cp /mnt/src/pure-exporter-master.zip /usr/local
cd /usr/local
unzip pure-exporter-master.zip
cd pure-exporter-master

python3 -m venv env
source ./env/bin/activate

pip install --upgrade pip
yum install -y -q python-gunicorn

# yum install -y -q python-pip

python -m pip install -r requirements.txt
python3 pure_exporter.py





