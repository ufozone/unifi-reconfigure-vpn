#!/bin/bash
# File: vpn-site-to-site-reconfigure.sh
# Author: ufozone
# Date: 2023-01-29
# Version: 1.0
# Desc: Site-to-Site VPN in Auto IPsec VTI mode does not detect a change of WAN IP address.
#       This script checks periodically the current WAN IP addresses of both sites and 
#       updates the configuration.
# 
# DON'T CHANGE ANYTHING BELOW THIS LINE
#######################################

CONFIG="/config/vpn-site-to-site.conf"
NAME="vpn-site-to-site-reconfigure"
WR="/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper"

if [[ ! -e $CONFIG ]]
then
	logger -t $NAME -- "File vpn-site-to-site.conf not found. Abort."
	exit 1
fi
source $CONFIG

if [[ ( ( "$THIS_SITE" != "A" ) && ( "$THIS_SITE" != "B" ) ) || ( "$SITE_A_HOST" == "" ) || ( "$SITE_B_HOST" == "" ) || ( "$PRE_SHARED_SECRET" == "" ) ]]
then
	logger -t $NAME -- "Configuration in vpn-site-to-site.conf is invalid. Abort."
	exit 1
fi

if [[ "$THIS_SITE" == "A" ]]
then
	LOCAL_HOST=$SITE_A_HOST
	REMOTE_HOST=$SITE_B_HOST
else
	LOCAL_HOST=$SITE_B_HOST
	REMOTE_HOST=$SITE_A_HOST
fi

# Begin configuration
$WR begin

# Check current site-to-site VPN configuration over path
VALIDATE_ESP_GROUP=$($WR show vpn ipsec esp-group ESP0)
if [[ $(echo "$VALIDATE_ESP_GROUP" | grep -i 'empty') ]]
then
	logger -t $NAME -- "ESP group ESP0 not found in configuration. Abort."
	logger -t $NAME -- "You need to set up an Auto IPsec VTI site-to-site VPN connection in the controller."
	exit 1
fi
VALIDATE_IKE_GROUP=$($WR show vpn ipsec ike-group IKE0)
if [[ $(echo "$VALIDATE_IKE_GROUP" | grep -i 'empty') ]]
then
	logger -t $NAME -- "IKE group IKE0 not found in configuration. Abort."
	logger -t $NAME -- "You need to set up an Auto IPsec VTI site-to-site VPN connection in the controller."
	exit 1
fi

# Get local and remote addresses via DDNS lookup
GET_LOCAL_ADDRESS=$(host -st A $LOCAL_HOST)
LOCAL_ADDRESS=$(echo $GET_LOCAL_ADDRESS | grep -Pom 1 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -n1)
GET_REMOTE_ADDRESS=$(host -st A $REMOTE_HOST)
REMOTE_ADDRESS=$(echo $GET_REMOTE_ADDRESS | grep -Pom 1 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -n1)

if [[ "$LOCAL_ADDRESS" == "" ]]
then
	logger -t $NAME -- "No local address found. Abort."
	exit 1
fi
if [[ "$REMOTE_ADDRESS" == "" ]]
then
	logger -t $NAME -- "No remote address found. Abort."
	exit 1
fi

# Check current peer configuration and used pre-shared-secret
VALIDATE_PEER=$($WR show vpn ipsec site-to-site peer $REMOTE_ADDRESS)
VALIDATE_PRE_SHARED_SECRET=$($WR show vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication pre-shared-secret)
CURRENT_PRE_SHARED_SECRET=$(echo $VALIDATE_PRE_SHARED_SECRET | grep -Piom 1 '\b[0-9a-f]+\b' | head -n1)

# No peer config found or incorrect pre-shared-secret in unse
if [[ ( $(echo "$VALIDATE_PEER" | grep -i 'empty') ) || ( "$CURRENT_PRE_SHARED_SECRET" != "$PRE_SHARED_SECRET" ) ]]
then
	if [[ $(echo "$VALIDATE_PEER" | grep -i 'empty') ]]
	then
		logger -t $NAME -- "No site-to-site peer configuration found."
	elif [[ "$CURRENT_PRE_SHARED_SECRET" != "$PRE_SHARED_SECRET" ]]
	then
		logger -t $NAME -- "Incorrect pre-shared-secret is used."
	else
		logger -t $NAME -- "New remote adress detected. Updating config."
	fi
	
	VALIDATE_DELETE=$($WR delete vpn ipsec site-to-site)
	if [[ ! $(echo "$VALIDATE_DELETE" | grep -i 'nothing') ]]
	then
		logger -t $NAME -- "Existing site-to-site peer deleted."
	fi
	
	logger -t $NAME -- "Set up new site-to-site peer configuration."
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS description "CUSTOM_BY_SCRIPT"
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication mode pre-shared-secret
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS authentication pre-shared-secret $PRE_SHARED_SECRET
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS connection-type initiate
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS ike-group IKE0
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS local-address $LOCAL_ADDRESS
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS vti bind vti0
	$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS vti esp-group ESP0
	
	CONFIG_CHANGED=TRUE
else
	logger -t $NAME -- "Remote address does not change."
	
	VALIDATE_LOCAL_ADDRESS=$($WR show vpn ipsec site-to-site peer $REMOTE_ADDRESS local-address)
	CURRENT_LOCAL_ADDRESS=$(echo $VALIDATE_LOCAL_ADDRESS | grep -Pom 1 '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -n1)
	
	if [[ "$CURRENT_LOCAL_ADDRESS" != "$LOCAL_ADDRESS" ]]
	then
		logger -t $NAME -- "Local address change detected. Updating config."
		$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS description "CUSTOM_BY_SCRIPT"
		$WR set vpn ipsec site-to-site peer $REMOTE_ADDRESS local-address $LOCAL_ADDRESS
		
		CONFIG_CHANGED=TRUE
	else
		CONFIG_CHANGED=FALSE
		logger -t $NAME -- "Local address does not change."
	fi
fi

if [[ $CONFIG_CHANGED == TRUE ]]
then
	logger -t $NAME -- "Commit configuration."
	$WR commit
	$WR save
else
	logger -t $NAME -- "Nothing to commit."
fi

# End configuration
$WR end

exit 0