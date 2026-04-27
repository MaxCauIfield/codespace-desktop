#!/bin/bash

# 快速启动脚本 - 适用于已经初始化过的环境
# Cloud Shell 版本：仅启动 Docker 容器和 Tailscale

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
        sudo tailscale up --authkey="${TAILSCALE_AUTHKEY}" --accept-routes --accept-dns=false --hostname="cloudshell-desktop" 2>/dev/null || true
    else
        echo "⚠️  未设置 TAILSCALE_AUTHKEY，请手动运行: sudo tailscale up"
    fi
fi

echo ""
echo "=========================================="
echo "  Cloud Shell Desktop 已启动!"
echo "=========================================="
echo ""
echo "🔗 连接方式:"
TAILSCALE_IP=$(sudo tailscale ip -4 2>/dev/null || echo "<Tailscale-IP>")
echo "  🌐 Web VNC (推荐):"
echo "     https://ssh.cloud.google.com/devshell/proxy?port=8080"
echo ""
echo "  🔌 VNC 客户端 (通过 Tailscale):"
echo "     ${TAILSCALE_IP}:5900 (密码: password)"
echo "     ⚠️  注意: Cloud Shell 可能限制出口端口"
echo ""
echo "  💻 RDP (通过 Tailscale):"
echo "     ${TAILSCALE_IP}:3389 (用户: root, 密码: cloudshell)"
echo "     ⚠️  注意: 端口可能受 Cloud Shell 网络限制"
echo ""
echo "📊 状态检查:"
echo "  • 容器状态: docker ps"
echo "  • 查看日志: docker logs ${CONTAINER_NAME}"
echo "  • Tailscale: sudo tailscale status"
