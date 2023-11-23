#!/bin/bash
# File: vpn-site-to-site-reconfigure.sh
# Author: ufozone
# Date: 2023-01-29
# Version: 2.2.1
# Desc: UniFi Site-to-Site IPsec VTI VPN does not detect a change of WAN IP address.
#       This script checks periodically the current WAN IP addresses of both sites and 
#       updates the configuration.
# 
# DON'T CHANGE ANYTHING BELOW THIS LINE
#######################################

Log()
{
    if [[ $VERBOSE == TRUE ]]
    then
        echo -e "\e[1;32m$@\e[0m"
    fi
    if [[ $DEBUG == FALSE ]]
    then
        logger -t $NAME -- "$@"
    fi
}

Verbose()
{
    if [[ $VERBOSE == TRUE ]]
    then
        echo "$@"
    fi
}

Command()
{
    if [[ $VERBOSE == TRUE ]]
    then
        echo -e "\e[1;41mVyatta Command:\e[0m $@"
    elif [[ $DEBUG == TRUE ]]
    then
        echo "$@"
    fi
    if [[ $DEBUG == FALSE ]]
    then
        $WR $@
    fi
}

Reset()
{
    echo "Reset all configuration changes."
    echo ""
    
    echo -e "\e[0m\e[1;42mStart...\e[0m\e[0;33m"
    $WR begin
    $WR load
    
    VTI_BIND_FOUND=FALSE
    IFS=$'\n'
    
    VALIDATE_PEERS=$($WR show vpn ipsec site-to-site peer)
    for FOUND_PEER in $(echo "${VALIDATE_PEERS}" | grep -Po 'peer \b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b')
    do
        FOUND_PEER_ADDRESS=$(echo $FOUND_PEER | grep -Pom 1 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -n1)
        VALIDATE_PEER=$($WR show vpn ipsec site-to-site peer $FOUND_PEER_ADDRESS)
        if [[ $(echo "${VALIDATE_PEER}" | grep -i "${VTI_BIND}") ]]
        then
            echo -e "\e[0m\e[1;42mPeer with VTI interface ${VTI_BIND} found. Try to delete...\e[0m\e[0;33m"
            $WR delete vpn ipsec site-to-site peer $FOUND_PEER_ADDRESS
            VTI_BIND_FOUND=TRUE
        fi
    done
    
    if [[ $VTI_BIND_FOUND == TRUE ]]
    then
        echo -e "\e[0m\e[1;42mTry to delete IKE group ${IKE_GROUP}...\e[0m\e[0;33m"
        $WR delete vpn ipsec ike-group $IKE_GROUP
        
        echo -e "\e[0m\e[1;42mTry to delete ESP group ${ESP_GROUP}...\e[0m\e[0;33m"
        $WR delete vpn ipsec esp-group $ESP_GROUP
        
        # Issue #1: Commit failed
        #echo -e "\e[0m\e[1;42mTry to delete static route to ${TRANSFER_NETWORK} to point out ${VTI_BIND}...\e[0m\e[0;33m"
        #$WR delete protocols static interface-route $TRANSFER_NETWORK next-hop-interface $VTI_BIND
        
        echo -e "\e[0m\e[1;42mTry to delete VTI interface ${VTI_BIND}...\e[0m\e[0;33m"
        $WR delete interfaces vti $VTI_BIND
    fi
    
    echo -e "\e[0m\e[1;42mCommit...\e[0m\e[0;33m"
    $WR commit
    $WR end
    
    echo -e "\e[0m\e[1;42mRestart VPN service...\e[0m\e[0;33m"
    /opt/vyatta/bin/vyatta-op-cmd-wrapper restart vpn
    
    echo -e "\e[0m\e[1;42mFinished.\e[0m"
    Log "Reset site-to-site peer configuration."
    
    unset IFS
}

