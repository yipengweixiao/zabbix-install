#!/bin/sh
echo -e '\E[1;31m 脚本作者:grichard \E[0m'


zabbix_version=3.0.6
zabbixdir=`pwd`
ip=`ip addr |grep inet |egrep -v "inet6|127.0.0.1" |awk '{print $2}' |awk -F "/" '{print $1}'`
release=`cat /etc/redhat-release | awk -F "release" '{print $2}' |awk -F "." '{print $1}' |sed 's/ //g'`

cat $zabbixdir/README.md

function install-module(){
echo -e '\E[1;31m 当前目录为:$zabbixdir \E[0m'
echo -e '\E[1;31m 本机ip:$ip \E[0m'
echo -e '\E[1;31m INSTALL MODULES \E[0m'

if [ $release = 7 ];then
	rpm -Uvh http://mirrors.isu.net.sa/pub/fedora/fedora-epel/7/x86_64/e/epel-release-7-6.noarch.rpm
	yum -y install php-xml unixODBC unixODBC-devel  php-xmlrpc php-mbstring php-mhash patch java-devel wget unzip libxml2 libxml2-devel httpd mariadb mariadb-devel mariadb-server php php-mysql php-common php-mbstring php-gd php-odbc php-pear curl curl-devel net-snmp net-snmp-devel perl-DBI php-xml ntpdate  php-bcmath zlib-devel glibc-devel curl-devel gcc automake libidn-devel openssl-devel net-snmp-devel rpm-devel OpenIPMI-devel
	systemctl restart mariadb.service
fi

ntpdate asia.pool.ntp.org  && echo -e '\E[1;31m sync time \E[0m'
groupadd zabbix    && echo -e '\E[1;31m groupadd zabbix \E[0m'
useradd -g zabbix zabbix    && echo -e '\E[1;31m useradd zabbix \E[0m'
sleep 2
}

function install-abc(){
mysqladmin  -uroot password "123456"    && echo -e '\E[1;31m set mariadb password 123456 \E[0m'
echo "create database IF NOT EXISTS zabbix default charset utf8 COLLATE utf8_general_ci;" | mysql -uroot -p123456
echo "grant all privileges on zabbix.* to zabbix@'localhost' identified by 'zabbix';" | mysql -uroot -p123456
echo "flush privileges;" | mysql -uroot -p123456    && echo -e '\E[1;31m create zabbix database  \E[0m'

if [ ! -f zabbix-${zabbix_version}.tar.gz ];then
	wget http://netix.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/${zabbix_version}/zabbix-${zabbix_version}.tar.gz
fi

tar zxvf $zabbixdir/zabbix-${zabbix_version}.tar.gz
cd $zabbixdir/zabbix-${zabbix_version}  && echo "pwd"
./configure --prefix=/usr/local/zabbix/ --enable-server --enable-agent --with-mysql --with-net-snmp --with-libcurl --with-libxml2 --enable-java
sleep 2 && echo -e '\E[1;31m 编译安装zabbix \E[0m'

CPU=$(cat /proc/cpuinfo | grep processor | wc -l)
if [ $CPU -gt 1 ];then
    make -j$CPU
else
    make
fi

make install
mkdir /var/www/html/zabbix   && echo -e '\E[1;31m install chinese fonts \E[0m'
cp -rf $zabbixdir/zabbix-${zabbix_version}/frontends/php/* /var/www/html/zabbix/
mv /var/www/html/zabbix/fonts/DejaVuSans.ttf /var/www/html/zabbix/fonts/DejaVuSans.ttf.old
cp -fr $zabbixdir/simkai.ttf /var/www/html/zabbix/fonts/DejaVuSans.ttf

cd /var/www/html/zabbix
wget https://raw.githubusercontent.com/OneOaaS/graphtrees/master/graphtree3-0-1.patch
patch  -Np0 <graphtree3-0-1.patch   && echo -e '\E[1;31m install graphtrees \E[0m'

echo -e '\E[1;31m add zabbix.conf.php \E[0m'
rm -fr /var/www/html/zabbix/conf/zabbix.conf.php
cat > /var/www/html/zabbix/conf/zabbix.conf.php <<END
<?php
// Zabbix GUI configuration file.
global \$DB;

\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = 'zabbix';

// Schema name. Used for IBM DB2 and PostgreSQL.
\$DB['SCHEMA'] = '';

\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = '';

\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
?>
END

echo -e '\E[1;31m import zabbix database \E[0m'
cd $zabbixdir/zabbix-${zabbix_version}
mysql -uzabbix -pzabbix -hlocalhost zabbix < database/mysql/schema.sql  && echo -e '\E[1;31m schena.sql OK! \E[0m'
mysql -uzabbix -pzabbix -hlocalhost zabbix < database/mysql/images.sql && echo -e '\E[1;31m images.sql OK! \E[0m'
mysql -uzabbix -pzabbix -hlocalhost zabbix < database/mysql/data.sql && echo -e '\E[1;31m data.sql OK! \E[0m'

cp misc/init.d/tru64/zabbix_agentd /etc/init.d/  && echo -e '\E[1;31m 添加启动方式\E[0m'
cp misc/init.d/tru64/zabbix_server /etc/init.d/
chmod +x /etc/init.d/zabbix_*
sed -i -e 's:DAEMON=/usr/local/sbin/zabbix_server:DAEMON=/usr/local/zabbix/sbin/zabbix_server:g' /etc/init.d/zabbix_server 
sed -i -e 's:DAEMON=/usr/local/sbin/zabbix_agentd:DAEMON=/usr/local/zabbix/sbin/zabbix_agentd:g' /etc/init.d/zabbix_agentd
sed -i -e 's:DBUser=root:DBUser=zabbix:g' /usr/local/zabbix/etc/zabbix_server.conf
sed -i -e '/# DBPassword=/a\DBPassword=zabbix' /usr/local/zabbix/etc/zabbix_server.conf

cp /etc/php.ini /etc/php.ini.old   && echo -e '\E[1;31m 备份php.ini \E[0m'
sed -i -e '/max_execution_time =/s30/300/' /etc/php.ini
sed -i -e '/max_input_time =/s/60/300/' /etc/php.ini
sed -i -e '/mbstring.func_overload =/s/0/1/' /etc/php.ini
sed -i -e '/post_max_size =/s/8M/32M/' /etc/php.ini
sed -i -e 's/;always_populate_raw_post_data = -1/always_populate_raw_post_data = -1/g' /etc/php.ini
sed -i -e 's/;date.timezone =/date.timezone = PRC/g' /etc/php.ini
sed -i '/#ServerName www.example.com:80/a\ServerName zabbix' /etc/httpd/conf/httpd.conf  && echo -e '\E[1;31m ServerName changed \E[0m'
systemctl restart httpd.service     && echo -e '\E[1;31m httpd.service restart \E[0m'
/etc/init.d/zabbix_server restart   && echo -e '\E[1;31m zabbix_server restart \E[0m'
/etc/init.d/zabbix_agentd restart   && echo -e '\E[1;31m zabbix_agent restart \E[0m'
/usr/local/zabbix/sbin/zabbix_java/startup.sh    && echo -e '\E[1;31m zabbix_java restart \E[0m'
echo "数据库默认root密码zabbix123456;zabbix-Database name:zabbix/User:zabbix/Password:zabbix"
cp $zabbixdir/zabbix-${zabbix_version}.tar.gz /var/www/html/zabbix    && echo -e '\E[1;31m zabbix web copied \E[0m'
echo "打开http://$ip/zabbix，进行下一步安装"
}

install-module
install-abc
