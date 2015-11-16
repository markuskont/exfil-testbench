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

function iterate_pcaps () {
    # turn existing pcaps into an array
    EXTENTION='.pcap'
    pcaps=`vagrant ssh $MONITORING_BOX -c "find $PCAP_DIR -type f -name *$EXTENTION"` || die "Unable to find pcaps over ssh"
    tempfile=`mktemp`

    for pcap in $pcaps ; do
        echo $pcap | awk -F "$PCAP_DIR" '{print $2}' | awk -F "$EXTENTION" '{print $1}' | cut -d '/' -f 2 >> $tempfile
    done

    SSH $MONITORING_BOX "rm -r $LOG_DIR/bro"

    for pcap in `cat $tempfile`; do
        echo $pcap
        SSH $MONITORING_BOX "mkdir -p $LOG_DIR/bro/$pcap && cd $LOG_DIR/bro/$pcap && /opt/bro/bin/bro -C -r $PCAP_DIR/$pcap.pcap /opt/bro/share/bro/site/local.bro"
    done

    rm $tempfile

#    SSH $MONITORING_BOX "mkdir $LOG_DIR"
#    SSH $MONITORING_BOX "find $PCAP_DIR -type f -name *.pcap | while read pcap ; do cd \"$LOG_DIR/\`echo $pcap | awk -F \"$PCAP_DIR\" '{print \$2}'\`\" && /opt/bro/bin/bro -r \$pcap /opt/bro/share/bro/site/local.bro ; done"

}

iterate_pcaps

# MAIN
