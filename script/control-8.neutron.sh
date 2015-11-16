#!/bin/bash -ex
#
# RABBIT_PASS=a
# ADMIN_PASS=a

source config.cfg

SERVICE_TENANT_ID=`keystone tenant-get service | awk '$2~/^id/{print $4}'`


echo "############ Cau hinh forward goi tin cho cac VM ############"
sleep 7 
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
sysctl -p 



echo "########## CAI DAT NEUTRON TREN $CON_MGNT_IP ##########"
sleep 5
apt-get -y install neutron-server neutron-plugin-ml2 python-neutronclient
apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent
apt-get -y install neutron-server neutron-plugin-ml2 python-neutronclient


######## SAO LUU CAU HINH NEUTRON.CONF CHO $CON_MGNT_IP##################"
echo "########## SUA FILE CAU HINH  NEUTRON CHO $CON_MGNT_IP ##########"
sleep 7

#
controlneutron=/etc/neutron/neutron.conf
test -f $controlneutron.orig || cp $controlneutron $controlneutron.orig
rm $controlneutron
touch $controlneutron
cat << EOF >> $controlneutron
[DEFAULT]
verbose = True

rpc_backend = rabbit
auth_strategy = keystone

core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
nova_url = http://$CON_MGNT_IP:8774/v2


[matchmaker_redis]
[matchmaker_ring]
[quotas]
[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000
auth_url = http://$CON_MGNT_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $NEUTRON_PASS



[database]
connection = mysql://neutron:$NEUTRON_DBPASS@$CON_MGNT_IP/neutron


[nova]
auth_url = http://$CON_MGNT_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS

[oslo_concurrency]
lock_path = \$state_path/lock
[oslo_policy]
[oslo_messaging_amqp]
[oslo_messaging_qpid]

[oslo_messaging_rabbit]
rabbit_host = $CON_MGNT_IP
rabbit_userid = openstack
rabbit_password = $RABBIT_PASS

EOF


######## SAO LUU CAU HINH ML2 CHO $CON_MGNT_IP##################"
echo "########## SUA FILE CAU HINH  ML2 CHO $CON_MGNT_IP ##########"
sleep 7

controlML2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $controlML2.orig || cp $controlML2 $controlML2.orig
rm $controlML2
touch $controlML2

cat << EOF >> $controlML2
[ml2]
type_drivers = flat,vlan,gre
tenant_network_types = vlan,gre
mechanism_drivers = openvswitch

[ml2_type_flat]

[ml2_type_vlan]
network_vlan_ranges = physnet1:100:600

[ml2_type_gre]

[ml2_type_vxlan]

[securitygroup]
enable_security_group = True
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

[ovs]
tenant_network_type = vlan
bridge_mappings = physnet1:br-eth1

EOF


echo "######## Dong bo hoa database #########"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

echo "############  Sua file cau hinh DHCP AGENT ############ "
sleep 7 
#
netdhcp=/etc/neutron/dhcp_agent.ini

test -f $netdhcp.orig || cp $netdhcp $netdhcp.orig
rm $netdhcp
touch $netdhcp

cat << EOF >> $netdhcp
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
dhcp_delete_namespaces = True
verbose = True
enable_isolated_metadata = True
EOF

echo "############  Sua file cau hinh METADATA AGENT ############"
sleep 7 
#
netmetadata=/etc/neutron/metadata_agent.ini

test -f $netmetadata.orig || cp $netmetadata $netmetadata.orig
rm $netmetadata
touch $netmetadata

cat << EOF >> $netmetadata
[DEFAULT]
verbose = True

auth_uri = http://$CON_MGNT_IP:5000
auth_url = http://$CON_MGNT_IP:35357
auth_region = regionOne
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $NEUTRON_PASS

nova_metadata_ip = $CON_MGNT_IP

metadata_proxy_shared_secret = $METADATA_SECRET
EOF
#

# Add them cac port cho OVS
ovs-vsctl add-br br-int 
ovs-vsctl add-br br-eth1
ovs-vsctl add-port br-eth1 eth1

echo "############  Khoi dong lai OpenvSwitch ############"
sleep 7

service neutron-server restart
service openvswitch-switch restart
service neutron-plugin-openvswitch-agent restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
# service neutron-lbaas-agent restart
# service neutron-vpn-agent restart

sleep 15

service openvswitch-switch restart
service neutron-plugin-openvswitch-agent restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
# service neutron-lbaas-agent restart
# service neutron-vpn-agent restart


sed -i "s/exit 0/# exit 0/g" /etc/rc.local
echo "service neutron-server restart" >> /etc/rc.local
echo "service openvswitch-switch restart" >> /etc/rc.local
echo "service neutron-plugin-openvswitch-agent restart" >> /etc/rc.local
echo "service neutron-l3-agent restart" >> /etc/rc.local
echo "service neutron-dhcp-agent restart" >> /etc/rc.local
echo "service neutron-metadata-agent restart" >> /etc/rc.local
# echo "service neutron-lbaas-agent restart" >> /etc/rc.local
# echo "service neutron-vpn-agent restart" >> /etc/rc.local
echo "exit 0" >> /etc/rc.local


