#!/bin/sh

CURWDIR=$(cd $(dirname $0) && pwd)
CUSTOMCONF="$CURWDIR/../conf/custom.conf"
SETCONFDEF="$CURWDIR/../conf/set.def"
SETCONF="$CURWDIR/../conf/set.conf"
PIDFILE="$CURWDIR/../conf/custom.pid"
SSBIN="$CURWDIR/../bin/sslocal"

CMDHEAD='"cmd":"'
CMDTAIL='",'
SHELLBUTTON1="$CURWDIR/../sbin/ss.sh config"
SHELLBUTTON2="$CURWDIR/../sbin/ss.sh start"
SHELLBUTTON22="$CURWDIR/../sbin/ss.sh stop"
CMDBUTTON1=${CMDHEAD}${SHELLBUTTON1}${CMDTAIL};
CMDBUTTON2=${CMDHEAD}${SHELLBUTTON2}${CMDTAIL};
CMDBUTTON22=${CMDHEAD}${SHELLBUTTON22}${CMDTAIL};

testServerStatus()
{
    status=`ps | grep sslocal | wc -l`
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
    else
        contentbody="**服务未启动**"
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
        "title": "迷你shadowsocks",
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
    cp $SETCONFDEF $SETCONF
    genCustomConfig;
    pid=`cat $PIDFILE 2>/dev/null`;
    kill -SIGUSR1 $pid >/dev/null 2>&1;
    return 0;
}

ssStart()
{
    serveraddr=`head -n 1 $SETCONF | cut -d ' ' -f2-`;
    serverport=`head -n 2 $SETCONF | tail -n 1 | cut -d ' ' -f2-`;
    secmode=`head -n 3 $SETCONF | tail -n 1 | cut -d ' ' -f2-`;
    passwd=`head -n 4 $SETCONF | tail -n 1 | cut -d ' ' -f2-`;
    $SSBIN -s $serveraddr -p $serverport -u 0.0.0.0 -b 1080 -k $passwd -m $secmode -d
    genCustomConfig;
    pid=`cat $PIDFILE 2>/dev/null`;
    kill -SIGUSR1 $pid >/dev/null 2>&1;
    return 0;
}

ssStop()
{
    killall sslocal 1>/dev/null 2>&1;
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