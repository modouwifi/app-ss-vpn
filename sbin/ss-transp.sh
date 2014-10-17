#!/bin/sh
CURWDIR=$(cd $(dirname $0) && pwd)
serveraddr=$1
serverport=$2
secmode=$3
passwd=$4
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
    # add the whitelist
    $CURWDIR/../sbin/sswhitelist.sh
    # anything else will be redirected to ss local port
    iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports 1080
    # apply the rules
    iptables -t nat -I PREROUTING -p tcp -j SHADOWSOCKS
    iptables -t nat -I OUTPUT -p tcp -j PDNSD
    return 0
}

ssIptablesClear()
{
    iptables -t nat -F PDNSD
    iptables -t nat -D OUTPUT -p tcp -j PDNSD
    iptables -t nat -F SHADOWSOCKS
    iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
}
ssRedirStop()
{
    killall ss-redir 1>/dev/null 2>&1;
}

ssRedirStart()
{
    $CURWDIR/../bin/ss-redir -s $serveraddr -p $serverport -l 1080 -k $passwd -b 0.0.0.0 -m $secmode -v &
}

# main
ssRedirStop;
ssRedirStart;
ssIptablesClear;
ssIptablesAdd;
