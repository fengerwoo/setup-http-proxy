# HTTP代理服务器一键安装脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Ubuntu-orange.svg)](https://ubuntu.com/)

一键安装配置基于 Squid 的 HTTP 代理服务器，自动生成随机认证账号密码，开箱即用。

## ✨ 特性

- 🚀 一键安装，自动配置
- 🔐 自动生成随机用户名和密码
- 🛡️ 隐私保护（删除转发标头）
- 📝 自动保存配置信息到文件
- 🔧 简单的用户管理命令
- 💾 关闭缓存节省磁盘空间

## 📋 系统要求

### 传统部署
- Ubuntu 18.04 或更高版本
- Root 权限或 sudo 访问权限
- 至少 512MB 可用内存

### Docker 部署
- Docker 20.10 或更高版本
- 至少 256MB 可用内存

## 🚀 快速开始

### 方式一：Docker 部署（推荐）

**使用 GitHub Container Registry 镜像：**

```bash
# 使用随机生成的用户名和密码
docker run -d \
  --name http-proxy \
  -p 3128:3128 \
  --restart unless-stopped \
  ghcr.io/fengerwoo/setup-http-proxy:latest

# 查看生成的用户名和密码
docker logs http-proxy
```

**自定义用户名和密码：**

```bash
docker run -d \
  --name http-proxy \
  -p 3128:3128 \
  -e PROXY_USERNAME=myuser \
  -e PROXY_PASSWORD=mypassword \
  --restart unless-stopped \
  ghcr.io/fengerwoo/setup-http-proxy:latest
```

**使用 docker-compose：**

创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'

services:
  http-proxy:
    image: ghcr.io/fengerwoo/setup-http-proxy:latest
    container_name: http-proxy
    ports:
      - "3128:3128"
    environment:
      - PROXY_USERNAME=myuser
      - PROXY_PASSWORD=mypassword
    restart: unless-stopped
```

启动服务：

```bash
docker-compose up -d
```

**本地构建镜像：**

```bash
# 克隆仓库
git clone https://github.com/fengerwoo/setup-http-proxy.git
cd setup-proxy

# 构建镜像
docker build -t http-proxy .

# 运行容器
docker run -d \
  --name http-proxy \
  -p 3128:3128 \
  --restart unless-stopped \
  http-proxy
```

### 方式二：传统安装

```bash
wget -qO- https://raw.githubusercontent.com/fengerwoo/setup-http-proxy/main/setup-proxy.sh | sudo bash
```

或者

```bash
curl -fsSL https://raw.githubusercontent.com/fengerwoo/setup-http-proxy/main/setup-proxy.sh | sudo bash
```

### 手动安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/fengerwoo/setup-http-proxy/main/setup-proxy.sh

# 添加执行权限
chmod +x setup-proxy.sh

# 运行脚本
sudo bash setup-proxy.sh
```

## 📖 使用说明

### 安装完成后

脚本会自动输出代理信息，包括：

- 服务器地址和端口
- 随机生成的用户名和密码
- 完整的代理 URL
- 常用管理命令

配置信息也会保存到 `/root/proxy_info_YYYYMMDD_HHMMSS.txt` 文件中。

### 代理配置示例

安装完成后，您会得到类似以下的代理信息：

```
地址: 123.456.789.0:3128
用户名: proxy_a1b2c3d4
密码: AbCd1234!@#$EfGh

完整代理URL:
http://proxy_a1b2c3d4:AbCd1234!@#$EfGh@123.456.789.0:3128
```

### 在应用中使用

**Linux/Mac 终端：**
```bash
export http_proxy="http://username:password@server_ip:3128"
export https_proxy="http://username:password@server_ip:3128"
```

**浏览器配置：**
- 手动代理配置
- HTTP 代理：`server_ip`
- 端口：`3128`
- 需要认证，输入用户名和密码

### 测试代理连接

安装或部署完成后，可以使用以下命令测试代理是否正常工作：

**方法一：使用 curl（推荐）**
```bash
# 基本测试（假设用户名是 proxy_xhkxyaks，密码是 AeBGBX7-7CVoF!QF）
curl -x http://proxy_xhkxyaks:AeBGBX7-7CVoF%21QF@localhost:3128 -L https://httpbin.org/ip

# 如果密码包含特殊字符，使用 --proxy-user 参数更可靠
curl -L https://httpbin.org/ip \
  --proxy http://localhost:3128 \
  --proxy-user "proxy_xhkxyaks:AeBGBX7-7CVoF!QF"

# 测试 HTTP 网站
curl -x http://用户名:密码@localhost:3128 http://www.baidu.com

# 测试 HTTPS 网站
curl -x http://用户名:密码@localhost:3128 https://www.google.com
```

