FROM ubuntu:22.04

# 设置环境变量避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装必要的软件包
RUN apt-get update && \
    apt-get install -y \
    squid \
    apache2-utils \
    curl \
    tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建必要的目录
RUN mkdir -p /var/spool/squid /var/log/squid

# 复制配置文件模板和启动脚本
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 暴露代理端口
EXPOSE 3128

# 设置启动脚本为入口点
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
