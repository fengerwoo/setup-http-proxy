#!/bin/bash

# HTTP代理服务器一键安装脚本 (Squid + 随机账号密码)
# 使用方法: sudo bash setup-proxy.sh

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}HTTP代理服务器一键安装脚本${NC}"
echo -e "${GREEN}================================${NC}"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 生成随机用户名和密码
USERNAME="proxy_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w 16 | head -n 1)

# 获取服务器公网IP
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ipinfo.io/ip)
PROXY_PORT=3128

echo -e "${YELLOW}正在更新系统...${NC}"
apt update -qq

echo -e "${YELLOW}正在安装 Squid 和依赖...${NC}"
DEBIAN_FRONTEND=noninteractive apt install -y squid apache2-utils > /dev/null 2>&1

echo -e "${YELLOW}正在配置 Squid...${NC}"

# 备份原配置
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup.$(date +%s)

# 创建新配置
cat > /etc/squid/squid.conf << 'EOF'
# 认证配置
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm HTTP Proxy Server
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED

# 端口配置
http_port 3128

# 访问控制
http_access allow authenticated
http_access deny all

# 隐私保护
forwarded_for delete
via off
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
request_header_access Cache-Control deny all

# 缓存设置（关闭缓存以节省空间）
cache deny all

# 日志
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log

# 其他配置
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOF

echo -e "${YELLOW}正在创建认证文件...${NC}"
# 创建密码文件
htpasswd -cb /etc/squid/passwords "$USERNAME" "$PASSWORD"
chmod 640 /etc/squid/passwords
chown root:proxy /etc/squid/passwords

echo -e "${YELLOW}正在重启 Squid 服务...${NC}"
systemctl restart squid
systemctl enable squid > /dev/null 2>&1

# 检查服务状态
if systemctl is-active --quiet squid; then
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}安装成功！${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${GREEN}代理信息:${NC}"
    echo -e "地址: ${YELLOW}${SERVER_IP}:${PROXY_PORT}${NC}"
    echo -e "用户名: ${YELLOW}${USERNAME}${NC}"
    echo -e "密码: ${YELLOW}${PASSWORD}${NC}"
    echo ""
    echo -e "${GREEN}完整代理URL:${NC}"
    echo -e "${YELLOW}http://${USERNAME}:${PASSWORD}@${SERVER_IP}:${PROXY_PORT}${NC}"
    echo ""
    echo -e "${GREEN}修改密码命令:${NC}"
    echo -e "${YELLOW}sudo htpasswd /etc/squid/passwords ${USERNAME}${NC}"
    echo ""
    echo -e "${GREEN}添加新用户命令:${NC}"
    echo -e "${YELLOW}sudo htpasswd /etc/squid/passwords 新用户名${NC}"
    echo ""
    echo -e "${GREEN}删除用户命令:${NC}"
    echo -e "${YELLOW}sudo htpasswd -D /etc/squid/passwords 用户名${NC}"
    echo ""
    echo -e "${GREEN}查看所有用户:${NC}"
    echo -e "${YELLOW}sudo cat /etc/squid/passwords | cut -d: -f1${NC}"
    echo ""
    echo -e "${GREEN}重启服务命令:${NC}"
    echo -e "${YELLOW}sudo systemctl restart squid${NC}"
    echo ""
    echo -e "${RED}请将以上信息保存到安全的地方！${NC}"
    echo -e "${GREEN}================================${NC}"
    
    # 保存到文件
    INFO_FILE="/root/proxy_info_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$INFO_FILE" << INFOEOF
HTTP代理服务器信息
==================
安装时间: $(date)
服务器IP: ${SERVER_IP}
代理端口: ${PROXY_PORT}
用户名: ${USERNAME}
密码: ${PASSWORD}

完整代理URL:
http://${USERNAME}:${PASSWORD}@${SERVER_IP}:${PROXY_PORT}

管理命令:
- 修改密码: sudo htpasswd /etc/squid/passwords ${USERNAME}
- 添加用户: sudo htpasswd /etc/squid/passwords 新用户名
- 删除用户: sudo htpasswd -D /etc/squid/passwords 用户名
- 查看用户: sudo cat /etc/squid/passwords | cut -d: -f1
- 重启服务: sudo systemctl restart squid
- 查看日志: sudo tail -f /var/log/squid/access.log
- 卸载服务: sudo apt remove --purge squid -y
INFOEOF
    
    echo -e "${GREEN}信息已保存到: ${YELLOW}${INFO_FILE}${NC}"
else
    echo -e "${RED}安装失败！请检查错误信息${NC}"
    systemctl status squid
    exit 1
fi
