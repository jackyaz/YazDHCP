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
# Last Modified: Martinski W. [2023-Jan-28].
#---------------------------------------------------------

# shellcheck disable=SC2155

### Start of script variables ###
readonly SCRIPT_NAME="YazDHCP"
readonly SCRIPT_VERSION="v1.0.5"
SCRIPT_BRANCH="develop"
SCRIPT_REPO="https://jackyaz.io/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_CONF="$SCRIPT_DIR/DHCP_clients"
readonly SCRIPT_WEBPAGE_DIR="$(readlink /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://jackyaz.io/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
### End of output format variables ###

### Start of router environment variables ###
[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL=$(nvram get productid) || ROUTER_MODEL=$(nvram get odmpid)
### End of router environment variables ###

##----------------------------------------------##
## Added/modified by Martinski W. [2023-Jan-28] ##
##----------------------------------------------##
# DHCP Lease Time: Min & Max Values in seconds.
# 2 minutes=120 to 90 days=7776000 (inclusive).
# Single '0' or 'I' indicates "infinite" value.
# For NVRAM the "infinite" value (in secs.) is
# 1092 days (i.e. 156 weeks, or ~=3 years).
#------------------------------------------------#
readonly MinDHCPLeaseTime=120
readonly MaxDHCPLeaseTime=7776000
readonly InfiniteLeaseTimeTag="I"
readonly InfiniteLeaseTimeSecs=94348800
readonly YazDHCP_LEASEtag="DHCP_LEASE"
readonly DHCP_LEASE_FILE="DHCP_Lease"
readonly SCRIPT_DHCP_LEASE_CONF="${SCRIPT_DIR}/$DHCP_LEASE_FILE"

# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output(){
	if [ "$1" = "true" ]; then
		logger -t "$SCRIPT_NAME" "$2"
		printf "\\e[1m$3%s: $2\\e[0m\\n\\n" "$SCRIPT_NAME"
	else
		printf "\\e[1m$3%s: $2\\e[0m\\n\\n" "$SCRIPT_NAME"
	fi
}

Firmware_Version_Check(){
	if nvram get rc_support | grep -qF "am_addons"; then
		return 0
	else
		return 1
	fi
}

### Code for this function courtesy of https://github.com/decoderman- credit to @thelonelycoder ###
Firmware_Version_Number(){
	echo "$1" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}
############################################################################

### Code for these functions inspired by https://github.com/Adamm00 - credit to @Adamm ###
Check_Lock(){
	if [ -f "/tmp/$SCRIPT_NAME.lock" ]; then
		ageoflock=$(($(date +%s) - $(date +%s -r /tmp/$SCRIPT_NAME.lock)))
		if [ "$ageoflock" -gt 600 ]; then
			Print_Output true "Stale lock file found (>600 seconds old) - purging lock" "$ERR"
			kill "$(sed -n '1p' /tmp/$SCRIPT_NAME.lock)" >/dev/null 2>&1
			Clear_Lock
			echo "$$" > "/tmp/$SCRIPT_NAME.lock"
			return 0
		else
			Print_Output true "Lock file found (age: $ageoflock seconds) - stopping to prevent duplicate runs" "$ERR"
			if [ -z "$1" ]; then
				exit 1
			else
				if [ "$1" = "webui" ]; then
					exit 1
				fi
				return 1
			fi
		fi
	else
		echo "$$" > "/tmp/$SCRIPT_NAME.lock"
		return 0
	fi
}

Clear_Lock(){
	rm -f "/tmp/$SCRIPT_NAME.lock" 2>/dev/null
	return 0
}
############################################################################

Validate_IP(){
	if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
		for i in 1 2 3 4; do
			if [ "$(echo "$1" | cut -d. -f$i)" -gt 255 ]; then
				Print_Output false "Octet $i ($(echo "$1" | cut -d. -f$i)) - is invalid, must be less than 255" "$ERR"
				return 1
			fi
		done
	else
		Print_Output false "$1 - is not a valid IPv4 address, valid format is 1.2.3.4" "$ERR"
		return 1
	fi
}

##----------------------------------------------##
## Added/modified by Martinski W. [2023-Jan-28] ##
##----------------------------------------------##
# The DHCP Lease Time values can be given in:
# seconds, minutes, hours, days, or weeks.
# Single '0' or 'I' indicates "infinite" value.
#------------------------------------------------#
DHCP_LeaseValueToSeconds()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then echo "-1" ; return 1 ; fi

   timeUnits="X"  timeFactor=1  timeNumber="$1"

   if [ "$1" = "0" ] || [ "$1" = "$InfiniteLeaseTimeTag" ]
   then
      echo "$InfiniteLeaseTimeSecs" ; return 0
   fi

   if echo "$1" | grep -q "^[0-9]\{1,7\}$"
   then
		timeUnits="s"
		timeNumber="$1"
   elif echo "$1" | grep -q "^[0-9]\{1,6\}[smhdw]\{1\}$"
   then
		timeUnits="$(echo "$1" | awk '{print substr($0,length($0),1)}')"
		timeNumber="$(echo "$1" | awk '{print substr($0,0,length($0)-1)}')"
   fi

   case "$timeUnits" in
		s) timeFactor=1 ;;
		m) timeFactor=60 ;;
		h) timeFactor=3600 ;;
		d) timeFactor=86400 ;;
		w) timeFactor=604800 ;;
   esac

   if ! echo "$timeNumber" | grep -q "^[0-9]\{1,7\}$"
   then echo "-1" ; return 1 ; fi

   timeValue="$((timeNumber * timeFactor))"
   echo "$timeValue"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jan-28] ##
