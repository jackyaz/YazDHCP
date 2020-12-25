#!/bin/sh

##########################################################
##                                                      ##
##  __     __          _____   _    _   _____  _____    ##
##  \ \   / /         |  __ \ | |  | | / ____||  __ \   ##
##   \ \_/ /__ _  ____| |  | || |__| || |     | |__) |  ##
##    \   // _` ||_  /| |  | ||  __  || |     |  ___/   ##
##     | || (_| | / / | |__| || |  | || |____ | |       ##
##     |_| \__,_|/___||_____/ |_|  |_| \_____||_|       ##
##                                                      ##
##         https://github.com/jackyaz/YazDHCP/          ##
##                                                      ##
##########################################################

### Start of script variables ###
readonly SCRIPT_NAME="YazDHCP"
readonly SCRIPT_CONF="/jffs/addons/$SCRIPT_NAME.d/config"
readonly SCRIPT_VERSION="v0.0.1"
readonly SCRIPT_BRANCH="master"
readonly SCRIPT_REPO="https://raw.githubusercontent.com/jackyaz/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_WEBPAGE_DIR="$(readlink /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/jackyaz/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
### End of output format variables ###

### Start of router environment variables ###
readonly LAN="$(nvram get lan_ipaddr)"
[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL=$(nvram get productid) || ROUTER_MODEL=$(nvram get odmpid)
### End of router environment variables ###

### Start of path variables ###
readonly DNSCONF="/jffs/configs/dnsmasq.conf.add"
readonly TMPCONF="/jffs/configs/tmpdnsmasq.conf.add"
### End of path variables ###

# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME" "$2"
		printf "\\e[1m$3%s: $2\\e[0m\\n\\n" "$SCRIPT_NAME"
	else
		printf "\\e[1m$3%s: $2\\e[0m\\n\\n" "$SCRIPT_NAME"
	fi
}

### nvram parsing code based on dhcpstaticlist.sh by @Xentrk ###
Export_FW_DHCP_JFFS(){
	if [ "$(/bin/uname -m)" = "aarch64" ]; then
		sed 's/></\n/g;s/>/ /g;s/<//g' /jffs/nvram/dhcp_staticlist > /tmp/yazdhcp-ips.tmp
	else
		nvram get dhcp_staticlist | sed 's/></\n/g;s/>/ /g;s/<//g' > /tmp/yazdhcp-ips.tmp
	fi
	
	if [ "$(/bin/uname -m)" = "aarch64" ]; then
		HOSTNAME_LIST=$(sed 's/>undefined//' /jffs/nvram/dhcp_hostnames)
	else
		HOSTNAME_LIST=$(nvram get dhcp_hostnames | sed 's/>undefined//')
	fi
	
	OLDIFS=$IFS
	IFS="<"
	
	for HOST in $HOSTNAME_LIST; do
		if [ "$HOST" = "" ]; then
			continue
		fi
		MAC=$(echo "$HOST" | cut -d ">" -f 1)
		HOSTNAME=$(echo "$HOST" | cut -d ">" -f 2)
		echo "$MAC $HOSTNAME" >> /tmp/yazdhcp-hosts.tmp
	done
	
	IFS=$OLDIFS
	
	awk 'NR==FNR { k[$1]=$2; next } { print $0, k[$1] }' /tmp/yazdhcp-hosts.tmp /tmp/yazdhcp-ips.tmp > /tmp/yazdhcp.tmp
	
	sort -t . -k 3,3n -k 4,4n /tmp/yazdhcp.tmp | awk '{ print "dhcp-host="$1","$2","$3""; }' | sed 's/,$//'
	
	rm -f /tmp/yazdhcp*.tmp
}
##############
