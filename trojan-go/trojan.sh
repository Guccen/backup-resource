#trojan 一键对接脚本
#Update Time： 2020-11-4 15:24:11
#!/bin/bash
#check root
[ $(id -u) != "0" ] && { echo "错误: 您必须以root用户运行此脚本"; exit 1; }
unlink $0   #修复删除运行脚本错误

#常量
config="/data/trojan/trojan-go/server.json"

#fonts color
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
Info="${Green}[Info]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[Error]${Font}"
Notification="${Yellow}[Notification]${Font}"

get_ip(){
	ip=$(curl -s https://ipinfo.io/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ip.sb/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ipify.org)
	[[ -z $ip ]] && ip=$(curl -s https://ip.seeip.org)
	[[ -z $ip ]] && ip=$(curl -s https://ifconfig.co/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.myip.com | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && ip=$(curl -s icanhazip.com)
	[[ -z $ip ]] && ip=$(curl -s myip.ipip.net | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && echo -e "\n 这小鸡鸡还是割了吧！\n" && exit
}

#检测系统
check_system(){
	clear
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
	#res = $(cat /etc/redhat-release | awk '{print $4}')
	#if [[ ${release} == "centos" ]] && [[ ${bit} == "x86_64" ]] && [[ ${res} -ge 7 ]]; then
	if [[ ${release} == "centos" ]] && [[ ${res} -eq 6 ]]; then
	echo -e "你的系统为[${release} ${bit}],检测${Red} 不可以 ${Font}搭建。"
	echo -e "请选择${Yellow} Centos7.x / Debian / Ubuntu ${Font}搭建"
	exit 0;
	else
	echo -e "你的系统为[${release} ${bit}],检测${Green} 可以 ${Font}搭建。"
	fi
}

check_port(){
	if [[ -n `netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80` ]] || [[ -n `netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443` ]];then
	echo -e "检测到本机${Red} 80/443 ${Font}端口被占用，无法搭建。"
	exit 0;
	fi
}

#安装Trojan
install_trojan(){
	if [[ ${release} == "centos" ]];then
	yum update -y
	rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps
	yum install wget curl git net-tools socat zip ntpdate iptables unzip nginx tar -y
	else
	apt update -y
	apt-get update -y
	apt-get install wget curl git net-tools socat zip ntpdate iptables unzip nginx tar -y
	fi
	nginx_status=`ps -aux | grep "nginx: worker" |grep -v "grep"`
    if [ -n "$nginx_status" ]; then
        systemctl stop nginx
    fi
	check_port
	#开始处理对接信息
	clear
	get_ip
	read -p "请输入绑定域名(例如:www.baidu.com)[华为云解析不可用]: " DOMAIN_URL
	Ping_URL=`ping ${DOMAIN_URL} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    Curl_URL="${ip}"
	if [ $Ping_URL != $Curl_URL ] ; then
	echo -e "检测到域名未解析或解析未生效，无法搭建。"
	exit 0;
	fi
	if [ ! -d "/etc/nginx/" ]; then
        echo -e "检测到nginx安装失败，请检查是否系统出错。"
        exit 0;
    fi
	cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $DOMAIN_URL;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF
	systemctl restart nginx
	clear
	#下载伪装网站
	rm -rf /usr/share/nginx/html/*
    cd /usr/share/nginx/html/
    wget https://github.com/atrandys/trojan/raw/master/fakesite.zip && unzip fakesite.zip
	#创建trojan文件夹
	if [ ! -d "/data/trojan" ]; then
        mkdir -p /data/trojan
    fi
	
	#申请证书操作
	if [ ! -d "/data/trojan-cert" ]; then
        mkdir -p /data/trojan-cert/$DOMAIN_URL
        if [ ! -d "/data/trojan-cert/$DOMAIN_URL" ]; then
            echo -e "检测到目录创建失败，请检查是否系统出错。"
            exit 1
        fi
        curl https://get.acme.sh | sh
        ~/.acme.sh/acme.sh  --issue  -d $DOMAIN_URL  --nginx
        if test -s /root/.acme.sh/$DOMAIN_URL/fullchain.cer; then
            cert_success="1"
        fi
    elif [ -f "/data/trojan-cert/$DOMAIN_URL/fullchain.cer" ]; then
        cd /data/trojan-cert/$DOMAIN_URL
        create_time=`stat -c %Y fullchain.cer`
        now_time=`date +%s`
        minus=$(($now_time - $create_time ))
        if [  $minus -gt 5184000 ]; then
            curl https://get.acme.sh | sh
            ~/.acme.sh/acme.sh  --issue  -d $DOMAIN_URL  --nginx
            if test -s /root/.acme.sh/$DOMAIN_URL/fullchain.cer; then
                cert_success="1"
            fi
        else 
            echo -e "检测到域名$DOMAIN_URL证书存在且未超过60天，无需重新申请"
            cert_success="1"
        fi        
    else 
        mkdir -p /data/trojan-cert/$DOMAIN_URL
        curl https://get.acme.sh | sh
        ~/.acme.sh/acme.sh  --issue  -d $DOMAIN_URL  --nginx
        if test -s /root/.acme.sh/$DOMAIN_URL/fullchain.cer; then
            cert_success="1"
        fi
    fi
	clear
	if [ "$cert_success" != "1" ]; then
	echo -e "检测到域名$DOMAIN_URL证书申请失败，安装失败"
	exit 0;
	else
	cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       127.0.0.1:80;
        server_name  $DOMAIN_URL;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
    server {
        listen       0.0.0.0:80;
        server_name  $DOMAIN_URL;
        return 301 https://$DOMAIN_URL\$request_uri;
    }
    
}
EOF
	systemctl restart nginx
    systemctl enable nginx
	
	cd /data/trojan
	git clone https://github.com/Guccen/backup-resource.git
	mv /data/trojan/backup-resource/* /data/trojan/ && rm -rf /data/trojan/backup-resource
	cd /data/trojan/trojan-go && chmod +x *
	clear
	read -p "请输入你的对接数据库IP(例如:127.0.0.1 如果是本机请直接回车): " MYSQL_HOST
	read -p "请输入你的数据库名称(默认sspanel):" MYSQL_DB
	read -p "请输入你的数据库端口(默认3306):" MYSQL_PORT
	read -p "请输入你的数据库用户名(默认root):" MYSQL_USER
	read -p "请输入你的数据库密码(默认root):" MYSQL_PASS
	read -p "请输入你的节点编号(回车默认为节点ID 3):  " NODE_ID
	sed -i '/"cert"/c \        "cert": '\"/data/trojan-cert/${DOMAIN_URL}/fullchain.cer\",'' ${config}
	sed -i '/"key"/c \        "key": '\"/data/trojan-cert/${DOMAIN_URL}/private.key\",'' ${config}
	sed -i '/"sni"/c \        "sni": '\"${DOMAIN_URL}\",'' ${config}
	MYSQL_HOST=${MYSQL_HOST:-"localhost"}
	sed -i '/"mysql_server"/c \        "server_addr": '\"${MYSQL_HOST}\",'' ${config}
	MYSQL_DB=${MYSQL_DB:-"sspanel"}
	sed -i '/"mysql_database"/c \        "database": '\"${MYSQL_DB}\",'' ${config}
	MYSQL_USER=${MYSQL_USER:-"root"}
	sed -i '/"mysql_username"/c \        "username": '\"${MYSQL_USER}\",'' ${config}
	MYSQL_PASS=${MYSQL_PASS:-"root"}
	sed -i '/"mysql_password"/c \        "password": '\"${MYSQL_PASS}\",'' ${config}
	MYSQL_PORT=${MYSQL_PORT:-"3306"}
	sed -i '/"mysql_port"/c \        "server_port": '${MYSQL_PORT},'' ${config}
	NODE_ID=${NODE_ID:-"3"}
	sed -i '/"node_id"/c \		"node_id": '${NODE_ID}'' ${config}
	#同步时间
	cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime -r >/dev/null 2>&1
	timedatectl set-timezone Asia/Shanghai
	timedatectl
	ntpdate -u cn.pool.ntp.org
	if [[ ${release} == "centos" ]];then
	#关闭CentOS7的防火墙
	systemctl stop firewalld.service
	systemctl disable firewalld.service
	#iptables
	iptables -F
	iptables -X  
	iptables -I INPUT -p tcp -m tcp --dport 22:65535 -j ACCEPT
	iptables -I INPUT -p udp -m udp --dport 22:65535 -j ACCEPT
	iptables-save >/etc/sysconfig/iptables
	echo 'iptables-restore /etc/sysconfig/iptables' >> /etc/rc.local
	chmod +x /etc/rc.d/rc.local && chmod +x /etc/rc.local
	#生成守护文件
	cp /data/trojan/trojan-go/example/trojan-go.service /usr/lib/systemd/system/trojan-go.service
	else
	cp /data/trojan/trojan-go/example/trojan-go.service /lib/systemd/system/trojan-go.service
	fi
	systemctl daemon-reload
	systemctl start trojan-go
	systemctl enable trojan-go
	cd /root
	~/.acme.sh/acme.sh  --installcert  -d  $DOMAIN_URL   \
		--key-file   /data/trojan-cert/$DOMAIN_URL/private.key \
		--fullchain-file  /data/trojan-cert/$DOMAIN_URL/fullchain.cer \
		--reloadcmd  "systemctl restart trojan-go"	
	clear
	if [[ `ps -ef | grep trojan-go |grep -v grep | wc -l` -ge 1 ]];then
		echo -e "${OK} ${GreenBG} Torjan后端已启动 ${Font}"
	else
		echo -e "${OK} ${RedBG} Torjan后端未启动 ${Font}"
		echo -e "请检查是否为Centos 7.x系统、检查配置文件是否正确、检查是否代码错误请反馈"
		exit 1
	fi
	stdout() {
		echo -e "\033[32m$1\033[0m"
	}
	stdout "启动命令：systemctl start trojan-go"
	stdout "停止命令：systemctl stop trojan-go"
	stdout "重启命令：systemctl restart trojan-go"
	stdout "开启自启：systemctl enable trojan-go"
	stdout "关闭自启：systemctl disable trojan-go"
	stdout "查看状态：systemctl status trojan-go"
	fi
	
}
uninstall_trojan(){
	if [ ! -d "/data/trojan/trojan-go" ]; then
	echo -e "${Error} 你似乎未安装Trojan程序，请检查后重试"
	else	
	systemctl stop trojan-go
	systemctl disable trojan-go
	systemctl stop nginx
	systemctl disable nginx
	rm -rf /data/*
	rm -rf /usr/share/nginx/html/*
	clear
	echo -e "${Success} 卸载完成"
	fi
}
main(){
	check_system
	clear
	echo -e "\033[1;5;31m请选择运行模式：\033[0m"
	echo -e "1.安装Trojan"
	echo -e "2.卸载Trojan"
	read -t 30 -p "选择：" Mode
	case $Mode in
			1)
				install_trojan
				;;
			2)
				uninstall_trojan
				;;
			*)
				echo -e "请选择正确运行模式"
				exit 1
				;;
	esac
}
main