##----------------------------------------------##
Check_DHCP_LeaseTime()
{
   NVRAM_LeaseKey="dhcp_lease"
   NVRAM_LeaseTime="$(nvram get $NVRAM_LeaseKey)"

   if [ ! -f "$SCRIPT_DHCP_LEASE_CONF" ]
   then
      echo "## DO *NOT* EDIT THIS FILE. IT'S DYNAMICALLY UPDATED ##" > "$SCRIPT_DHCP_LEASE_CONF"
      echo "DHCP_LEASE=$NVRAM_LeaseTime" >> "$SCRIPT_DHCP_LEASE_CONF"
      return 0
   fi

   if ! grep -q "^DHCP_LEASE=" "$SCRIPT_DHCP_LEASE_CONF"
   then
      echo "DHCP_LEASE=$NVRAM_LeaseTime" >> "$SCRIPT_DHCP_LEASE_CONF"
      return 0
   fi

   LeaseValue="$(grep "^DHCP_LEASE=" "$SCRIPT_DHCP_LEASE_CONF" | awk -F '=' '{print $2}')"
   if [ -z "$LeaseValue" ]
   then
      sed -i "s/DHCP_LEASE=.*/DHCP_LEASE=$NVRAM_LeaseTime/" "$SCRIPT_DHCP_LEASE_CONF"
      return 0
   fi

   LeaseTime="$(DHCP_LeaseValueToSeconds "$LeaseValue")"

   if [ "$LeaseTime" = "$InfiniteLeaseTimeSecs" ] && \
      [ "$LeaseTime" != "$NVRAM_LeaseTime" ]
   then
      nvram set ${NVRAM_LeaseKey}="$LeaseTime"
      nvram commit
      return 0
   fi

   if [ "$LeaseTime" = "-1" ] || \
      [ "$LeaseTime" -lt "$MinDHCPLeaseTime" ] || \
      [ "$LeaseTime" -gt "$MaxDHCPLeaseTime" ] || \
      [ "$LeaseTime" -eq "$NVRAM_LeaseTime" ]
   then return 1 ; fi

   nvram set ${NVRAM_LeaseKey}="$LeaseTime"
   nvram commit
}

##----------------------------------------##
## Modified by Martinski W. [2023-Jan-28] ##
##----------------------------------------##
Conf_FromSettings(){
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TMPFILE="/tmp/yazdhcp_clients.tmp"
	if [ -f "$SETTINGSFILE" ]; then
		if [ "$(grep -E "yazdhcp_|^$YazDHCP_LEASEtag" $SETTINGSFILE | grep -v "version" -c)" -gt 0 ]; then
			Print_Output true "Updated DHCP information from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "$SCRIPT_CONF.bak"
			grep -E "yazdhcp_|^$YazDHCP_LEASEtag" "$SETTINGSFILE" | grep -v "version" > "$TMPFILE"
			sed -i "s/yazdhcp_//g;s/ /=/g" "$TMPFILE"
			DHCPCLIENTS=""
			while IFS='' read -r line || [ -n "$line" ]
			do
				if echo "$line" | grep -q "^${YazDHCP_LEASEtag}="
				then
					LEASE_VALUE="$(echo "$line" | cut -d '=' -f2)"
					sed -i "s/DHCP_LEASE=.*/DHCP_LEASE=$LEASE_VALUE/" "$SCRIPT_DHCP_LEASE_CONF"
					continue
				fi
				DHCPCLIENTS="${DHCPCLIENTS}$(echo "$line" | cut -f2 -d'=')"
			done < "$TMPFILE"
			
			echo "$DHCPCLIENTS" | sed 's/|/:/g;s/></\n/g;s/>/ /g;s/<//g' > /tmp/yazdhcp_clients_parsed.tmp
			
			echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"
			
			while IFS='' read -r line || [ -n "$line" ]; do
				if [ "$(echo "$line" | wc -w)" -eq 4 ]; then
					echo "$line" | awk '{ print ""$1","$2","$3","$4""; }' >> "$SCRIPT_CONF"
				elif [ "$(echo "$line" | wc -w)" -gt 1 ]; then
					if [ "$(echo "$line" | cut -d " " -f3 | wc -L)" -eq 0 ]; then
						echo "$line" | awk '{ print ""$1","$2","","$3""; }' >> "$SCRIPT_CONF"
					else
						printf "%s,\\n" "$(echo "$line" | sed 's/ /,/g')" >> "$SCRIPT_CONF"
					fi
				fi
			done < /tmp/yazdhcp_clients_parsed.tmp
			
			LANSUBNET="$(nvram get lan_ipaddr | cut -d'.' -f1-3)"
			LANNETMASK="$(nvram get lan_netmask)"
			if [ "$LANNETMASK" = "255.255.255.0" ]; then
				awk -F "," -v lansub="$LANSUBNET" 'FNR==1{print $0; next} BEGIN {OFS = ","} $2=lansub"."$2' "$SCRIPT_CONF" > "$SCRIPT_CONF.tmp"
			else
				cp "$SCRIPT_CONF" "$SCRIPT_CONF.tmp"
			fi
			sort -t . -k 3,3n -k 4,4n "$SCRIPT_CONF.tmp" > "$SCRIPT_CONF"
			rm -f "$SCRIPT_CONF.tmp"
			
			grep 'yazdhcp_version' "$SETTINGSFILE" > "$TMPFILE"
			sed -i "\\~yazdhcp_~d" "$SETTINGSFILE"
			sed -i "\\~${YazDHCP_LEASEtag}~d" "$SETTINGSFILE"
			mv "$SETTINGSFILE" "$SETTINGSFILE.bak"
			cat "$SETTINGSFILE.bak" "$TMPFILE" > "$SETTINGSFILE"
			rm -f /tmp/yazdhcp*
			rm -f "$SETTINGSFILE.bak"
			
			Check_DHCP_LeaseTime
			Update_Hostnames
			Update_Staticlist
			Update_Optionslist
			
			Print_Output true "Merge of updated DHCP client information from WebUI completed successfully" "$PASS"
		else
			Print_Output false "No updated DHCP information from WebUI found, no merge into $SCRIPT_CONF necessary" "$PASS"
		fi
	fi
}

