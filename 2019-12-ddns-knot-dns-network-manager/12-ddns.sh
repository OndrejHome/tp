#!/bin/sh
## == configurable variables == BEGIN
MONITORED_DEVICE=""
TSIG_STRING=""
DNS_SERVER=""
DNS_HOSTNAME=""
## == configurable variables == END

if [ "$1" != "$MONITORED_DEVICE" ] || [ "$2" != "dhcp4-change" ] && [ "$2" != "up" ]
then
    # if we have not matched the MONITORED_DEVICE or 
    # if the action was not the change of IP address, then lets quietly exit
    exit 0;
fi
# we have matched the event that IP was changed (or aquired) from DHCP
# first lets make sure we have tool to send updated IP to DNS
if ! command -v nsupdate >/dev/null; then
	logger "ddns: Missing 'nsupdate' command: NOT updating DNS."
	exit 0;
fi

# get IP address that we have set previously (this will be empty if run first time)
IP_OLD=$(cat /run/NetworkManager/current_ipv4 2>/dev/null)
# extract IPv4 address
IP=$(echo "$IP4_ADDRESS_0"|cut -d/ -f1)

# check if IPv4 address changed from previous time, continue only if htere was change
# (or when this is the first time running = when IP_OLD is empty
if [ "$IP_OLD" = "$IP" ]; then
    logger "ddns: No change in IP address, not updating DNS."
    exit 0
fi

# update IPv4 into DNS
logger "ddns: Attempting to update IP to '$IP'."
nsupdate -y "$TSIG_STRING" <<EOF
server $DNS_SERVER
update delete $DNS_HOSTNAME a
update add $DNS_HOSTNAME 300 a $IP 
send
EOF

# store updated IPv4 address in temporary localfile so we skip update on DHCP refresh for same IP
echo "$IP" > /run/NetworkManager/current_ipv4