Help()
{
    echo "UniFi Site-to-Site IPsec VTI VPN does not detect a change of WAN IP address."
    echo "This script checks periodically the current WAN IP addresses of both sites and updates the configuration."
    echo
    echo "Syntax: ${NAME}.sh [-d|h|v]"
    echo "Options:"
    echo "d     Debug mode. Does not make any changes to the configuration, but displays them."
    echo "h     Print this Help."
    echo "r     Reset all configuration changes."
    echo "v     Verbose mode. It provides additional details."
    echo
}

# Make sure script is run as group vyattacfg
if [[ $(id -ng) != "vyattacfg" ]]
then
    Verbose "Script run in wrong scope. Restart."
    exec sg vyattacfg -c "$0 $@"
fi

VERBOSE=FALSE
DEBUG=FALSE
CONFIG_CHANGED=FALSE
CONFIG_FILE="/config/vpn-site-to-site.conf"
PEER_FILE="/config/vpn-site-to-site.peer"
NAME="vpn-site-to-site-reconfigure"
WR="/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper"

if [[ ! -e $CONFIG_FILE ]]
then
    Log "File vpn-site-to-site.conf not found. Abort."
    exit 1
fi
source $CONFIG_FILE

if [[ ( ( $THIS_SITE != "A" ) && ( $THIS_SITE != "B" ) ) || ( $SITE_A_HOST == "" ) || ( $SITE_B_HOST == "" ) || ( $PRE_SHARED_SECRET == "" ) ]]
then
    Log "Configuration in vpn-site-to-site.conf is invalid. Abort."
    exit 1
fi

TRANSFER_NETWORK="10.255.254.0/24"
if [[ $THIS_SITE == "A" ]]
then
    TRANSFER_ADDRESS="10.255.254.1/32"
    LOCAL_HOST=$SITE_A_HOST
    REMOTE_HOST=$SITE_B_HOST
    REMOTE_NETWORKS=$SITE_B_NETWORKS
else
    TRANSFER_ADDRESS="10.255.254.2/32"
    LOCAL_HOST=$SITE_B_HOST
    REMOTE_HOST=$SITE_A_HOST
    REMOTE_NETWORKS=$SITE_A_NETWORKS
fi

if [[ ! -n $VTI_BIND ]]
then
    VTI_BIND="vti64"
fi

if [[ ! -n $ESP_GROUP ]]
then
    ESP_GROUP="ESP0"
fi

if [[ ! -n $IKE_GROUP ]]
then
    IKE_GROUP="IKE0"
fi

while getopts ":dhrv" option
do
   case $option in
      d) DEBUG=TRUE;;
      h) Help
         exit;;
      r) Reset
         exit;;
      v) VERBOSE=TRUE;;
   esac
done

# Get local and remote addresses via DDNS lookup
GET_LOCAL_ADDRESS=$(host -st A $LOCAL_HOST)
LOCAL_ADDRESS=$(echo $GET_LOCAL_ADDRESS | grep -Pom 1 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -n1)
GET_REMOTE_ADDRESS=$(host -st A $REMOTE_HOST)
REMOTE_ADDRESS=$(echo $GET_REMOTE_ADDRESS | grep -Pom 1 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -n1)

if [[ $LOCAL_ADDRESS == "" ]]
then
    Log "No local address found. Abort."
    exit 1
else
    Verbose "Local address: ${LOCAL_ADDRESS}"
fi
if [[ $REMOTE_ADDRESS == "" ]]
then
    Log "No remote address found. Abort."
    exit 1
else
    Verbose "Remote address: ${REMOTE_ADDRESS}"
fi

# Begin configuration
Command begin

# Check current site-to-site VPN configuration over path
VALIDATE_INTERFACE=$($WR show interfaces vti $VTI_BIND address)
if [[ $(echo "${VALIDATE_INTERFACE}" | grep -i 'empty') ]]
then
    Log "VTI interface ${VTI_BIND} not found in configuration. Create."
    Command set interfaces vti $VTI_BIND address $TRANSFER_ADDRESS
    
    CONFIG_CHANGED=TRUE