Set_Version_Custom_Settings(){
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	case "$1" in
		local)
			if [ -f "$SETTINGSFILE" ]; then
				if [ "$(grep -c "yazdhcp_version_local" $SETTINGSFILE)" -gt 0 ]; then
					if [ "$SCRIPT_VERSION" != "$(grep "yazdhcp_version_local" /jffs/addons/custom_settings.txt | cut -f2 -d' ')" ]; then
						sed -i "s/yazdhcp_version_local.*/yazdhcp_version_local $SCRIPT_VERSION/" "$SETTINGSFILE"
					fi
				else
					echo "yazdhcp_version_local $SCRIPT_VERSION" >> "$SETTINGSFILE"
				fi
			else
				echo "yazdhcp_version_local $SCRIPT_VERSION" >> "$SETTINGSFILE"
			fi
		;;
		server)
			if [ -f "$SETTINGSFILE" ]; then
				if [ "$(grep -c "yazdhcp_version_server" $SETTINGSFILE)" -gt 0 ]; then
					if [ "$2" != "$(grep "yazdhcp_version_server" /jffs/addons/custom_settings.txt | cut -f2 -d' ')" ]; then
						sed -i "s/yazdhcp_version_server.*/yazdhcp_version_server $2/" "$SETTINGSFILE"
					fi
				else
					echo "yazdhcp_version_server $2" >> "$SETTINGSFILE"
				fi
			else
				echo "yazdhcp_version_server $2" >> "$SETTINGSFILE"
			fi
		;;
	esac
}

