#!/bin/bash

# SOCKS5代理服务器一键安装脚本 (Dante + 随机账号密码)
# 使用方法: sudo bash setup-socks5.sh

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}SOCKS5代理服务器一键安装脚本${NC}"
echo -e "${GREEN}================================${NC}"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 生成随机用户名和密码
USERNAME="socks_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | fold -w 16 | head -n 1)

# 获取服务器公网IP
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ipinfo.io/ip)
SOCKS_PORT=1080

echo -e "${YELLOW}正在更新系统...${NC}"
apt update -qq

echo -e "${YELLOW}正在安装 Dante SOCKS5 服务器...${NC}"
DEBIAN_FRONTEND=noninteractive apt install -y dante-server > /dev/null 2>&1

echo -e "${YELLOW}正在检测网卡...${NC}"
# 自动检测主网卡
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
if [ -z "$NETWORK_INTERFACE" ]; then
    NETWORK_INTERFACE="eth0"
    echo -e "${YELLOW}无法自动检测网卡，使用默认: eth0${NC}"
else
    echo -e "${GREEN}检测到网卡: ${NETWORK_INTERFACE}${NC}"
fi

echo -e "${YELLOW}正在配置 Dante...${NC}"

# 备份原配置
if [ -f /etc/danted.conf ]; then
    cp /etc/danted.conf /etc/danted.conf.backup.$(date +%s)
fi

# 创建新配置
cat > /etc/danted.conf << EOF
# 日志输出
logoutput: syslog

# 内部接口（监听所有接口）
internal: 0.0.0.0 port = ${SOCKS_PORT}

# 外部接口（用于转发流量）
external: ${NETWORK_INTERFACE}

# 认证方法（用户名密码认证）
socksmethod: username

# 客户端访问控制
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

# SOCKS 访问控制
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    command: bind connect udpassociate
    log: error
    socksmethod: username
}
EOF

echo -e "${YELLOW}正在创建 SOCKS5 用户...${NC}"
# 创建系统用户（不创建家目录，不允许登录）
if id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}用户 $USERNAME 已存在，正在删除...${NC}"
    userdel -r "$USERNAME" 2>/dev/null || true
fi

useradd -r -s /bin/false "$USERNAME"

# 设置密码（非交互式）
echo "$USERNAME:$PASSWORD" | chpasswd

echo -e "${YELLOW}正在重启 Dante 服务...${NC}"
systemctl restart danted
systemctl enable danted > /dev/null 2>&1

# 等待服务启动
sleep 2

# 检查服务状态
if systemctl is-active --quiet danted; then
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}安装成功！${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${GREEN}SOCKS5 代理信息:${NC}"
    echo -e "地址: ${YELLOW}${SERVER_IP}:${SOCKS_PORT}${NC}"
    echo -e "用户名: ${YELLOW}${USERNAME}${NC}"
    echo -e "密码: ${YELLOW}${PASSWORD}${NC}"
    echo ""
    echo -e "${GREEN}完整 SOCKS5 URL:${NC}"
    echo -e "${YELLOW}socks5://${USERNAME}:${PASSWORD}@${SERVER_IP}:${SOCKS_PORT}${NC}"
    echo ""
    echo -e "${GREEN}测试连接命令:${NC}"
    echo -e "${YELLOW}curl --socks5 ${USERNAME}:${PASSWORD}@${SERVER_IP}:${SOCKS_PORT} https://ifconfig.me${NC}"
    echo ""
    echo -e "${GREEN}修改密码命令:${NC}"
    echo -e "${YELLOW}sudo passwd ${USERNAME}${NC}"
    echo ""
    echo -e "${GREEN}添加新用户命令:${NC}"
    echo -e "${YELLOW}sudo useradd -r -s /bin/false 新用户名 && sudo passwd 新用户名${NC}"
    echo ""
    echo -e "${GREEN}删除用户命令:${NC}"
    echo -e "${YELLOW}sudo userdel 用户名${NC}"
    echo ""
    echo -e "${GREEN}查看所有用户:${NC}"
    echo -e "${YELLOW}cat /etc/passwd | grep '/bin/false' | grep 'socks_'${NC}"
    echo ""
    echo -e "${GREEN}重启服务命令:${NC}"
    echo -e "${YELLOW}sudo systemctl restart danted${NC}"
    echo ""
    echo -e "${GREEN}查看服务状态:${NC}"
    echo -e "${YELLOW}sudo systemctl status danted${NC}"
    echo ""
    echo -e "${GREEN}查看日志:${NC}"
    echo -e "${YELLOW}sudo journalctl -u danted -f${NC}"
    echo ""
    echo -e "${RED}请将以上信息保存到安全的地方！${NC}"
    echo -e "${GREEN}================================${NC}"
    
    # 保存到文件
    INFO_FILE="/root/socks5_info_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$INFO_FILE" << INFOEOF
SOCKS5代理服务器信息
==================
安装时间: $(date)
服务器IP: ${SERVER_IP}
代理端口: ${SOCKS_PORT}
用户名: ${USERNAME}
密码: ${PASSWORD}

完整 SOCKS5 URL:
socks5://${USERNAME}:${PASSWORD}@${SERVER_IP}:${SOCKS_PORT}

网卡接口: ${NETWORK_INTERFACE}

测试命令:
curl --socks5 ${USERNAME}:${PASSWORD}@${SERVER_IP}:${SOCKS_PORT} https://ifconfig.me

管理命令:
- 修改密码: sudo passwd ${USERNAME}
- 添加用户: sudo useradd -r -s /bin/false 新用户名 && sudo passwd 新用户名
- 删除用户: sudo userdel 用户名
- 查看用户: cat /etc/passwd | grep '/bin/false' | grep 'socks_'
- 重启服务: sudo systemctl restart danted
- 查看状态: sudo systemctl status danted
- 查看日志: sudo journalctl -u danted -f
- 编辑配置: sudo nano /etc/danted.conf
- 卸载服务: sudo apt remove --purge dante-server -y

配置文件位置: /etc/danted.conf
INFOEOF
    
    echo -e "${GREEN}信息已保存到: ${YELLOW}${INFO_FILE}${NC}"
else
    echo -e "${RED}安装失败！请检查错误信息${NC}"
    echo -e "${YELLOW}查看详细错误:${NC}"
    echo -e "${YELLOW}sudo journalctl -xeu danted${NC}"
    systemctl status danted
    exit 1
fi
