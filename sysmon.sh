#!/bin/bash

# 
# Monitor System Usage and notify through ElementarySMS API
#
# Copyright 2015 (c) Sorin Pohontu
# Support/FeedBack:  http://www.frontline.ro
#
#
# License: GNU GENERAL PUBLIC LICENSE version 2.0. 
#

#
# Tested on: 
# - Debian Linux 7.0

NOTIFY_LOAD=0.50
NOTIFY_POSTFIX=1
NOTIFY_POSTFIX_DEFFERED=5

# Load ElementarySMS Configuration
ELEMENTARY_CONF="$(dirname $0)"/elementary.conf

if [ ! -f "$ELEMENTARY_CONF" ]; then
	echo 'ElementarySMS API Configuration Not Found !'
	exit
else
	. "$ELEMENTARY_CONF"
fi

# Variables
VAR_FILE='/tmp/sysmon.var'
CR='\n'

# Check if VARFILE exists
if [ ! -f "$VAR_FILE" ]; then
	# Init previous values
	LOAD_PREV=0.00
	POSTFIX_DEFFERED_PREV=0
else
	# Load previous values
	. "$VAR_FILE"
fi

# Create a temporary message file
MESSAGEFILE="$(mktemp)"

#
# Functions
#
# Sends SMS using ElementarySMS API
#
function sendSMS {
	MACHINE=`hostname -s`
	
	/usr/bin/curl -H "Content-Type: application/json" -X POST \
	--data-binary '{"api-key" : "'$ELEMENTARYSMS_API_KEY'", "number" : "'$NOTIFY_NUMBER'", "message" : "['${MACHINE}']: '"$1"'"}' \
	"$ELEMENTARYSMS_API_URL"/message/add
}

#
# 01. Check System Load
#
# Read Current Average 5 Minutes System Load
#
LOAD="$(uptime | awk -F 'load average:' '{ print $2 }' | cut -d, -f2 | sed 's/ //g')"

# Check if 5 Min System Load is greater than NOTIFY_LOAD
if [ $(expr ${LOAD} \> ${NOTIFY_LOAD}) -eq 1 ]; then
	# Check if 5 Min System Load is greater than previous value
	if [ $(expr ${LOAD} \> ${LOAD_PREV}) -eq 1 ]; then
		printf "System Load [%s] for last 5 minutes is beyond notification limit (%s) !" "$LOAD" "$NOTIFY_LOAD" >> $MESSAGEFILE
	fi
fi
# Save current variable values
echo LOAD_PREV="${LOAD}" > $VAR_FILE

#
# 02. Check Postfix Deffered Queue Size
#
#
if [ "$NOTIFY_POSTFIX" -eq 1 ]; then
	POSTFIX_DEFFERED="$(find /var/spool/postfix/deferred -ignore_readdir_race -nowarn -type f | wc -l)"
	
	# Check if Postfix Defferred Queue Size is greater than NOTIFY_POSTFIX_DEFFERED
	if [ $(expr ${POSTFIX_DEFFERED} \> ${NOTIFY_POSTFIX_DEFFERED}) -eq 1 ]; then
		# Check if Postfix Defferred Queue Size is greater than previous value
		if [ $(expr ${POSTFIX_DEFFERED} \> ${POSTFIX_DEFFERED_PREV}) -eq 1 ]; then
			# Add New Line / Separator
			if [ -s "$MESSAGEFILE" ]; then
				printf "%s%s" "$CR" "$CR" >> $MESSAGEFILE
			fi
			printf "Mail Defferred Queue Size [%s] is beyond notification limit (%s) !" "$POSTFIX_DEFFERED" "$NOTIFY_POSTFIX_DEFFERED" >> $MESSAGEFILE
		fi
	fi
	# Save current variable values
	echo POSTFIX_DEFFERED_PREV="${POSTFIX_DEFFERED}" >> $VAR_FILE
fi

#
# Send SMS Notification only if MESSAGEFILE is not empty
#
if [ -s "$MESSAGEFILE" ]; then
	sendSMS "$(cat "$MESSAGEFILE")" > /dev/null 2>&1
fi

#
# Clean up
#
# Removing MESSAGEFILE 
rm -f "$MESSAGEFILE"