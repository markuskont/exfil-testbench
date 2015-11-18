#!/bin/bash

# Global variables

PCAP_DIR="/vagrant/pcap"
LOG_DIR="/vagrant/logs"

SSH_ARGS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

MONITORING_BOX='tap'
SENDER_BOX='host'
LISTENER_BOX='cnc'

SNORT_LOG_DIR="$LOG_DIR/snort"
BRO_LOG_DIR="$LOG_DIR/bro"
SURICATA_LOG_DIR="$LOG_DIR/suricata"

EXTENTION='.pcap'

SCRIPT="
sudo cp /vagrant/elk/logstash/10-read.conf /etc/logstash/conf.d/
sudo curl -XDELETE localhost:9200/*
sudo service logstash stop
sudo service logstash start

nohup sudo suricata -c /etc/suricata/suricata.yaml --unix-socket & sleep 10

for pcap in \`find $PCAP_DIR -type f -name *$EXTENTION\`; do
    iteration_name=\`echo \$pcap | \\
    awk -F \"$PCAP_DIR\" '{print \$2}' |\\
    awk -F \"$EXTENTION\" '{print \$1}' |\\
    cut -d '/' -f 2\`

    echo \"Processing pcaps with BRO\"
    iteration_log_dir=$BRO_LOG_DIR/\$iteration_name
    if [ -d \$iteration_log_dir ]; then
        rm -r \$iteration_log_dir
    fi
    mkdir -p \$iteration_log_dir
    cd \$iteration_log_dir
    /opt/bro/bin/bro -C -r \$pcap /opt/bro/share/bro/site/local.bro

    echo \"Processing pcaps with Suricata\"
    iteration_log_dir=$SURICATA_LOG_DIR/\$iteration_name
    if [ -d \$iteration_log_dir ]; then
        rm -r \$iteration_log_dir
    fi
    mkdir -p \$iteration_log_dir
    sudo suricatasc -c \"pcap-file \$pcap \$iteration_log_dir\"

done

sudo pkill -9 Suricata
"

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

SSH $MONITORING_BOX "$SCRIPT"

# MAIN
# suricatasc
# https://redmine.openinfosecfoundation.org/projects/suricata/wiki/Interacting_via_Unix_Socket