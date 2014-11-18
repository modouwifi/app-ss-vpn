#!/bin/sh
CURWDIR=$(cd $(dirname $0) && pwd)
serveraddr=$1
serverport=$2
secmode=$3
passwd=$4

DEFAULTLIST=$CURWDIR/../conf/defaultrange.txt
CUSTOMLIST=$CURWDIR/../data/customrange.txt
DEFAULTWHITESHELL=$CURWDIR/../sbin/default-whitelist.sh
DEFAULTWHITESHELLBAK=$CURWDIR/../sbin/default-whitelist.shbak
CUSTOMWHITESHELL=$CURWDIR/../sbin/custom-whitelist.sh
CUSTOMWHITESHELLBAK=$CURWDIR/../sbin/custom-whitelist.shbak


ssIptablesAdd()
{
    # create new chain
    iptables -t nat -N SHADOWSOCKS 1>/dev/null 2>&1
    iptables -t nat -N PDNSD 1>/dev/null 2>&1
    iptables -t nat -A PDNSD -d 8.8.8.8 -p tcp -j REDIRECT --to-ports 1080
    # ignore server addr
    iptables -t nat -A SHADOWSOCKS -d $serveraddr -j RETURN
    # ignore LANs addr
    iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
    # anything else will be redirected to ss local port
    iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports 1080
    # apply the rules
    iptables -t nat -I PREROUTING -p tcp -j SHADOWSOCKS
    iptables -t nat -I OUTPUT -p tcp -j PDNSD
    # add the whitelist
    if [ -f $DEFAULTWHITESHELL ]; then
        $DEFAULTWHITESHELL 2>/dev/null
    fi
    if [ -f $CUSTOMWHITESHELL ]; then
         $CUSTOMWHITESHELL 2>/dev/null
    fi

    return 0
}

ssIptablesClear()
{
    iptables -t nat -F PDNSD
    iptables -t nat -D OUTPUT -p tcp -j PDNSD
    iptables -t nat -F SHADOWSOCKS
    iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
}

ssIptablesFlushAll()
{
    ssIptablesClear;
    ssIptablesAdd;
}

ssIptablesAddOne()
{
    iprange="$1"
    iptables -t nat -D SHADOWSOCKS -d $iprange -j RETURN 2>/dev/null
    iptables -t nat -I SHADOWSOCKS 6 -d $iprange -j RETURN
}

ssRedirStop()
{
    killall ss-redir 1>/dev/null 2>&1;
}

ssRedirStart()
{
    $CURWDIR/../bin/ss-redir -s $serveraddr -p $serverport -l 1080 -k $passwd -b 0.0.0.0 -m $secmode -v &
}

genDefaultShell()
{
    if [ ! -f "$DEFAULTLIST" ]; then
        return 1
    fi
    if [ -f "$DEFAULTWHITESHELL" ]; then
        mv $DEFAULTWHITESHELL $DEFAULTWHITESHELLBAK
    fi

    echo "#!/bin/sh" > $DEFAULTWHITESHELL
    for lines in `cat $DEFAULTLIST`; do
        # if the format is wrong, we should get the back up
        echo "iptables -t nat -I SHADOWSOCKS 6 -d $lines -j RETURN" >> $DEFAULTWHITESHELL
    done
    chmod +x $DEFAULTWHITESHELL
    return 0
}

genCustomShell()
{
    if [ ! -f "$CUSTOMLIST" ]; then
        return 1
    fi
    if [ -f "$CUSTOMWHITESHELL" ]; then
        mv $CUSTOMWHITESHELL $CUSTOMWHITESHELLBAK
    fi

    echo "#!/bin/sh" > $CUSTOMWHITESHELL
    for lines in `cat $CUSTOMLIST`; do
        echo "iptables -t nat -D SHADOWSOCKS -d $lines -j RETURN 2>/dev/null" >> $CUSTOMWHITESHELL
        echo "iptables -t nat -A SHADOWSOCKS -d $lines -j RETURN" >> $CUSTOMWHITESHELL
    done
    chmod +x $CUSTOMWHITESHELL
    return 0
}

# main
ssRedirStop;
ssRedirStart;
genDefaultShell;
genCustomShell;
ssIptablesFlushAll;
