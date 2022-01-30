#!/bin/bash

# SCRIPTS TO BACKUP NAGIOS STATUS.DAT FILE

# noc-sms slack bot
APITOKEN="xoxb-xxxxxxxxxx-xxxxxxxxxx-xxxxxxxxxxxxxxxxxxxx"

# slack channel #xljia_test
CHANNELID="CXXXXXXXXX"

OK_ICON=":ok-256:"
NO_ICON=":no-256:"
OK_MSG="DONE"
NO_MSG="FAIL"

backup_status_dat() {
    cp /var/log/nagios/* /tmp/nagios && chown nagios.nagios /tmp/nagios/*
}

send_message() {
    curl -H "Content-type: application/json; charset=utf-8" \
    --data '{"as_user":true, "channel":"'${CHANNELID}'","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"'$1' Nagios Status File Backup '$2'"}}]}' \
    -H "Authorization: Bearer $APITOKEN" \
    -X POST https://slack.com/api/chat.postMessage >/dev/null 2>&1
}

HOUR=`date +%H`
MINUTE=`date +%M`

if [[ $? -eq 0 ]]; then
    if [[ $HOUR -eq 00 && $MINUTE -eq 00 ]]; then
        send_message $OK_ICON $OK_MSG
    fi
    # send_message $OK_ICON $OK_MSG
else
    send_message $NO_ICON $NO_MSG
fi


backup_status_dat
