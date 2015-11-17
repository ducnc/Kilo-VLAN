#!/bin/bash

cat << EOF > config.cfg

# Bien ten may cua CONTROLLER
HOST_NAME=controller1

## Khai bao IP cho $HOST_NAME NODE
CON_MGNT_IP=172.16.69.60
CON2_MGNT_IP=172.16.69.63

# Khai bao IP cho COMPUTE1 NODE
COM1_MGNT_IP=172.16.69.61
COM2_MGNT_IP=172.16.69.62


GATEWAY_IP=172.16.69.1
NETMASK_ADD=255.255.255.0

# Set password
DEFAULT_PASS='Welcome123'

RABBIT_PASS=`openssl rand -hex 10`
MYSQL_PASS=`openssl rand -hex 10`
TOKEN_PASS=`openssl rand -hex 10`
ADMIN_PASS=`openssl rand -hex 10`
DEMO_PASS=`openssl rand -hex 10`
SERVICE_PASSWORD=`openssl rand -hex 10`
METADATA_SECRET=`openssl rand -hex 10`

SERVICE_TENANT_NAME="service"
ADMIN_TENANT_NAME="admin"
DEMO_TENANT_NAME="demo"
INVIS_TENANT_NAME="invisible_to_admin"
ADMIN_USER_NAME="admin"
DEMO_USER_NAME="demo"

# Environment variable for OPS service
KEYSTONE_PASS=`openssl rand -hex 10`
GLANCE_PASS=`openssl rand -hex 10`
NOVA_PASS=`openssl rand -hex 10`
NEUTRON_PASS=`openssl rand -hex 10`
CINDER_PASS=`openssl rand -hex 10`

# Environment variable for DB
KEYSTONE_DBPASS=`openssl rand -hex 10`
GLANCE_DBPASS=`openssl rand -hex 10`
NOVA_DBPASS=`openssl rand -hex 10`
NEUTRON_DBPASS=`openssl rand -hex 10`
CINDER_DBPASS=`openssl rand -hex 10`

# User declaration in Keystone
ADMIN_ROLE_NAME="admin"
MEMBER_ROLE_NAME="Member"
KEYSTONEADMIN_ROLE_NAME="KeystoneAdmin"
KEYSTONESERVICE_ROLE_NAME="KeystoneServiceAdmin"


# OS_SERVICE_TOKEN=`openssl rand -hex 10`

EOF
