#!/bin/bash

# 快速启动脚本 - 适用于已经初始化过的环境

CONTAINER_NAME="cloudshell-desktop"

echo "🚀 快速启动 Cloud Shell Desktop..."

# 检查 Docker 容器状态
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "✅ Docker 容器已在运行"
else
    echo "🔄 启动 Docker 容器..."
    docker start ${CONTAINER_NAME} 2>/dev/null || {
        echo "❌ 容器不存在，请先运行 ./install.sh 进行初始化"
        exit 1
    }
fi

# 检查 Tailscale
if pgrep -x "tailscaled" > /dev/null; then
    echo "✅ Tailscale 已在运行"
    echo "   IP 地址: $(sudo tailscale ip -4 2>/dev/null || echo '未获取')"
else
    echo "🔄 启动 Tailscale..."
    sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 \
        --state=/var/lib/tailscale/tailscaled.state &
    sleep 3
    
    if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
        sudo tailscale up --authkey="${TAILSCALE_AUTHKEY}" --accept-routes --accept-dns=false 2>/dev/null || true
    else
        echo "⚠️  未设置 TAILSCALE_AUTHKEY，请手动运行: sudo tailscale up"
    fi
fi

# 检查 SSH
if ! netstat -tlnp 2>/dev/null | grep -q ':22'; then
    echo "🔄 启动 SSH 服务..."
    sudo service ssh restart 2>/dev/null || sudo /usr/sbin/sshd
fi

# 检查 RDP
if ! netstat -tlnp 2>/dev/null | grep -q ':3389'; then
    echo "🔄 启动 RDP 服务..."
    sudo service xrdp restart 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "  Cloud Shell Desktop 已启动!"
echo "=========================================="
echo ""
echo "🔗 连接方式:"
TAILSCALE_IP=$(sudo tailscale ip -4 2>/dev/null || echo "<Tailscale-IP>")
echo "  • Web VNC:   https://ssh.cloud.google.com/devshell/proxy?port=8080"
echo "  • VNC 客户端: ${TAILSCALE_IP}:5900"
echo "  • SSH:       ssh root@${TAILSCALE_IP}"
echo "  • RDP:       ${TAILSCALE_IP}:3389"
echo ""
echo "📊 状态检查:"
echo "  • 容器状态: docker ps"
echo "  • 查看日志: docker logs ${CONTAINER_NAME}"
echo "  • Tailscale: sudo tailscale status"