Update_Check(){
	echo 'var updatestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_update.js"
	doupdate="false"
	localver=$(grep "SCRIPT_VERSION=" /jffs/scripts/"$SCRIPT_NAME" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
	/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/404/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || { Print_Output true "404 error detected - stopping update" "$ERR"; return 1; }
	serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/version/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
	if [ "$localver" != "$serverver" ]; then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverver"
		echo 'var updatestatus = "'"$serverver"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 3 "$SCRIPT_REPO/md5/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ]; then
			doupdate="md5"
			Set_Version_Custom_Settings server "$serverver-hotfix"
			echo 'var updatestatus = "'"$serverver-hotfix"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
		fi
	fi
	if [ "$doupdate" = "false" ]; then
		echo 'var updatestatus = "None";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	fi
	echo "$doupdate,$localver,$serverver"
}

Update_Version(){
	if [ -z "$1" ] || [ "$1" = "unattended" ]; then
		updatecheckresult="$(Update_Check)"
		isupdate="$(echo "$updatecheckresult" | cut -f1 -d',')"
		localver="$(echo "$updatecheckresult" | cut -f2 -d',')"
		serverver="$(echo "$updatecheckresult" | cut -f3 -d',')"
		
		if [ "$isupdate" = "version" ]; then
			Print_Output true "New version of $SCRIPT_NAME available - updating to $serverver" "$PASS"
		elif [ "$isupdate" = "md5" ]; then
			Print_Output true "MD5 hash of $SCRIPT_NAME does not match - downloading updated $serverver" "$PASS"
		fi
		
		Update_File shared-jy.tar.gz
		
		if [ "$isupdate" != "false" ]; then
			Update_File Advanced_DHCP_Content.asp
			
			Download_File "$SCRIPT_REPO/update/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && Print_Output true "$SCRIPT_NAME successfully updated"
			chmod 0755 /jffs/scripts/"$SCRIPT_NAME"
			Clear_Lock
			if [ -z "$1" ]; then
				exec "$0" setversion
			elif [ "$1" = "unattended" ]; then
				exec "$0" setversion unattended
			fi
			exit 0
		else
			Print_Output true "No new version - latest is $localver" "$WARN"
			Clear_Lock
		fi
	fi
	
	if [ "$1" = "force" ]; then
		serverver=$(/usr/sbin/curl -fsL --retry 3 "$SCRIPT_REPO/version/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})')
		Print_Output true "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
		Update_File Advanced_DHCP_Content.asp
		Update_File shared-jy.tar.gz
		Download_File "$SCRIPT_REPO/update/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && Print_Output true "$SCRIPT_NAME successfully updated"
		chmod 0755 /jffs/scripts/"$SCRIPT_NAME"
		Clear_Lock
		if [ -z "$2" ]; then
			exec "$0" setversion
		elif [ "$2" = "unattended" ]; then
			exec "$0" setversion unattended
		fi
		exit 0
	fi
}

Update_File(){
	if [ "$1" = "Advanced_DHCP_Content.asp" ]; then
		tmpfile="/tmp/$1"
		Download_File "$SCRIPT_REPO/files/$1" "$tmpfile"
		if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1; then
			Download_File "$SCRIPT_REPO/files/$1" "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
		rm -f "$tmpfile"
	elif [ "$1" = "shared-jy.tar.gz" ]; then
		if [ ! -f "$SHARED_DIR/$1.md5" ]; then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/$1.md5")"
			remotemd5="$(curl -fsL --retry 3 "$SHARED_REPO/$1.md5")"
			if [ "$localmd5" != "$remotemd5" ]; then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
				tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
				rm -f "$SHARED_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
			fi
		fi
	else
		return 1
	fi
}

Create_Dirs(){
	if [ ! -d "$SCRIPT_DIR" ]; then
		mkdir -p "$SCRIPT_DIR"
	fi
	
	if [ ! -d "$SHARED_DIR" ]; then
		mkdir -p "$SHARED_DIR"
	fi
	
	if [ ! -d "$SCRIPT_WEBPAGE_DIR" ]; then
		mkdir -p "$SCRIPT_WEBPAGE_DIR"
	fi
	
	if [ ! -d "$SCRIPT_WEB_DIR" ]; then
		mkdir -p "$SCRIPT_WEB_DIR"
	fi
}

##-------------------------------------##
## Added by Martinski W. [2023-Jan-28] ##
##-------------------------------------##
Create_DHCP_LeaseConfig()
{
   Check_DHCP_LeaseTime
   ln -s "$SCRIPT_DHCP_LEASE_CONF" "${SCRIPT_WEB_DIR}/${DHCP_LEASE_FILE}.htm" 2>/dev/null
}

##----------------------------------------##
## Modified by Martinski W. [2023-Jan-28] ##
##----------------------------------------##
Create_Symlinks(){
	rm -rf "${SCRIPT_WEB_DIR:?}/"* 2>/dev/null
	
	ln -s "$SCRIPT_CONF" "$SCRIPT_WEB_DIR/DHCP_clients.htm" 2>/dev/null
	Create_DHCP_LeaseConfig

	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

Auto_ServiceEvent(){
	case $1 in
		create)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				# shellcheck disable=SC2016
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME service_event"' "$@" & # '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					# shellcheck disable=SC2016
					echo "/jffs/scripts/$SCRIPT_NAME service_event"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/service-event
				echo "" >> /jffs/scripts/service-event
				# shellcheck disable=SC2016
				echo "/jffs/scripts/$SCRIPT_NAME service_event"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				chmod 0755 /jffs/scripts/service-event
			fi
		;;
		delete)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
			fi
		;;
	esac
}

Auto_Startup(){
	case $1 in
		create)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/services-start
				echo "" >> /jffs/scripts/services-start
				echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				chmod 0755 /jffs/scripts/services-start
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
		;;
	esac
}

Auto_DNSMASQ(){
	case $1 in
		create)
			if [ -f /jffs/configs/dnsmasq.conf.add ]; then
				CONFCHANGED="false"
				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_hostnames" /jffs/configs/dnsmasq.conf.add)
				STARTUPLINECOUNTEX=$(grep -cx "addn-hosts=$SCRIPT_DIR/.hostnames # ${SCRIPT_NAME}_hostnames" /jffs/configs/dnsmasq.conf.add)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"${SCRIPT_NAME}_hostnames"'/d' /jffs/configs/dnsmasq.conf.add
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "addn-hosts=$SCRIPT_DIR/.hostnames # ${SCRIPT_NAME}_hostnames" >> /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi
				
				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_staticlist" /jffs/configs/dnsmasq.conf.add)
				STARTUPLINECOUNTEX=$(grep -cx "dhcp-hostsfile=$SCRIPT_DIR/.staticlist # ${SCRIPT_NAME}_staticlist" /jffs/configs/dnsmasq.conf.add)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"${SCRIPT_NAME}_staticlist"'/d' /jffs/configs/dnsmasq.conf.add
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "dhcp-hostsfile=$SCRIPT_DIR/.staticlist # ${SCRIPT_NAME}_staticlist" >> /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi
				
				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_optionslist" /jffs/configs/dnsmasq.conf.add)
				STARTUPLINECOUNTEX=$(grep -cx "dhcp-optsfile=$SCRIPT_DIR/.optionslist # ${SCRIPT_NAME}_optionslist" /jffs/configs/dnsmasq.conf.add)
				
				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"${SCRIPT_NAME}_optionslist"'/d' /jffs/configs/dnsmasq.conf.add
				fi
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "dhcp-optsfile=$SCRIPT_DIR/.optionslist # ${SCRIPT_NAME}_optionslist" >> /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi
				
				if [ "$CONFCHANGED" = "true" ]; then
					service restart_dnsmasq >/dev/null 2>&1
				fi
			else
				{ echo ""; echo "addn-hosts=$SCRIPT_DIR/.hostnames # ${SCRIPT_NAME}_hostnames"; echo "dhcp-hostsfile=$SCRIPT_DIR/.staticlist # ${SCRIPT_NAME}_staticlist"; echo "dhcp-optsfile=$SCRIPT_DIR/.optionslist # ${SCRIPT_NAME}_optionslist"; } >> /jffs/configs/dnsmasq.conf.add
				chmod 0644 /jffs/configs/dnsmasq.conf.add
				service restart_dnsmasq >/dev/null 2>&1
			fi
		;;
		delete)
			if [ -f /jffs/configs/dnsmasq.conf.add ]; then
				CONFCHANGED="false"
				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_hostnames" /jffs/configs/dnsmasq.conf.add)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_hostnames"'/d' /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi
				
				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_staticlist" /jffs/configs/dnsmasq.conf.add)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_staticlist"'/d' /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi
				
				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_optionslist" /jffs/configs/dnsmasq.conf.add)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_optionslist"'/d' /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi
				
				if [ "$CONFCHANGED" = "true" ]; then
					service restart_dnsmasq >/dev/null 2>&1
				fi
			fi
		;;
	esac
}

