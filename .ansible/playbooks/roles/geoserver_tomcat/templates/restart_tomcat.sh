#!/bin/bash
DRYRUN=${DRYRUN-}
NOWAIT=${NOWAIT-}
DEBUG=${DEBUG-}
MAXTIMEHOUR=${MAXTIMEHOUR-3}
MAXRAM=${MAXRAM-2000000}
WAITSEC=${WAITSEC-60}
SERVICES=${SERVICES-"tomcat-geoserver"}
PROCESS_FILTER=${PROCESS_FILTER-"java.*tomcat.*geoserver"}
set -e
if [[ -n $DEBUG ]];then set -x;fi
todo=
log () { echo "$@" >&2; }
vv() { log "$@"; $( if [[ -n $DRYRUN ]];then echo echo;fi; ) "$@"; }
pslines=""
get_pslines() { ps -eo pid,%cpu,rss,rsz,vsz,bsdtime,cmd,args|egrep "$PROCESS_FILTER"|grep -v grep; }
triggered() {
    pslines="$(get_pslines)"
    memu=$(echo "$pslines"|awk '{print $4}')
    memres=$(echo "$pslines"|awk '{print $3}')
    bsdtime=$(echo "$pslines"|awk '{print $6}')
    bsdhour=$(echo "$bsdtime"|awk -F: '{print $1}')
    while read line;do
        if [ $bsdhour -gt $MAXTIMEHOUR ] && [ $memu -gt $MAXRAM ];then
            return 0
        fi
    done <<< "$pslines"
    return 1
}
# if process triggers filters, wait for 2 minutes to calm down,
#  and after flag for kill/restart dance
if ( triggered );then
    for i in $(seq $WAITSEC);do
        if ! ( triggered );then
            todo=
            break;
        fi
        todo=1
        if [[ -n $NOWAIT ]];then break;fi
        vv sleep 1
    done
fi
if [[ -n $todo ]];then
    for pid in $( echo "$pslines" | awk '{print $1}' );do
        vv kill -9 $pid || /bin/true
    done
    for s in $SERVICES;do vv service $s restart;done
fi
exit $?
