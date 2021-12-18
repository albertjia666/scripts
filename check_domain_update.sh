#!/bin/bash
 
program=${0##*/}
daySecond=86400
#daySecond=172800
yearDays=365
yearsDays=18250
okey=0
warn=1
crit=2
nagiosLink='https://nagios.fwmrm.net/thruk/cgi-bin/status.cgi?host='
slackWebhook='https://hooks.slack.com/services/xxxxxxxxxxxxxxxxxxxx'
 
usage()
{
    echo "Usage: $program -h | -d <domain>"
}
 
parse_arguments()
{
    local args
    args=$(getopt -o hd: --long help,domain: -u -n "$program" -- "$@")
    eval set -- "$args"
 
    while :; do
        case "$1" in
        -d|--domain)
            shift
            domain_name=$1
        ;;
        -h|--help)
            usage
            exit
        ;;
        --)
            shift
            break
        ;;
        *)
            echo "Internal error!"
        ;;
        esac
        shift
    done
 
    if [ -z "$domain_name" ]; then
            echo "UNKNOWN - There is no domain name to check"
            exit 1
    fi
}
 
# TO CHECK WHETHER DOMAIN NAME HAS BEEN UPDATED IN 24 HOURS
# |_ IF YES: CHECK DOMAIN RENEW EXTENDED YEAR WHETHER GTEATER THAN 1 YEAR
# |_ _ IF YES: THEN DOMAIN NAME RENEW SOULD BE VALID
# |_ _ IF NO: THEN DOMAIN NAME UPDATE SHOULD BE INVALID. MAYBE RENEW FAILED ANYWAY
# |_ IF NO: KEEP CHECKING NEXT TIME
 
notify()
{
    if echo "$1" | grep -q -E '\.cn$'
    then
        echo "Domain *.cn detected"
        exit 0
    else
        # echo "Domain *.com/*.net/*.tv detected"
 
        updateDate=$(whois $1 | grep "Updated Date:" | awk '{print $NF}')
        [ ! $updateDate ] && echo "Get No Domain Updated Date: Maybe Invalid Domain Name" && exit 1
        updateTimestamp=$(date +%s --date="$(whois $1 | grep "Updated Date:" | awk '{print $NF}')")
 
        currentDate=$(date -d today +"%Y-%m-%dT%H:%M:%SZ")
        currentTimestamp=$(date +%s)
 
        if [[ ${currentTimestamp} -gt ${updateTimestamp} ]] && [[ $((${currentTimestamp} - ${updateTimestamp})) -lt $daySecond ]];then
 
            expireDate=$(whois $1 | grep "Registry Expiry Date:" | awk '{print $NF}')
            [ ! $expireDate ] && echo "Get No Domain Registry Expiry Date: Maybe Invalid Domain Name" && exit 1
            expireTimestamp=$(date +%s --date="$(whois $1 | grep "Registry Expiry Date:" | awk '{print $NF}')")
 
            if [[ ${expireTimestamp} -gt ${currentTimestamp} ]];then
                diffSecond=$((${expireTimestamp} - ${currentTimestamp}))
                #diffDays=$(($((${diffSecond} / 86400)) - 1))
                diffDays=$((${diffSecond} / 86400))
                
                if [[ ${yearDays} -ge ${diffDays} ]];
                then
                    echo "CRITICAL - Domain $1(${diffDays}d to expire) renew less than 365 days. Update Date: ${updateDate}"
                    curl -X POST \
                        -H 'Content-type: application/json' \
                        --data '{"text":":red_circle: Domain <'$nagiosLink''$1'|'$1'> ('$diffDays'd to expire) renew less than 365 days. Update Date: '$updateDate' <!here>"}' \
                        $slackWebhook >/dev/null 2>&1
                    exit 2
                #elif [[ ${diffDays} -ge ${yearsDays} ]];
                #then
                #    echo "OK - Domain $1(${diffDays}) renew deteced. Update Date: ${updateDate}"
                #    curl -X POST \
                #        -H 'Content-type: application/json' \
                #        --data '{"text":":large_green_circle: Domain '$1'('$diffDays') renew deteced. Update Date: '$updateDate' <@U8K31Q1B6>"}' \
                #        $slackWebhook >/dev/null 2>&1
                #    exit 0
                else
                    echo "OK - Domain $1(${diffDays}d to expire) renew detected, please double confirm. Update Date: ${updateDate}"
                    curl -X POST \
                        -H 'Content-type: application/json' \
                        --data '{"text":":large_green_circle: Domain <'$nagiosLink''$1'|'$1'> ('$diffDays'd to expire) renew detected, please double confirm. Update Date: '$updateDate' <!here>"}' \
                        $slackWebhook >/dev/null 2>&1
                    exit 0
                fi
            else
                echo "CRITICAL - Domain $1(${diffDays}d to expire) has been expired. Update Date: ${updateDate}"
                curl -X POST \
                    -H 'Content-type: application/json' \
                    --data '{"text":":red_circle: Domain <'$nagiosLink''$1'|'$1'> ('$diffDays'd to expire) has been expired. Update Date: '$updateDate' <!here>"}' \
                    $slackWebhook >/dev/null 2>&1
                exit 2
            fi
 
        else
            echo "OK - Domain $1 Update Date: $updateDate"
            exit 0
        fi
    fi
 
}
 
parse_arguments "$@"
notify $domain_name

