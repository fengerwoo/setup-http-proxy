#!/bin/bash

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}HTTP代理服务器 Docker 版${NC}"
echo -e "${GREEN}================================${NC}"

# 从环境变量获取或生成随机用户名和密码
if [ -z "$PROXY_USERNAME" ]; then
    USERNAME="proxy_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
else
    USERNAME="$PROXY_USERNAME"
fi

if [ -z "$PROXY_PASSWORD" ]; then
    # 避免使用 @, &, $, %, : 等在 URL 中需要转义的特殊字符
    # - 字符必须放在最后或最前，否则会被解释为范围
    PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!#^*_-' | fold -w 16 | head -n 1)
else
    PASSWORD="$PROXY_PASSWORD"
fi

PROXY_PORT=3128

echo -e "${YELLOW}正在配置 Squid...${NC}"

# 创建 Squid 配置
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

# 初始化 Squid 缓存目录
echo -e "${YELLOW}正在初始化 Squid 缓存目录...${NC}"
squid -z 2>/dev/null || true

# 清理 squid -z 可能产生的 PID 文件
rm -f /run/squid.pid

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}配置完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${GREEN}代理信息:${NC}"
echo -e "用户名: ${YELLOW}${USERNAME}${NC}"
echo -e "密码: ${YELLOW}${PASSWORD}${NC}"
echo -e "端口: ${YELLOW}${PROXY_PORT}${NC}"
echo ""
echo -e "${GREEN}修改密码命令:${NC}"
echo -e "${YELLOW}docker exec -it <容器名> htpasswd /etc/squid/passwords ${USERNAME}${NC}"
echo ""
echo -e "${GREEN}添加新用户命令:${NC}"
echo -e "${YELLOW}docker exec -it <容器名> htpasswd /etc/squid/passwords 新用户名${NC}"
echo ""
echo -e "${RED}请将以上信息保存到安全的地方！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 保存认证信息到文件
cat > /var/log/squid/proxy_info.txt << INFOEOF
HTTP代理服务器信息
==================
启动时间: $(date)
代理端口: ${PROXY_PORT}
用户名: ${USERNAME}
密码: ${PASSWORD}

管理命令:
- 修改密码: docker exec -it <容器名> htpasswd /etc/squid/passwords ${USERNAME}
- 添加用户: docker exec -it <容器名> htpasswd /etc/squid/passwords 新用户名
- 删除用户: docker exec -it <容器名> htpasswd -D /etc/squid/passwords 用户名
- 查看用户: docker exec -it <容器名> cat /etc/squid/passwords | cut -d: -f1
- 查看日志: docker exec -it <容器名> tail -f /var/log/squid/access.log
INFOEOF

echo -e "${YELLOW}正在启动 Squid...${NC}"
# 使用 exec 替换当前进程，这样 Squid 可以正确接收信号
exec squid -N
