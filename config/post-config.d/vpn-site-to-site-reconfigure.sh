#!/bin/bash
# File: reconfigure-site-to-site.sh
# Author: ufozone
# Date: 2023-01-29
# Version: 0.2
# Desc: Site-to-Site VPN in Auto IPsec VTI mode does not detect a change of WAN IP address.
#       This script checks periodically the current WAN IP addresses of both sites and 
#       updates the configuration.

# Which site is this? A or B?
THIS_SITE="A"

# Hostnames of both sites as FQDN with final point
SITE_A_HOST="site-a.ddns.com."
SITE_B_HOST="site-b.ddns.com."

# Pre shared secret must be the same on both sites
PRE_SHARED_SECRET="e72abd600a90eb0e733b7c8c856690c95d02819e"


# DON'T CHANGE ANYTHING FROM THIS LINE
NAME="vpn-site-to-site-reconfigure"
WR="/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper"
if [[ "$THIS_SITE" == "A" ]]
then
	LOCAL_HOST=$SITE_A_HOST
	REMOTE_HOST=$SITE_B_HOST
else
	LOCAL_HOST=$SITE_B_HOST
	REMOTE_HOST=$SITE_A_HOST
fi

# begin configuration
$WR begin

# Check site-to-site configuration over path
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

VALIDATE_PEER=$($WR show vpn ipsec site-to-site peer $REMOTE_ADDRESS)
if [[ $(echo "$VALIDATE_PEER" | grep -i 'empty') ]]
then
	logger -t $NAME -- "New remote adress found or no site-to-site configured."
	VALIDATE_DELETE=$($WR delete vpn ipsec site-to-site)
	if [[ $(echo "$VALIDATE_DELETE" | grep -i 'nothing') ]]
	then
		logger -t $NAME -- "No site-to-site configuration found."
	else
		logger -t $NAME -- "Existing site-to-site configuration deleted."
	fi
	logger -t $NAME -- "Set up new site-to-site configuration."
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
