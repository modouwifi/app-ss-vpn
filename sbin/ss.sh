#!/bin/sh

CURWDIR=$(cd $(dirname $0) && pwd)
CUSTOMCONF="$CURWDIR/../conf/custom.conf"
SETCONFDEF="$CURWDIR/../conf/set.def"
SETCONF="$CURWDIR/../conf/set.conf"
DATAJSON="$CURWDIR/../conf/data.json"
PDNSDCONFILE="$CURWDIR/../conf/pdnsd.conf"
PIDFILE="$CURWDIR/../conf/custom.pid"
SSBIN="$CURWDIR/../bin/ss-redir"
SSSHELL="$CURWDIR/../sbin/ss-transp.sh "
PDNSDBIN="$CURWDIR/../bin/pdnsd"
DNSMASQCONF="/system/conf/dnsmasq.conf"
PDNSDCONF="conf-dir=$CURWDIR/../conf/dnsmasq";

CMDHEAD='"cmd":"'
CMDTAIL='",'
SHELLBUTTON1="$CURWDIR/../sbin/ss.sh config"
SHELLBUTTON2="$CURWDIR/../sbin/ss.sh start"
SHELLBUTTON22="$CURWDIR/../sbin/ss.sh stop"
CMDBUTTON1=${CMDHEAD}${SHELLBUTTON1}${CMDTAIL};
CMDBUTTON2=${CMDHEAD}${SHELLBUTTON2}${CMDTAIL};
CMDBUTTON22=${CMDHEAD}${SHELLBUTTON22}${CMDTAIL};

## add the change of dnsmasq conf for pdnsd
## fork from HDNS
delConfDir() {
    /system/sbin/writesys.sh
    local pdnsddir=`echo "$CURWDIR/../conf/dnsmasq" | sed -e 's:/:\\\\/:g'`
    /bin/sed -ie "/conf-dir=$pdnsddir/d" $DNSMASQCONF 1>/dev/null 2>&1
    /system/sbin/writesys.sh close
}

addConfDir() {
    /system/sbin/writesys.sh
    local pdnsddir=`echo "$CURWDIR/../conf/dnsmasq" | sed -e 's:/:\\\\/:g'`
    /bin/sed -ie "/conf-dir=$pdnsddir/d" $DNSMASQCONF 1>/dev/null 2>&1
    echo $PDNSDCONF >> $DNSMASQCONF
    /system/sbin/writesys.sh close
}

dnsStop() {
    pid=`/bin/ps|grep dnsmasq|grep -v grep|awk '{print $1}'`
    if [ "$pid" != "" ]; then
        /bin/kill $pid 1>/dev/null 2>&1
    else
        /usr/bin/killall dnsmasq 1>/dev/null 2>&1
    fi
}

dnsStart() {
    dnsStop
    /bin/dnsmasq -C "$DNSMASQCONF" &
}

pdnsdEnable() {
    addConfDir
    dnsStart
}

pdnsdDisable() {
    delConfDir
    killall pdnsd 1>/dev/null 2>&1
    dnsStart
}

testServerStatus()
{
    status=`ps | grep ss-redir | wc -l`
    if [ "$status" == "1" ]; then
        echo 0;
    else
        echo 1;
    fi
    return 0;
}

testConfigStatus()
{
    if [ -f "$SETCONF" ]; then
        echo 1;
    else
        echo 0;
    fi
    return 0;
}

genCustomContent()
{
    contenthead='"content":"'
    contenttail='",'
    contentbody=""
    linetag="\n"

    isserverstart=`testServerStatus`
    isserverconfig=`testConfigStatus`

    if [ "$isserverstart" == "1" ]; then
        contentbody="**服务已启动**"
        /system/sbin/json4sh.sh "set" $DATAJSON state_shadow_socks value true
    else
        contentbody="**服务未启动**"
        /system/sbin/json4sh.sh "set" $DATAJSON state_shadow_socks value false
    fi

    if [ "$isserverconfig" == "1" ]; then
        counts=`cat $SETCONF | wc -l`
        configcontent=""
        for count in $(seq $counts)
        do
            line=`head -n $count $SETCONF | tail -n 1`
            configcontent=${configcontent}${line}${linetag}
        done
        contentbody=${contentbody}${linetag}${configcontent};
    fi

    echo ${contenthead}${contentbody}${contenttail};
    return 0;
}

genCustomConfig()
{
    echo '
    {
        "title": "ShadowSocks VPN",
    ' > $CUSTOMCONF

    content=`genCustomContent`
    echo $content >> $CUSTOMCONF

    echo '
        "button1": {
    ' >> $CUSTOMCONF
    echo $CMDBUTTON1 >> $CUSTOMCONF
    echo '
            "txt": "配置账号",
            "code": {"0": "正在显示", "-1": "执行失败"}
            },
        "button2": {
    ' >>$CUSTOMCONF


    isserverstart=`testServerStatus`
    if [ "$isserverstart" == "1" ]; then
        echo $CMDBUTTON22 >> $CUSTOMCONF
        echo '
            "txt": "关闭服务",
        ' >> $CUSTOMCONF
    else
        echo $CMDBUTTON2 >> $CUSTOMCONF
        echo '
            "txt": "开启服务",
        ' >> $CUSTOMCONF
    fi

    echo '
            "code": {"0": "start success", "-1": "执行失败"}
            }
    }
    ' >> $CUSTOMCONF
    return 0;
}

