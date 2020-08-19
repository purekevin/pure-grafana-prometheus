#!/bin/sh
cd /var/lib/prometheus/pure-exporter-master
python3 -m venv env
source ./env/bin/activate

# install dependencies
python3 -m pip install -r requirements.txt

# run the application in debug mode
python3 pure_exporter.py >pure-exporter.log 2>&1 &