else
    Verbose "VTI interface ${VTI_BIND} with ${VALIDATE_INTERFACE} found in configuration."
fi

VALIDATE_TRANSFER_ROUTE=$($WR show protocols static interface-route $TRANSFER_NETWORK next-hop-interface)
if [[ ! $(echo $VALIDATE_TRANSFER_ROUTE | grep -i "next-hop-interface ${VTI_BIND}") ]]
then
    Log "Static route ${TRANSFER_NETWORK} not found. Create."
    Command set protocols static interface-route $TRANSFER_NETWORK next-hop-interface $VTI_BIND
    
    CONFIG_CHANGED=TRUE
    Verbose "Static route ${TRANSFER_NETWORK} not found."
else
    Verbose "Static route ${TRANSFER_NETWORK} found."
fi

for REMOTE_NETWORK in `echo ${REMOTE_NETWORKS}`
do
    VALIDATE_REMOTE_ROUTE=$($WR show protocols static interface-route $REMOTE_NETWORK next-hop-interface $VTI_BIND)
    if [[ $(echo "${VALIDATE_REMOTE_ROUTE}" | grep -i 'empty') ]]
    then
        Log "Static route ${REMOTE_NETWORK} not found. Create."
        Command set protocols static interface-route $REMOTE_NETWORK next-hop-interface $VTI_BIND distance 30
        
        CONFIG_CHANGED=TRUE
    else
        Verbose "Static route ${REMOTE_NETWORK} found."
    fi
    VALIDATE_FIREWALL=$($WR show firewall group network-group remote_site_vpn_network network $REMOTE_NETWORK)
    if [[ $(echo "${VALIDATE_FIREWALL}" | grep -i 'empty') ]]
    then
        Log "Firewall group item ${REMOTE_NETWORK} not found. Create."
        Command set firewall group network-group remote_site_vpn_network network $REMOTE_NETWORK
        
        CONFIG_CHANGED=TRUE
    else
        Verbose "Firewall group item ${REMOTE_NETWORK} found."
    fi
done

# Check current site-to-site VPN configuration over path
VALIDATE_ESP_GROUP=$($WR show vpn ipsec esp-group $ESP_GROUP)
if [[ $(echo "${VALIDATE_ESP_GROUP}" | grep -i 'empty') ]]
then
    Log "ESP group ${ESP_GROUP} not found in configuration. Create."
    
    Command set vpn ipsec esp-group $ESP_GROUP compression disable
    Command set vpn ipsec esp-group $ESP_GROUP lifetime 3600
    Command set vpn ipsec esp-group $ESP_GROUP mode tunnel
    Command set vpn ipsec esp-group $ESP_GROUP pfs enable
    Command set vpn ipsec esp-group $ESP_GROUP proposal 1 encryption aes256
    Command set vpn ipsec esp-group $ESP_GROUP proposal 1 hash sha1
    
    CONFIG_CHANGED=TRUE
else
    Verbose "ESP group ${ESP_GROUP} found in configuration."
fi
VALIDATE_IKE_GROUP=$($WR show vpn ipsec ike-group $IKE_GROUP)
if [[ $(echo "${VALIDATE_IKE_GROUP}" | grep -i 'empty') ]]
then
    Log "IKE group ${IKE_GROUP} not found in configuration. Create."
    
    Command set vpn ipsec ike-group $IKE_GROUP dead-peer-detection action restart
    Command set vpn ipsec ike-group $IKE_GROUP dead-peer-detection interval 20
    Command set vpn ipsec ike-group $IKE_GROUP dead-peer-detection timeout 120
    Command set vpn ipsec ike-group $IKE_GROUP ikev2-reauth no
    Command set vpn ipsec ike-group $IKE_GROUP key-exchange ikev1
    Command set vpn ipsec ike-group $IKE_GROUP lifetime 28800
    Command set vpn ipsec ike-group $IKE_GROUP proposal 1 dh-group 14
    Command set vpn ipsec ike-group $IKE_GROUP proposal 1 encryption aes256
    Command set vpn ipsec ike-group $IKE_GROUP proposal 1 hash sha1
    
    CONFIG_CHANGED=TRUE
