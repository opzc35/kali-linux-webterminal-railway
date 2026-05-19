FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=7681

# 1. 更新系统并安装基础依赖、SSH 服务、以及 Kali 官方默认核心工具集 (kali-linux-headless)
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y --no-install-recommends \
    ca-certificates wget curl git openssh-server tini fastfetch \
    kali-linux-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. 安装 wstunnel (用于将 SSH 流量转为 WebSocket 流量)
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64|amd64) wstunnel_arch="linux_amd64" ;; \
      aarch64|arm64) wstunnel_arch="linux_arm64" ;; \
      *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    wget -qO /tmp/wstunnel.tar.gz "https://github.com/erebe/wstunnel/releases/download/v9.7.1/wstunnel_9.7.1_${wstunnel_arch}.tar.gz" \
    && tar -xzf /tmp/wstunnel.tar.gz -C /usr/local/bin/ wstunnel \
    && chmod +x /usr/local/bin/wstunnel \
    && rm /tmp/wstunnel.tar.gz

# 3. 配置 SSH 服务（允许 root 登录与密码认证）
# ⚠️ 请将下面的 'kali' 改为你自定义的强密码
RUN mkdir /var/run/sshd \
    && echo 'root:kali' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 4. 编写启动脚本：同时拉起 SSH 服务和 wstunnel 隧道
RUN echo '#!/bin/bash\n\
service ssh start\n\
echo "wstunnel listening on port $PORT..."\n\
exec /usr/local/bin/wstunnel server ws://0.0.0.0:$PORT --restrict-to 127.0.0.1:22\n\
' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7681

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
