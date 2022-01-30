#!/bin/bash

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

get_used_memory_linux() {
echo "$1" | awk '/^MemTotal:/ {total = $2;}
     /^MemFree:/ {free = $2;}
     /^MemAvailable:/ {avail = $2;}
     /^Buffers:/ {buffers = $2;}
     /^Cached:/ {cached = $2;
        if (avail == "") avail = free + buffers + cached;
        printf "%0.f\n", (total - avail) / total * 100;}'
}

get_used_swap_linux() {
echo "$1" | awk '/^SwapTotal:/ {total = $2;}
     /^SwapFree:/ {free = $2;
        if (avail == "") avail = free;
        if (total==0) printf "%d\n",0;
        else printf "%0.f\n", (total - avail) / total * 100;}'
}

while getopts :H:W:C: opt
do
  case $opt in
  H)HOST=$OPTARG
   ;;
  W)OPT_WARN=$OPTARG
   ;;
  C)OPT_CRIT=$OPTARG
   ;;
  '?') echo -e "CRITICAL - $0: invalid option -$OPTARG" >&2
       echo -e "Usage: $0 [-H HOSTADDRESS] [-W WARN] [-C CRITICAL]"
   exit 2
   ;;
  esac
done

if ! [[ -n "$HOST" ]];then
    echo -e "CRITICAL - HOSTADDRESS must be set"
    exit 2
fi


OPT_WARN=${OPT_WARN:-90,0}
OPT_CRIT=${OPT_CRIT:-95,0}

R_WARN=$(echo $OPT_WARN | cut -d',' -f1)
S_WARN=$(echo $OPT_WARN | cut -d',' -f2)

R_CRIT=$(echo $OPT_CRIT | cut -d',' -f1)
S_CRIT=$(echo $OPT_CRIT | cut -d',' -f2)

MEMINFO=$(/usr/bin/ssh -o ConnectTimeout=60 xxxxxx@"$HOST" "cat /proc/meminfo" 2>&1) && USD_PCT=$(get_used_memory_linux "${MEMINFO}" 2>&1) && SWAP_PCT=$(get_used_swap_linux "${MEMINFO}" 2>&1)

if [[ $? -eq 0 ]]; then
   NOTE="Ram:${USD_PCT}%, Swap:${SWAP_PCT}%"
   if [[ ("${R_CRIT}" -ne 0 && "${USD_PCT:-0}" -ge "${R_CRIT}") || ("${S_CRIT}" -ne 0 && "${SWAP_PCT:-0}" -ge "${S_CRIT}")  ]]; then
      NOTE="CRIT $NOTE"
   elif [[ ("${R_WARN}" -ne 0 && "${USD_PCT:-0}" -ge "${R_WARN}") || ("${S_WARN}" -ne 0 && "${SWAP_PCT:-0}" -ge "${S_WARN}")  ]]; then
      NOTE="WARN $NOTE"
   else
      NOTE="OK $NOTE"
   fi
   PERFDATA="memory_used=${USD_PCT:-0},${SWAP_PCT:-0};${OPT_WARN};${OPT_CRIT}"
   echo "$NOTE | $PERFDATA"

else
  echo "CRITICAL - $MEMINFO $USD_PCT $SWAP_PCT" | tr -cd '[:print:]\n'
  exit 2
fi

EXITSTATUS=$STATE_UNKNOWN
case "${NOTE}" in
  UNK*)  EXITSTATUS=$STATE_UNKNOWN;  ;;
  OK*)   EXITSTATUS=$STATE_OK;       ;;
  WARN*) EXITSTATUS=$STATE_WARNING;  ;;
  CRIT*) EXITSTATUS=$STATE_CRITICAL; ;;
esac
exit $EXITSTATUS
