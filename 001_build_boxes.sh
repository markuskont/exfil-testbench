#!/bin/bash

WORKING_DIR="$PWD/tmp"

build_box () {

    NAME=$1

    vagrant status
    vagrant halt -f
    vagrant destroy -f
    vagrant up
    vagrant halt
    vagrant package --output $NAME.box
    vagrant destroy -f
    vagrant box remove $NAME
    vagrant box add $NAME $NAME.box

    rm -f $NAME.box
}

test_box () {

    NAME=$1

    vagrant status
    vagrant halt -f
    vagrant destroy -f
    vagrant up
}

mkdir -p $WORKING_DIR
cd $WORKING_DIR

cat <<EOF > Vagrantfile

\$script = <<SCRIPT

sudo sed -i 's/Port 22/Port 2022/g' /etc/ssh/sshd_config

sudo apt-get update
sudo apt-get install -y --force-yes httptunnel

sudo git clone https://github.com/lockout/nc64 /opt/nc64
sudo chmod 755 /opt/nc64/nc64.py

sudo git clone https://github.com/lockout/tun64 /opt/tun64
sudo chmod 755 /opt/tun64/tun64.py

SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "starflame/kali2_linux4.0.0_amd64"
  config.vm.provision "shell", inline: \$script
end

EOF

build_box exfil_kali

cat <<EOF > Vagrantfile

\$script = <<SCRIPT

sudo echo 1 > /proc/sys/net/ipv4/ip_forward
sudo echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

sudo echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
sudo echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf

sudo apt-get update
sudo apt-get -y install bind9 vim htop tmux

sudo cp /vagrant/named* /etc/bind/
sudo cp /vagrant/exfil.zone /var/cache/bind

sudo service bind9 restart

SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/jessie64"
  config.vm.provision "shell", inline: \$script
end
EOF

cat <<EOF > $WORKING_DIR/exfil.zone
\$ORIGIN .
\$TTL 300        ; 5 minutes
exfil.                      IN SOA  ns1.exfil. green.mail.exfil. (
                                2015102620 ; serial
                                1200       ; refresh (20 minutes)
                                180        ; retry (3 minutes)
                                604800     ; exfilpire (1 week)
                                7200       ; minimum (2 hours)
                                )
                        NS      ns1.exfil.
                        NS      ns2.exfil.

\$ORIGIN exfil.
ns1                     A       172.10.10.21
                        AAAA    2a01:1010:20::21
ns2                     A       172.10.10.22
                        AAAA    2a01:1010:20::22
router1                 A       172.10.10.21
                        AAAA    2a01:1010:20::21
router2                 A       172.10.10.22
                        AAAA    2a01:1010:20::22
cnc                     A       192.168.12.12
                        AAAA    2a02:1010:12::12
host                    A       192.168.11.11
                        AAAA    2a00:1010:11::11
badguys                 NS      cnc
EOF

cat <<EOF > $WORKING_DIR/named.conf.options
options {
    directory "/var/cache/bind";
    dnssec-validation auto;

    auth-nxdomain no;
    listen-on-v6 { any; };
    recursion yes;
};
EOF

cat <<EOF > $WORKING_DIR/named.conf.local
logging {
        category xfer-in { log_syslog; };
        category xfer-out { log_syslog; };
        category default { log_syslog; };

        category queries {log_syslog;};
        category lame-servers { null;};
        category edns-disabled { null; };

        channel log_syslog {
                syslog daemon;
                print-category yes;
                print-severity yes;
                print-time no;
        };
};
zone "exfil" {
        type master;
        file "exfil.zone";
};
EOF

build_box exfil_router

cd ..