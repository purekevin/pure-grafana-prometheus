Code to install/run prometheus/grafana/node-exporter/flashblade-exporter/APIs

Once logged into the VM, run this command:
<br>
curl --insecure -s -o install-fb-metrics.sh https://10.21.224.167/pureuser/rft-prometheus-dashboard/-/raw/master/install-fb-metrics.sh
<br>
chmod 755 ./install-fb-metrics.sh
<br>
./install-fb-metrics.sh
