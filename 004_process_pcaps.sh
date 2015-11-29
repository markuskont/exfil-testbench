#!/bin/bash

# Global variables

PCAP_DIR="/vagrant/pcap"
LOG_DIR="/vagrant/logs"

SSH_ARGS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

MONITORING_BOX='tap'
MONITORING_BOX2='moloch'
SENDER_BOX='host'
LISTENER_BOX='cnc'

SNORT_ET_LOG_DIR="$LOG_DIR/snort_et"
BRO_LOG_DIR="$LOG_DIR/bro"
SURICATA_LOG_DIR="$LOG_DIR/suricata"

EXTENTION='.pcap'

MOLOCH_BASE_DIR="/data/moloch"

# Common functions
function die() { 
    echo "$@" 1>&2
    exit 1
}

function SSH () {
    BOX=$1
    CMD=$2

    vagrant ssh $BOX -c "$CMD"

}

echo "Please enter oinkcode: "
read OINKCODE

TAP="
sudo cp /vagrant/elk/logstash/10-read.conf /etc/logstash/conf.d/
sudo curl -XDELETE localhost:9200/*
sudo service logstash stop
sudo service logstash start

if [[ $OINKCODE =~ [a-f0-9]+ ]]; then
    echo \"Downloading Sourcefire registered rules\"
    sudo wget -O rules.tgz https://www.snort.org/rules/snortrules-snapshot-2976.tar.gz?oinkcode=$OINKCODE
    mkdir -p /vagrant/snort/sourcefire
    rm -r /vagrant/snort/sourcefire/*
    tar -xzf rules.tgz -C /vagrant/snort/sourcefire
    cp /vagrant/snort/snort-sourcefire.conf /vagrant/snort/sourcefire/snort.conf
else
    echo \"Oinkcode does not match HEX format. Not doing anything.\"
fi

nohup sudo suricata -c /etc/suricata/suricata.yaml --unix-socket & sleep 10

for pcap in \`find $PCAP_DIR -type f -name *$EXTENTION\`; do
    iteration_name=\`echo \$pcap | \\
    awk -F \"$PCAP_DIR\" '{print \$2}' |\\
    awk -F \"$EXTENTION\" '{print \$1}' |\\
    cut -d '/' -f 2\`

    echo \"Processing \$pcap with BRO\"
    iteration_log_dir=$BRO_LOG_DIR/\$iteration_name
    if [ -d \$iteration_log_dir ]; then
        rm -r \$iteration_log_dir
    fi
    mkdir -p \$iteration_log_dir
    cd \$iteration_log_dir
    /opt/bro/bin/bro -C -r \$pcap /opt/bro/share/bro/site/local.bro

    echo \"Processing \$pcap with Suricata\"
    iteration_log_dir=$SURICATA_LOG_DIR/\$iteration_name
    if [ -d \$iteration_log_dir ]; then
        rm -r \$iteration_log_dir
    fi
    mkdir -p \$iteration_log_dir
    sudo suricatasc -c \"pcap-file \$pcap \$iteration_log_dir\"

    #echo \"Processing \$pcap with Snort (Emerging threats ruleset)\"
    #iteration_log_dir=$SNORT_ET_LOG_DIR
    #if [ -d \$iteration_log_dir ]; then
    #    rm -r \$iteration_log_dir
    #fi
    #mkdir -p \$iteration_log_dir

    #echo \"Processing \$pcap with Snort (Sourcefire registered ruleset)\"
    #iteration_log_dir=$SNORT_ET_LOG_DIR
    #if [ -d \$iteration_log_dir ]; then
    #    rm -r \$iteration_log_dir
    #fi
    #mkdir -p \$iteration_log_dir
done

sudo pkill -9 Suricata
"

MOLOCH="

sudo pkill -9 moloch

sudo service elasticsearch stop
sudo service elasticsearch start

sleep 10

echo INIT | sudo /data/moloch/db/db.pl 127.0.0.1:9200 init
sleep 5
cd $MOLOCH_BASE_DIR/viewer
node addUser.js -c ../etc/config.ini admin "Admin" admin -admin

sudo $MOLOCH_BASE_DIR/bin/moloch-capture -c $MOLOCH_BASE_DIR/etc/config.ini -R $PCAP_DIR

cd $MOLOCH_BASE_DIR/bin
nohup sudo ./run_viewer.sh & sleep 1

"

SSH $MONITORING_BOX "$TAP"
#SSH $MONITORING_BOX2 "$MOLOCH"

# MAIN
# suricatasc
# https://redmine.openinfosecfoundation.org/projects/suricata/wiki/Interacting_via_Unix_Socket