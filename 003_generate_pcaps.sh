#!/bin/bash

PCAP_DIR="/vagrant/pcap"
SLEEP_INTERVAL='1'
MONITORING_BOX='tap'

cnc='10.0.242.194'
host='10.0.242.193'

files=( '/etc/shadow' '/root/.ssh/id_rsa' '/root/.ssh/id_rsa.pub' )
ports=( '53' '22' '80' '443' )
proto=( 't' 'u' )
ipver=( '4' '6' )

tun64_modes=( 't6over4' 't6to4' 'isatap' )

cnc_4='192.168.12.12'
cnc_6='2a02:1010:12::12'

cnc_ssh_port='2022'

working_dir='/tmp'
#working_dir='/var/pcap/experiments'

SSH () {
    BOX=$1
    CMD=$2
    vagrant ssh $BOX -c "$CMD"
}

start_tcpdump_listener () {

    PCAP_NAME=$1

    kill_tcpdump_listener
    echo "Creating PCAP folder"
    SSH $MONITORING_BOX "sudo mkdir -p $PCAP_DIR"
    echo "starting tcpdump for $ver-$protocol-$port.pcap"
    SSH $MONITORING_BOX "nohup sudo tcpdump -i eth0 -w $PCAP_DIR/$PCAP_NAME.pcap & sleep 1"
    echo "sleeping after sending data"
    sleep $SLEEP_INTERVAL
}

kill_tcpdump_listener () {
    echo "killing tcpdump"
    SSH $MONITORING_BOX "sudo pkill tcpdump"
    sleep $SLEEP_INTERVAL
}

run_tun64_test () {
    for mode in "${tun64_modes[@]}"; do
        echo "Initiating tunneling $mode test"
        start_tcpdump_listener
        tun64
        kill_tcpdump_listener
    done
}

# MAIN
#for protocol in "${proto[@]}"; do
#    echo "Initiating protocol $protocol test"
#    for port in "${ports[@]}"; do
#    echo "Initiating port $port test"
#
#    done
#done

start_tcpdump_listener "testime"
# testing
SSH $MONITORING_BOX "echo test"
sleep $SLEEP_INTERVAL
kill_tcpdump_listener