Download_File(){
	/usr/sbin/curl -fsL --retry 3 "$1" -o "$2"
}

Mount_WebUI(){
	umount /www/Advanced_DHCP_Content.asp 2>/dev/null
	mount -o bind "$SCRIPT_DIR/Advanced_DHCP_Content.asp" /www/Advanced_DHCP_Content.asp
}

Shortcut_Script(){
	case $1 in
		create)
			if [ -d /opt/bin ] && [ ! -f "/opt/bin/$SCRIPT_NAME" ] && [ -f "/jffs/scripts/$SCRIPT_NAME" ]; then
				ln -s /jffs/scripts/"$SCRIPT_NAME" /opt/bin
				chmod 0755 /opt/bin/"$SCRIPT_NAME"
			fi
		;;
		delete)
			if [ -f "/opt/bin/$SCRIPT_NAME" ]; then
				rm -f /opt/bin/"$SCRIPT_NAME"
			fi
		;;
	esac
}

PressEnter(){
	while true; do
		printf "Press enter to continue..."
		read -r key
		case "$key" in
			*)
				break
			;;
		esac
	done
	return 0
}

### nvram parsing code based on dhcpstaticlist.sh by @Xentrk ###
Export_FW_DHCP_JFFS(){
	printf "\\n\\e[1mDo you want to export DHCP assignments and hostnames from nvram to %s DHCP client files? (y/n)\\e[0m\\n" "$SCRIPT_NAME"
	printf "%s will backup nvram/jffs DHCP data as part of the export\\n" "$SCRIPT_NAME"
	printf "\\n\\e[1mEnter answer (y/n):    \\e[0m"
	read -r confirm
	case "$confirm" in
		y|Y)
			:
		;;
		*)
			return 1
		;;
	esac
	
	if [ "$(nvram get dhcp_staticlist | wc -m)" -le 1 ]; then
		Print_Output true "DHCP static assignmnents not exported from nvram, no data found" "$PASS"
		Clear_Lock
		return 1
	fi
	
	if [ "$(Firmware_Version_Number "$(nvram get buildno)")" -lt "$(Firmware_Version_Number 386.4)" ]; then
		if [ -f /jffs/nvram/dhcp_hostnames ]; then
			if [ "$(wc -m < /jffs/nvram/dhcp_hostnames)" -le 1 ]; then
				Print_Output true "DHCP hostnames not exported from nvram, no data found" "$PASS"
				Clear_Lock
				return 1
			fi
		elif [ "$(nvram get dhcp_hostnames | wc -m)" -le 1 ]; then
			Print_Output true "DHCP hostnames not exported from nvram, no data found" "$PASS"
			Clear_Lock
			return 1
		fi
		
		if [ -f /jffs/nvram/dhcp_staticlist ]; then
			sed 's/</\n/g;s/>/ /g;s/<//g' /jffs/nvram/dhcp_staticlist | sed '/^$/d' > /tmp/yazdhcp-ips.tmp
		else
			nvram get dhcp_staticlist | sed 's/</\n/g;s/>/ /g;s/<//g'| sed '/^$/d' > /tmp/yazdhcp-ips.tmp
		fi
		
		if [ -f /jffs/nvram/dhcp_hostnames ]; then
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
			MAC=$(echo "$HOST" | cut -d ">" -f1)
			HOSTNAME=$(echo "$HOST" | cut -d ">" -f2)
			echo "$MAC $HOSTNAME" >> /tmp/yazdhcp-hosts.tmp
		done
		
		IFS=$OLDIFS
		
		sed -i 's/ $//' /tmp/yazdhcp-ips.tmp
		sed -i 's/ $//' /tmp/yazdhcp-hosts.tmp
		
		awk 'NR==FNR { k[$1]=$2; next } { print $0, k[$1] }' /tmp/yazdhcp-hosts.tmp /tmp/yazdhcp-ips.tmp > /tmp/yazdhcp.tmp
		
		echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"
		sort -t . -k 3,3n -k 4,4n /tmp/yazdhcp.tmp > /tmp/yazdhcp_sorted.tmp
		
		while IFS='' read -r line || [ -n "$line" ]; do
			if [ "$(echo "$line" | wc -w)" -eq 4 ]; then
				echo "$line" | awk '{ print ""$1","$2","$4","$3""; }' >> "$SCRIPT_CONF"
			else
				if ! Validate_IP "$(echo "$line" | cut -d " " -f3)" >/dev/null 2>&1; then
					printf "%s,\\n" "$(echo "$line" | sed 's/ /,/g')" >> "$SCRIPT_CONF"
				else
					echo "$line" | awk '{ print ""$1","$2","","$3""; }' >> "$SCRIPT_CONF"
				fi
			fi
		done < /tmp/yazdhcp_sorted.tmp
		
		rm -f /tmp/yazdhcp*.tmp
		
		if [ -f /jffs/nvram/dhcp_hostnames ]; then
			cp /jffs/nvram/dhcp_hostnames "$SCRIPT_DIR/.nvram_jffs_dhcp_hostnames"
			rm -f /jffs/nvram/dhcp_hostnames
		fi
		nvram get dhcp_hostnames > "$SCRIPT_DIR/.nvram_dhcp_hostnames"
		nvram unset dhcp_hostnames
	else
		if [ -f /jffs/nvram/dhcp_staticlist ]; then
			sed 's/</\n/g;s/>/|/g;s/<//g' /jffs/nvram/dhcp_staticlist | sed '/^$/d' > /tmp/yazdhcp.tmp
		else
			nvram get dhcp_staticlist | sed 's/</\n/g;s/>/|/g;s/<//g'| sed '/^$/d' > /tmp/yazdhcp.tmp
		fi
		
		echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"
		sort -t . -k 3,3n -k 4,4n /tmp/yazdhcp.tmp > /tmp/yazdhcp_sorted.tmp
		
		while IFS='' read -r line || [ -n "$line" ]; do
			echo "$line" | awk 'FS="|" { print ""$1","$2","$4","$3""; }' >> "$SCRIPT_CONF"
		done < /tmp/yazdhcp_sorted.tmp
		
		rm -f /tmp/yazdhcp*.tmp
	fi
	
	if [ -f /jffs/nvram/dhcp_staticlist ]; then
		cp /jffs/nvram/dhcp_staticlist "$SCRIPT_DIR/.nvram_jffs_dhcp_staticlist"
	fi
	nvram get dhcp_staticlist > "$SCRIPT_DIR/.nvram_dhcp_staticlist"
	nvram unset dhcp_staticlist
	
	nvram commit
	
	Print_Output true "DHCP information successfully exported from nvram" "$PASS"
	
	Update_Hostnames
	Update_Staticlist
	Update_Optionslist
	
	Clear_Lock
}
##################################################################

