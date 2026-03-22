# 使用微软官方 DevContainer 基础镜像
# 系统版本：Ubuntu 24.04
# 这是 Codespaces 官方推荐的基础镜像，兼容 VSCode Server、扩展等
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 切换到 root 用户
USER root

# 禁用交互式安装提示，避免 apt 安装时弹出交互式对话框，在自动构建环境中必须设置
ENV DEBIAN_FRONTEND=noninteractive

# 预设键盘布局为 US 英文键盘，避免安装桌面环境时出现键盘选择界面
RUN echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | debconf-set-selections && \
    echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | debconf-set-selections

# 安装必要的软件包
RUN apt-get update && \
    apt-get upgrade -y && \
	# 安装 Cinnamon 和 VNC。安装 Xfce4 可解决灰屏问题
    apt-get install -y tigervnc-standalone-server cinnamon-desktop-environment dbus-x11 xfce4 xfce4-goodies novnc python3-websockify python3-numpy python3-pip pipx cabextract tightvncserver htop software-properties-common && \
	# 移除占位用的 Firefox（Snap 版本）
    apt-get remove -y firefox && \ 
	# 安装非 Snap 版本的 Firefox
	echo 'Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001' | tee /etc/apt/preferences.d/Mozilla && \
	add-apt-repository ppa:mozillateam/ppa && \
	apt-get update && \
    apt-get install -y firefox