**方法二：测试认证功能**
```bash
# 测试无认证访问（应该返回 407 错误）
curl -I -x http://localhost:3128 http://www.baidu.com

# 测试正确认证（应该返回 200）
curl -I -x http://用户名:密码@localhost:3128 http://www.baidu.com
```

**特殊字符处理说明：**
- URL 中的特殊字符需要转义：
  - `!` → `%21`
  - `#` → `%23`
  - `@` → `%40`
  - `$` → `%24`
  - `%` → `%25`
- 或者使用 `--proxy-user` 参数（无需转义）

**预期输出：**
```json
{
  "origin": "您的服务器IP地址"
}
```

## 🔧 管理命令

### Docker 部署管理

**查看容器日志（包含用户名密码）：**
```bash
docker logs http-proxy
```

**用户管理：**
```bash
# 修改现有用户密码
docker exec -it http-proxy htpasswd /etc/squid/passwords username

# 添加新用户
docker exec -it http-proxy htpasswd /etc/squid/passwords new_username

# 删除用户
docker exec -it http-proxy htpasswd -D /etc/squid/passwords username

# 查看所有用户
docker exec -it http-proxy cat /etc/squid/passwords | cut -d: -f1

# 查看保存的代理信息
docker exec -it http-proxy cat /var/log/squid/proxy_info.txt
```

**容器管理：**
```bash
# 重启容器
docker restart http-proxy

# 停止容器
docker stop http-proxy

# 启动容器
docker start http-proxy

# 查看容器状态
docker ps | grep http-proxy

# 查看访问日志
docker exec -it http-proxy tail -f /var/log/squid/access.log

# 查看错误日志
docker exec -it http-proxy tail -f /var/log/squid/cache.log
```

**卸载：**
```bash
# 停止并删除容器
docker stop http-proxy && docker rm http-proxy

# 删除镜像
docker rmi ghcr.io/fengerwoo/setup-http-proxy:latest
```

### 传统部署管理

**用户管理：**
```bash
# 修改现有用户密码
sudo htpasswd /etc/squid/passwords username

# 添加新用户
sudo htpasswd /etc/squid/passwords new_username

# 删除用户
sudo htpasswd -D /etc/squid/passwords username

# 查看所有用户
sudo cat /etc/squid/passwords | cut -d: -f1
```

**服务管理：**
```bash
# 重启 Squid 服务
sudo systemctl restart squid

# 查看服务状态
sudo systemctl status squid

# 停止服务
sudo systemctl stop squid

# 启动服务
sudo systemctl start squid

# 查看访问日志
sudo tail -f /var/log/squid/access.log

# 查看错误日志
sudo tail -f /var/log/squid/cache.log
```

**卸载：**
```bash
# 完全卸载 Squid 和配置文件
sudo apt remove --purge squid -y
sudo rm -rf /etc/squid /var/log/squid /var/spool/squid
```

## 🔒 安全建议

1. **更改默认端口**：编辑 `/etc/squid/squid.conf`，修改 `http_port 3128` 为其他端口
2. **定期更换密码**：使用 `htpasswd` 命令定期更新用户密码
3. **限制访问IP**：在 squid.conf 中添加 ACL 规则限制允许的客户端 IP
4. **使用防火墙**：配置 UFW 或 iptables 限制端口访问
5. **启用日志监控**：定期检查访问日志，发现异常流量

## 📝 配置文件说明

主配置文件位于：`/etc/squid/squid.conf`

主要配置项：

- **认证**：使用 basic_ncsa_auth 进行用户认证
- **端口**：默认 3128
- **缓存**：已禁用以节省空间
- **隐私**：删除 X-Forwarded-For 和 Via 标头
- **日志**：记录在 `/var/log/squid/` 目录下

## 🐛 故障排除

### 无法连接到代理

```bash
# 检查服务状态
sudo systemctl status squid

# 检查端口是否监听
sudo netstat -tlnp | grep 3128

# 检查防火墙
sudo ufw status
```

### 认证失败

```bash
# 检查密码文件权限
ls -la /etc/squid/passwords

# 重新创建用户
sudo htpasswd -c /etc/squid/passwords username
```

### 查看详细错误

```bash
# 查看 Squid 日志
sudo journalctl -u squid -n 50
sudo tail -f /var/log/squid/cache.log
```

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## ⚠️ 免责声明

本脚本仅供学习和合法用途使用。使用者需遵守当地法律法规，开发者不对任何滥用行为负责。

## 📮 联系方式

如有问题或建议，请在 [GitHub Issues](https://github.com/fengerwoo/setup-http-proxy/issues) 提出。

---

**注意**：首次安装后请妥善保存生成的用户名和密码，它们不会再次显示！配置信息已保存在 `/root/proxy_info_*.txt` 文件中。