Update_Hostnames(){
	existingmd5=""
	if [ -f "$SCRIPT_DIR/.hostnames" ]; then
		existingmd5="$(md5sum "$SCRIPT_DIR/.hostnames" | awk '{print $1}')"
	fi
	tail -n +2 "$SCRIPT_CONF" | awk -F',' '$3 != "" { print ""$2" "$3""; }' > "$SCRIPT_DIR/.hostnames"
	
	updatedmd5="$(md5sum "$SCRIPT_DIR/.hostnames" | awk '{print $1}')"
	if [ "$existingmd5" != "$updatedmd5" ]; then
		Print_Output true "DHCP hostname list updated successfully" "$PASS"
		service restart_dnsmasq >/dev/null 2>&1
	else
		Print_Output true "DHCP hostname list unchanged" "$WARN"
	fi
}

Update_Staticlist(){
	existingmd5=""
	if [ -f "$SCRIPT_DIR/.staticlist" ]; then
		existingmd5="$(md5sum "$SCRIPT_DIR/.staticlist" | awk '{print $1}')"
	fi
	tail -n +2 "$SCRIPT_CONF" | awk -F',' '{ print ""$1",set:"$1","$2""; }' > "$SCRIPT_DIR/.staticlist"
	updatedmd5="$(md5sum "$SCRIPT_DIR/.staticlist" | awk '{print $1}')"
	if [ "$existingmd5" != "$updatedmd5" ]; then
		Print_Output true "DHCP static assignment list updated successfully" "$PASS"
		service restart_dnsmasq >/dev/null 2>&1
	else
		Print_Output true "DHCP static assignment list unchanged" "$WARN"
	fi
}

Update_Optionslist(){
	existingmd5=""
	if [ -f "$SCRIPT_DIR/.optionslist" ]; then
		existingmd5="$(md5sum "$SCRIPT_DIR/.optionslist" | awk '{print $1}')"
	fi
	tail -n +2 "$SCRIPT_CONF" | awk -F',' '$4 != "" { print "tag:"$1",6,"$4""; }' > "$SCRIPT_DIR/.optionslist"
	updatedmd5="$(md5sum "$SCRIPT_DIR/.optionslist" | awk '{print $1}')"
	if [ "$existingmd5" != "$updatedmd5" ]; then
		Print_Output true "DHCP options list updated successfully" "$PASS"
		service restart_dnsmasq >/dev/null 2>&1
	else
		Print_Output true "DHCP options list unchanged" "$WARN"
	fi
}

