#!/bin/bash

# Google Cloud Shell Desktop Environment 安装脚本
# 支持 SSH (22)、VNC (5900)、RDP (3389) 和 Web VNC (8080)

set -e

# 默认配置
DEFAULT_WIDTH=1280
DEFAULT_HEIGHT=720
GEOMETRY="${DEFAULT_WIDTH}x${DEFAULT_HEIGHT}"
VNC_PASSWORD="${VNC_PASSWORD:-password}"
ROOT_PASSWORD="${ROOT_PASSWORD:-cloudshell}"
CONTAINER_NAME="cloudshell-desktop"
DESKTOP_IMAGE="dorowu/ubuntu-desktop-lxde-vnc"

echo "========================================"
echo "  Google Cloud Shell Desktop 安装脚本"
echo "  分辨率: ${GEOMETRY}"
echo "========================================"

# 0. 检查是否在Google Cloud Shell环境中
if [ -z "$CLOUD_SHELL" ] && [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
    echo "警告: 未检测到Google Cloud Shell环境，某些功能可能无法正常工作"
fi

# 0.5 检查并配置 TAILSCALE_AUTHKEY
if [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
    echo ""
    echo "⚠️  未检测到 TAILSCALE_AUTHKEY 环境变量"
    echo ""
    echo "Tailscale Auth Key 用于安全组网访问你的 Cloud Shell 桌面环境。"
    echo "获取方式: https://login.tailscale.com/admin/settings/keys"
    echo ""
    read -p "请输入你的 Tailscale Auth Key (格式: tskey-auth-...): " input_key
    echo ""
    
    if [ -n "$input_key" ]; then
        export TAILSCALE_AUTHKEY="$input_key"
        echo "✅ 已临时设置 TAILSCALE_AUTHKEY"
        
        # 询问是否保存到 .bashrc 以持久化
        read -p "是否将密钥保存到 ~/.bashrc 以供将来使用? (y/n): " save_choice
        if [[ "$save_choice" =~ ^[Yy]$ ]]; then
            echo "export TAILSCALE_AUTHKEY=\"$input_key\"" >> ~/.bashrc
            echo "✅ 已保存到 ~/.bashrc，下次启动 Cloud Shell 将自动加载"
        else
            echo "ℹ️  密钥未保存，仅在当前会话有效"
        fi
    else
        echo "⚠️  未提供密钥，Tailscale 需要手动登录"
        echo "   稍后运行: sudo tailscale up"
    fi
    echo ""
fi

# 1. 安装 Tailscale
echo "[1/6] 安装 Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "  Tailscale 安装完成"
else
    echo "  Tailscale 已安装"
fi

# 2. 启动 Tailscale
echo "[2/6] 启动 Tailscale..."
sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 \
    --state=/var/lib/tailscale/tailscaled.state &
sleep 3

if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
    echo "  使用 AuthKey 登录 Tailscale..."
    sudo tailscale up --authkey="${TAILSCALE_AUTHKEY}" --accept-routes --accept-dns=false --hostname="cloudshell-desktop" 2>/dev/null || {
        echo "  警告: Tailscale 登录失败，尝试手动登录..."
        echo "  请运行: sudo tailscale up"
    }
else
    echo "  注意: 未设置 TAILSCALE_AUTHKEY 环境变量"
    echo "  请运行: sudo tailscale up 手动登录"
fi

# 显示Tailscale状态
echo "  Tailscale IP 地址:"
sudo tailscale ip -4 2>/dev/null || echo "    (未获取到IP，可能尚未登录)"

# 3. 安装必要软件
echo "[3/6] 安装必要软件..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    tigervnc-standalone-server \
    xrdp \
    xorgxrdp \
    openssh-server \
    net-tools \
    ncdu \
    htop \
    curl \
    wget \
    git \
    vim \
    nano \
    2>/dev/null || echo "  部分软件包安装失败，继续..."

# 4. 配置 SSH 服务器
echo "[4/6] 配置 SSH 服务器..."
sudo mkdir -p /var/run/sshd

# 设置 root 密码
echo "root:${ROOT_PASSWORD}" | sudo chpasswd

# 配置 SSH
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config 2>/dev/null || true
sudo sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/' /etc/ssh/sshd_config 2>/dev/null || true

# 生成 SSH 主机密钥
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "  生成 SSH 主机密钥..."
    sudo ssh-keygen -A
fi

# 启动 SSH 服务
sudo service ssh restart 2>/dev/null || sudo /usr/sbin/sshd
sleep 1

if netstat -tlnp 2>/dev/null | grep -q ':22'; then
    echo "  SSH 服务已启动 (端口: 22)"
else
    echo "  警告: SSH 服务可能未正常启动"
fi

# 5. 配置 RDP 服务器
echo "[5/6] 配置 RDP 服务器..."

# 清理旧的 xrdp 配置
sudo rm -f /var/run/xrdp/*.pid 2>/dev/null || true
sudo mkdir -p /var/run/xrdp

# 配置 xrdp 使用 Xvnc 后端
sudo sed -i 's/^port=3350/port=-1/' /etc/xrdp/sesman.ini 2>/dev/null || true
sudo sed -i 's/^ListenPort=3350/ListenPort=-1/' /etc/xrdp/sesman.ini 2>/dev/null || true
sudo sed -i 's/^ssl_protocols=.*/ssl_protocols=TLSv1.2, TLSv1.3/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sudo sed -i 's/^crypt_level=.*/crypt_level=high/' /etc/xrdp/xrdp.ini 2>/dev/null || true

# 添加xrdp到ssl-cert组
sudo usermod -a -G ssl-cert xrdp 2>/dev/null || true

# 创建 xrdp 会话启动脚本
sudo tee /etc/xrdp/startwm.sh > /dev/null << 'XRDP_EOF'
#!/bin/bash
# xrdp 会话启动脚本 - 连接到 Docker VNC
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export DISPLAY=:1

# 等待 VNC 服务器准备就绪
for i in {1..30}; do
    if nc -z localhost 5900 2>/dev/null; then
        break
    fi
    sleep 1
done

# 使用 VNC 客户端连接到 Docker 内的 VNC 服务器
exec x11vnc -display :1 -connect localhost:5900 -forever -repeat 2>/dev/null || \
    echo "无法连接到 VNC 服务器"
XRDP_EOF
sudo chmod +x /etc/xrdp/startwm.sh

# 启动 xrdp 服务
sudo service xrdp stop 2>/dev/null || true
sleep 1
sudo service xrdp start 2>/dev/null || true
sleep 2

if netstat -tlnp 2>/dev/null | grep -q ':3389'; then
    echo "  RDP 服务已启动 (端口: 3389)"
else
    echo "  警告: RDP 服务可能未正常启动"
fi

# 6. 启动 Docker 桌面容器
echo "[6/6] 启动 Docker 桌面容器..."

# 停止并删除旧容器
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "  停止并删除旧容器..."
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
fi

# 创建 VNC 密码目录
mkdir -p ~/.vnc
echo "${VNC_PASSWORD}" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null || true
chmod 600 ~/.vnc/passwd 2>/dev/null || true

# 启动 Docker 容器
echo "  启动桌面容器 (这可能需要几分钟)..."
docker run -d \
    --name ${CONTAINER_NAME} \
    -p 8080:80 \
    -p 5900:5900 \
    -v "$HOME:/root" \
    -v "$HOME/.vnc:/root/.vnc:ro" \
    -e RESOLUTION="${GEOMETRY}" \
    -e VNC_PASSWORD="${VNC_PASSWORD}" \
    -e USER=root \
    --restart unless-stopped \
    ${DESKTOP_IMAGE} || {
        echo "  错误: Docker 容器启动失败"
        echo "  请检查 Docker 是否正常运行"
        exit 1
    }

# 等待容器启动
sleep 5

# 检查容器状态
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "  Docker 容器已启动"
else
    echo "  警告: Docker 容器可能未正常启动"
    echo "  查看日志: docker logs ${CONTAINER_NAME}"
fi

# 7. 应用网络优化
echo "[7/7] 应用网络优化..."
sudo sysctl -w net.ipv4.tcp_fast_open=3 2>/dev/null || true
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || true

# 输出连接信息
echo ""
echo "========================================"
echo "  安装完成！所有服务已启动"
echo "========================================"
echo ""
echo "连接方式:"
echo ""
echo "  🌐 Web VNC (推荐):"
echo "     地址: https://ssh.cloud.google.com/devshell/proxy?port=8080"
echo "     或访问: http://localhost:8080"
echo "     VNC 密码: ${VNC_PASSWORD}"
echo ""
echo "  🔌 VNC 客户端:"
TAILSCALE_IP=$(sudo tailscale ip -4 2>/dev/null || echo "<Tailscale-IP>")
echo "     地址: ${TAILSCALE_IP}:5900"
echo "     密码: ${VNC_PASSWORD}"
echo ""
echo "  🔐 SSH 连接:"
echo "     命令: ssh root@${TAILSCALE_IP}"
echo "     密码: ${ROOT_PASSWORD}"
echo "     注意: 需要在 Tailscale 管理控制台授权设备"
echo ""
echo "  💻 RDP 连接 (Windows):"
echo "     地址: ${TAILSCALE_IP}:3389"
echo "     用户: root"
echo "     密码: ${ROOT_PASSWORD}"
echo ""
echo "管理命令:"
echo "  • 查看容器日志: docker logs ${CONTAINER_NAME}"
echo "  • 重启容器: docker restart ${CONTAINER_NAME}"
echo "  • 停止容器: docker stop ${CONTAINER_NAME}"
echo "  • 进入容器: docker exec -it ${CONTAINER_NAME} bash"
echo "  • Tailscale 状态: sudo tailscale status"
echo ""
echo "持久化说明:"
echo "  • HOME 目录 ($HOME) 已挂载到容器，数据会自动保存"
echo "  • 安装的软件和文件会保存在 $HOME 中"
echo "  • Cloud Shell 的 $HOME 目录是持久化的"
echo ""
echo "⚠️  注意事项:"
echo "  • 如果无法连接，请检查 Tailscale 是否已登录"
echo "  • 首次使用需要在 Tailscale 控制台授权设备"
echo "  • Web VNC 可能需要几分钟才能完全启动"
echo ""
echo "保持运行中... (按 Ctrl+C 停止监控)"

# 监控脚本
while true; do
    sleep 60
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "警告: Docker 容器已停止，正在尝试重启..."
        docker start ${CONTAINER_NAME} 2>/dev/null || true
    fi
    if ! pgrep -x "xrdp" > /dev/null; then
        echo "警告: XRDP 服务已停止"
    fi
done
