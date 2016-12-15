#!/bin/sh
echo "脚本作者:grichard"
sleep 2
zabbixdir=`pwd`
zabbix_version=3.0.6
ip=`ip addr |grep inet |egrep -v "inet6|127.0.0.1" |awk '{print $2}' |awk -F "/" '{print $1}'`
echo -e '\E[1;31m 当前目录为:$zabbixdir \E[0m'
echo -e '\E[1;31m 本机ip:$ip \E[0m'
echo -e '\E[1;31m INSTALL MODULES \E[0m'
cat $zabbixdir/Readme

function addserverip() {
read -p  "what's zabbix-server-IP ?:" ServerIP
echo -e '\E[1;31m zabbix服务器ip为:$ServerIP \E[0m'
}
function addagentip() {
read -p  "zabbix-server-IP is $ServerIP yes or no:" chiose
if [ "${chiose}" != "y" ] && [ "${chiose}" != "Y" ] && [ "${chiose}" != "yes" ] && [ "${chiose}" != "YES" ];
  then
  exit 1
else
  echo -e '\E[1;31mWrong chiose! back!:\E[0m' 
    addserverip
fi
}

function install() {
yum install -y ntpdate gcc gcc-c++ wget unixODBC unixODBC-devel && echo -e '\E[1;31m 安装相关组件 \E[0m'
ntpdate asia.pool.ntp.org    && echo -e '\E[1;31m groupadd zabbix \E[0m'
groupadd zabbix
useradd -g zabbix zabbix    && echo -e '\E[1;31m useradd zabbix \E[0m'
sleep 2
wget http://netix.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/$zabbix_version/zabbix-${zabbix_version}.tar.gz
tar zxvf $zabbixdir/zabbix-${zabbix_version}.tar.gz  
cd $zabbixdir/zabbix-${zabbix_version}
echo `pwd`
./configure --prefix=/usr/local/zabbix/ --enable-agent     && echo -e '\E[1;31m install zabbix_agent \E[0m'
sleep 3
make && make install
sed -i "s/Server=127.0.0.1/Server=$ServerIP/g" /usr/local/zabbix/etc/zabbix_agentd.conf     && echo -e '\E[1;31m set zabbix-server IP \E[0m'
cp $zabbixdir/zabbix-${zabbix_version}/misc/init.d/tru64/zabbix_agentd /etc/init.d/
chmod +x /etc/init.d/zabbix_agentd
sed -i "s:DAEMON=/usr/local/sbin/zabbix_agentd:DAEMON=/usr/local/zabbix/sbin/zabbix_agentd:g" /etc/init.d/zabbix_agentd
/etc/init.d/zabbix_agentd restart     && echo -e '\E[1;31m zabbix restart \E[0m'
}

addserverip
addagentip
install