ScriptHeader(){
	clear
	printf "\\n"
	printf "\\e[1m##########################################################\\e[0m\\n"
	printf "\\e[1m##                                                      ##\\e[0m\\n"
	printf "\\e[1m##  __     __          _____   _    _   _____  _____    ##\\e[0m\\n"
	printf "\\e[1m##  \ \   / /         |  __ \ | |  | | / ____||  __ \   ##\\e[0m\\n"
	printf "\\e[1m##   \ \_/ /__ _  ____| |  | || |__| || |     | |__) |  ##\\e[0m\\n"
	printf "\\e[1m##    \   // _  ||_  /| |  | ||  __  || |     |  ___/   ##\\e[0m\\n"
	printf "\\e[1m##     | || (_| | / / | |__| || |  | || |____ | |       ##\\e[0m\\n"
	printf "\\e[1m##     |_| \__,_|/___||_____/ |_|  |_| \_____||_|       ##\\e[0m\\n"
	printf "\\e[1m##                                                      ##\\e[0m\\n"
	printf "\\e[1m##                 %s on %-9s                  ##\\e[0m\\n" "$SCRIPT_VERSION" "$ROUTER_MODEL"
	printf "\\e[1m##                                                      ##\\e[0m\\n"
	printf "\\e[1m##           https://github.com/jackyaz/%s         ##\\e[0m\\n" "$SCRIPT_NAME"
	printf "\\e[1m##                                                      ##\\e[0m\\n"
	printf "\\e[1m##########################################################\\e[0m\\n"
	printf "\\n"
}

MainMenu(){
	printf "1.    Process %s\\n\\n" "$SCRIPT_CONF"
	showexport="true"
	if [ "$(nvram get dhcp_staticlist | wc -m)" -le 1 ]; then
		showexport="false"
	fi
	if [ -f /jffs/nvram/dhcp_hostnames ]; then
		if [ "$(wc -m < /jffs/nvram/dhcp_hostnames)" -le 1 ]; then
			showexport="false"
		fi
	elif [ "$(nvram get dhcp_hostnames | wc -m)" -le 1 ]; then
		showexport="false"
	fi
	if [ "$showexport" = "true" ]; then
		printf "x.    Export nvram to %s\\n\\n" "$SCRIPT_NAME"
	fi
	printf "u.    Check for updates\\n"
	printf "uf.   Update %s with latest version (force update)\\n\\n" "$SCRIPT_NAME"
	printf "e.    Exit %s\\n\\n" "$SCRIPT_NAME"
	printf "z.    Uninstall %s\\n" "$SCRIPT_NAME"
	printf "\\n"
	printf "\\e[1m##########################################################\\e[0m\\n"
	printf "\\n"
	
	while true; do
		printf "Choose an option:    "
		read -r menu
		case "$menu" in
			1)
				printf "\\n"
				if Check_Lock menu; then
					Menu_ProcessDHCPClients
				fi
				PressEnter
				break
			;;
			x)
				printf "\\n"
				if Check_Lock menu; then
					Export_FW_DHCP_JFFS
				fi
				PressEnter
				break
			;;
			u)
				printf "\\n"
				if Check_Lock menu; then
					Menu_Update
				fi
				PressEnter
				break
			;;
			uf)
				printf "\\n"
				if Check_Lock menu; then
					Menu_ForceUpdate
				fi
				PressEnter
				break
			;;
			e)
				ScriptHeader
				printf "\\n\\e[1mThanks for using %s!\\e[0m\\n\\n\\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true; do
					printf "\\n\\e[1mAre you sure you want to uninstall %s? (y/n)\\e[0m\\n" "$SCRIPT_NAME"
					read -r confirm
					case "$confirm" in
						y|Y)
							Menu_Uninstall
							exit 0
						;;
						*)
							break
						;;
					esac
				done
				break
			;;
			*)
				printf "\\nPlease choose a valid option\\n\\n"
			;;
		esac
	done
	
	ScriptHeader
	MainMenu
}

Menu_Install(){
	Print_Output true "Welcome to $SCRIPT_NAME $SCRIPT_VERSION, a script by JackYaz"
	sleep 1
	
	Print_Output true "Checking your router meets the requirements for $SCRIPT_NAME"
	
	if ! Check_Requirements; then
		Print_Output true "Requirements for $SCRIPT_NAME not met, please see above for the reason(s)" "$CRIT"
		PressEnter
		Clear_Lock
		rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
		exit 1
	fi
	
	Create_Dirs
	Set_Version_Custom_Settings local
	Set_Version_Custom_Settings server "$SCRIPT_VERSION"
	Create_Symlinks
	
	httpstring="https"
	portstring=":$(nvram get https_lanport)"
	
	if [ "$(nvram get http_enable)" -eq 0 ]; then
		httpstring="http"
		portstring=""
	fi
	printf "%s will backup nvram/jffs DHCP data as part of the export, but you may wish to screenshot %s://%s%s/Advanced_DHCP_Content.asp\\e[0m\\n" "$SCRIPT_NAME" "$httpstring" "$(nvram get lan_ipaddr)" "$portstring"
	printf "\\n\\e[1mIf you wish to screenshot, please do so now as the WebUI page will be updated by %s\\e[0m\\n" "$SCRIPT_NAME"
	printf "\\n\\e[1mPress any key when you are ready to continue\\e[0m\\n"
	while true; do
		read -r key
		case "$key" in
			*)
				break
			;;
		esac
	done
	
	Update_File Advanced_DHCP_Content.asp
	Update_File shared-jy.tar.gz
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Auto_DNSMASQ create 2>/dev/null
	Shortcut_Script create
	
	echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"
	
	Export_FW_DHCP_JFFS
	
	Print_Output true "$SCRIPT_NAME installed successfully!" "$PASS"
	
	Clear_Lock
}