else
    Verbose "IKE group ${IKE_GROUP} found in configuration."
fi

# Check current peer configuration and used pre-shared-secret
VALIDATE_PEER=$($WR show vpn ipsec site-to-site peer $REMOTE_ADDRESS)
VALIDATE_PRE_SHARED_SECRET=$($WR show vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication pre-shared-secret)
CURRENT_PRE_SHARED_SECRET=$(echo $VALIDATE_PRE_SHARED_SECRET | grep -Piom 1 '\b[0-9a-f]+\b' | head -n1)

# No peer config found or incorrect pre-shared-secret in use
if [[ ( $(echo "${VALIDATE_PEER}" | grep -i 'empty') ) || ( $CURRENT_PRE_SHARED_SECRET != $PRE_SHARED_SECRET ) ]]
then
    if [[ $(echo "${VALIDATE_PEER}" | grep -i 'empty') ]]
    then
        Log "No site-to-site peer configuration found."
    elif [[ $CURRENT_PRE_SHARED_SECRET != $PRE_SHARED_SECRET ]]
    then
        Log "Incorrect pre-shared-secret is used."
    else
        Log "New remote adress detected. Updating config."
    fi
    
    if [[ -e $PEER_FILE ]]
    then
        LAST_REMOTE_ADDRESS=$(< $PEER_FILE)
        Verbose "Last remote address ${LAST_REMOTE_ADDRESS} found."
        
        VALIDATE_LAST_PEER=$($WR show vpn ipsec site-to-site peer $LAST_REMOTE_ADDRESS)
        if [[ ! $(echo "${VALIDATE_LAST_PEER}" | grep -i 'empty') ]]
        then
            Log "Try to delete the existing site-to-site peer configuration."
            Command delete vpn ipsec site-to-site peer $LAST_REMOTE_ADDRESS
        fi
    else
        Verbose "Peer file ${PEER_FILE} not found."
    fi
    
    Log "Set up new site-to-site peer configuration."
    (echo "${REMOTE_ADDRESS}" > $PEER_FILE) &> /dev/null
    Verbose "Write remote address ${REMOTE_ADDRESS} to ${PEER_FILE}."
    
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS description "CUSTOM_BY_SCRIPT"
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication id $LOCAL_HOST
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication remote-id $REMOTE_HOST
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication mode pre-shared-secret
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication pre-shared-secret $PRE_SHARED_SECRET
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS connection-type initiate
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS ike-group $IKE_GROUP
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS ikev2-reauth inherit
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS local-address $LOCAL_ADDRESS
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS vti bind $VTI_BIND
    Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS vti esp-group $ESP_GROUP
    
    CONFIG_CHANGED=TRUE
else
    Verbose "Remote address does not change."
    
    VALIDATE_LOCAL_ADDRESS=$($WR show vpn ipsec site-to-site peer $REMOTE_ADDRESS local-address)
    CURRENT_LOCAL_ADDRESS=$(echo $VALIDATE_LOCAL_ADDRESS | grep -Pom 1 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -n1)
    
    if [[ $CURRENT_LOCAL_ADDRESS != $LOCAL_ADDRESS ]]
    then
        Log "Local address change detected. Updating config."
        Command set vpn ipsec site-to-site peer $REMOTE_ADDRESS local-address $LOCAL_ADDRESS
        
        CONFIG_CHANGED=TRUE
    else
        Verbose "Local address does not change."
    fi
fi

if [[ $CONFIG_CHANGED == TRUE ]]
then
    Log "Commit configuration."
    Command commit
    
    if [[ $DEBUG == FALSE ]]
    then
        Verbose "Restart VPN service..."
        /opt/vyatta/bin/vyatta-op-cmd-wrapper restart vpn
    fi
else
    Verbose "Nothing to commit."
fi

# End configuration
Command end

exit 0