ssTpStart()
{
    genCustomConfig;
    custom $CUSTOMCONF &
    echo $! > $PIDFILE
    return 0;
}

ssConfig()
{
    generate-config-file $SETCONFDEF
    serveraddr=`head -n 1 $SETCONFDEF | cut -d ' ' -f2-`;
    serverport=`head -n 2 $SETCONFDEF | tail -n 1 | cut -d ' ' -f2-`;
    secmode=`head -n 3 $SETCONFDEF | tail -n 1 | cut -d ' ' -f2-`;
    passwd=`head -n 4 $SETCONFDEF | tail -n 1 | cut -d ' ' -f2-`;
    if [ "$serveraddr" == "" ]; then
        serveraddr="0.0.0.0"
    fi
    if [ "$serverport" == "" ]; then
        serverport=0
    fi
    if [ "$secmode" == "" ]; then
        secmode="未设置"
    fi
    if [ "$passwd" == "" ]; then
        passwd="未设置"
    fi
    /system/sbin/json4sh.sh "set" $DATAJSON service_ip_address value $serveraddr
    /system/sbin/json4sh.sh "set" $DATAJSON port_shadow_socks  value $serverport
    /system/sbin/json4sh.sh "set" $DATAJSON method_security    value $secmode
    /system/sbin/json4sh.sh "set" $DATAJSON password_shadow_socks value $passwd
    cp $SETCONFDEF $SETCONF
    genCustomConfig;
    pid=`cat $PIDFILE 2>/dev/null`;
    kill -SIGUSR1 $pid >/dev/null 2>&1;
    return 0;
}

syncConfig()
{
    serveraddr=`/system/sbin/json4sh.sh "get" $DATAJSON service_ip_address value`
    serverport=`/system/sbin/json4sh.sh "get" $DATAJSON port_shadow_socks  value`
    secmode=`/system/sbin/json4sh.sh "get" $DATAJSON method_security    value`
    passwd=`/system/sbin/json4sh.sh "get" $DATAJSON password_shadow_socks value`
    if [ "$serveraddr" == "" ]; then
        serveraddr="0.0.0.0"
    fi
    if [ "$serverport" == "" ]; then
        serverport=0
    fi
    if [ "$secmode" == "" ]; then
        secmode="未设置"
    fi
    if [ "$passwd" == "" ]; then
        passwd="未设置"
    fi
    echo "服务地址: $serveraddr
端口号: $serverport
加密方式: $secmode
密码: $passwd" > $SETCONFDEF
    cp $SETCONFDEF $SETCONF
}

ssStart()
{
    pdnsdEnable;
    serveraddr=`/system/sbin/json4sh.sh "get" $DATAJSON service_ip_address value`
    serverport=`/system/sbin/json4sh.sh "get" $DATAJSON port_shadow_socks  value`
    secmode=`/system/sbin/json4sh.sh "get" $DATAJSON method_security    value`
    passwd=`/system/sbin/json4sh.sh "get" $DATAJSON password_shadow_socks value`
    $SSSHELL $serveraddr $serverport $secmode $passwd &
    chown matrix $PDNSDCONFILE 1>/dev/null 2>&1
    $PDNSDBIN -c $PDNSDCONFILE &
    sleep 1
    genCustomConfig;
    pid=`cat $PIDFILE 2>/dev/null`;
    kill -SIGUSR1 $pid >/dev/null 2>&1;
    return 0;
}

ssStop()
{
    pdnsdDisable;
    killall ss-redir 1>/dev/null 2>&1;
    killall sswhitelist.sh 1>/dev/null 2>&1;
    killall ss-transp.sh 1>/dev/null 2>&1;
    iptables -t nat -F PDNSD 1>/dev/null 2>&1
    iptables -t nat -D OUTPUT -p tcp -j PDNSD 1>/dev/null 2>&1
    iptables -t nat -F SHADOWSOCKS 1>/dev/null 2>&1
    iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS 1>/dev/null 2>&1
    sleep 1
    genCustomConfig;
    pid=`cat $PIDFILE 2>/dev/null`;
    kill -SIGUSR1 $pid >/dev/null 2>&1;
    return 0;
}

case "$1" in
    "tpstart")
        ssTpStart;
        exit 0;
        ;;
    "config")
        ssConfig;
        exit 0;
        ;;
    "syncConfig")
        syncConfig;
        exit 0;
        ;;
    "start")
        ssStart;
        exit 0;
        ;;
    "stop")
        ssStop;
        exit 0;
        ;;
    *)
        exit 0;
        ;;
esac