Menu_ProcessDHCPClients(){
	Update_Hostnames
	Update_Staticlist
	Update_Optionslist
	
	Clear_Lock
}

Menu_Startup(){
	Create_Dirs
	Set_Version_Custom_Settings "local"
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Auto_DNSMASQ create 2>/dev/null
	Shortcut_Script create
	Mount_WebUI
	Clear_Lock
}

Menu_Update(){
	Update_Version
	Clear_Lock
}

Menu_ForceUpdate(){
	Update_Version force
	Clear_Lock
}

Menu_Uninstall(){
	Print_Output true "Removing $SCRIPT_NAME..." "$PASS"
	Auto_Startup delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	Auto_DNSMASQ delete 2>/dev/null
	Shortcut_Script delete
	umount /www/Advanced_DHCP_Content.asp 2>/dev/null
	rm -f "$SCRIPT_DIR/Advanced_DHCP_Content.asp"
	
	printf "\\n\\e[1mDo you want to restore the original nvram values from before %s was installed? (y/n):    \\e[0m" "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			if [ -f "$SCRIPT_DIR/.nvram_jffs_dhcp_staticlist" ]; then
				nvram set dhcp_staticlist="$(cat "$SCRIPT_DIR/.nvram_jffs_dhcp_staticlist")"
			fi
			
			if [ -f "$SCRIPT_DIR/.nvram_jffs_dhcp_hostnames" ]; then
				nvram set dhcp_hostnames="$(cat "$SCRIPT_DIR/.nvram_jffs_dhcp_hostnames")"
			fi
			
			if [ -f "$SCRIPT_DIR/.nvram_dhcp_staticlist" ]; then
				nvram set dhcp_staticlist="$(cat "$SCRIPT_DIR/.nvram_dhcp_staticlist")"
			fi
			
			if [ -f "$SCRIPT_DIR/.nvram_dhcp_hostnames" ]; then
				nvram set dhcp_hostnames="$(cat "$SCRIPT_DIR/.nvram_dhcp_hostnames")"
			fi
			
			nvram commit
		;;
		*)
			:
		;;
	esac
	
	printf "\\n\\e[1mDo you want to delete %s DHCP clients and nvram backup files? (y/n):    \\e[0m" "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			rm -rf "$SCRIPT_DIR" 2>/dev/null
		;;
		*)
			:
		;;
	esac
	
	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null
	rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
	Clear_Lock
	Print_Output true "Uninstall completed" "$PASS"
}

Check_Requirements(){
	CHECKSFAILED="false"
	
	if [ "$(nvram get jffs2_scripts)" -ne 1 ]; then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output true "Custom JFFS Scripts enabled" "$WARN"
	fi
	
	if ! Firmware_Version_Check; then
		Print_Output true "Unsupported firmware version detected" "$ERR"
		Print_Output true "$SCRIPT_NAME requires Merlin 384.15/384.13_4 or Fork 43E5 (or later)" "$ERR"
		CHECKSFAILED="true"
	fi
	
	if [ "$CHECKSFAILED" = "false" ]; then
		return 0
	else
		return 1
	fi
}

if [ -z "$1" ]; then
	Create_Dirs
	Set_Version_Custom_Settings local
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Auto_DNSMASQ create 2>/dev/null
	Shortcut_Script create
	ScriptHeader
	MainMenu
	exit 0
fi

case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	startup)
		Check_Lock
		if [ "$2" != "force" ]; then
			sleep 5
		fi
		Menu_Startup
		exit 0
	;;
	service_event)
		if [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME" ]; then
			Conf_FromSettings
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}checkupdate" ]; then
			Update_Check
			exit 0
		elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}doupdate" ]; then
			Update_Version force unattended
			exit 0
		fi
		exit 0
	;;
	update)
		Update_Version unattended
		exit 0
	;;
	forceupdate)
		Update_Version force unattended
		exit 0
	;;
	setversion)
		Set_Version_Custom_Settings local
		Set_Version_Custom_Settings server "$SCRIPT_VERSION"
		if [ -z "$2" ]; then
			exec "$0"
		fi
		exit 0
	;;
	checkupdate)
		Update_Check
		exit 0
	;;
	uninstall)
		Check_Lock
		Menu_Uninstall
		exit 0
	;;
	develop)
		SCRIPT_BRANCH="develop"
		SCRIPT_REPO="https://jackyaz.io/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	stable)
		SCRIPT_BRANCH="master"
		SCRIPT_REPO="https://jackyaz.io/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	*)
		echo "Command not recognised, please try again"
		exit 1
	;;
esac
