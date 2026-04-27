# Google Cloud Shell Desktop Environment

基于 Docker 的 LXDE 桌面环境，支持 Tailscale 组网、Web VNC、SSH 和 RDP 连接。

## ⚠️ 重要提示

确保你在 **home 目录** 下操作（运行 `cd ~`），否则会遇到权限错误。

## 🚀 一键部署

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/AnnaofArendelle/codespace-desktop.git&cloudshell_git_branch=GCP-Verson&cloudshell_shell_cmd=cd%20~%20%26%26%20chmod%20%2Bx%20install.sh%20%26%26%20./install.sh&shellonly=true)

## 📋 前置要求

1. **Google 账号** - 用于访问 Google Cloud Shell
2. **Tailscale 账号** - 用于安全组网访问

## 🔧 环境变量配置

与 GitHub Codespace 不同，Google Cloud Shell 使用**用户级持久化环境变量**。设置一次后，所有 Cloud Shell 会话都能使用。

### 方法一：持久化环境变量（推荐，只需配置一次）

将环境变量写入 `~/.bashrc`，这样每次启动 Cloud Shell 都会自动加载：

```bash
echo 'export TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxxxxxxxxxxxx' >> ~/.bashrc
source ~/.bashrc
```

> 💡 **提示**：Cloud Shell 的 `$HOME` 目录（包含 `.bashrc`）是持久化的，重启后仍然保留。

### 方法二：临时环境变量（仅当前会话有效）

```bash
export TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxxxxxxxxxxxx
```

### 获取 Tailscale Auth Key

1. 登录 [Tailscale 管理控制台](https://login.tailscale.com/admin/settings/keys)
2. 点击 **Generate auth key...**
3. 设置密钥名称，例如 `cloudshell-desktop`
4. 勾选 **Reusable**（可重复使用）和 **Ephemeral**（临时设备自动移除）
5. 点击 **Generate key** 并复制密钥

### 自动检测与提示

`install.sh` 脚本会自动检测 `TAILSCALE_AUTHKEY` 环境变量：
- ✅ 如果已设置：自动使用密钥登录 Tailscale
- ❌ 如果未设置：脚本会提示你输入密钥，并询问是否保存到 `~/.bashrc`

## 💻 使用方法

### 方法一：一键部署（推荐）

1. 点击上方 **Open in Cloud Shell** 按钮
2. 等待 Cloud Shell 启动并自动克隆仓库
3. **脚本会自动检测环境变量**:
   - 首次运行：脚本会提示输入 Tailscale Auth Key，并询问是否保存到 `~/.bashrc`
   - 已配置：自动使用已保存的密钥，无需额外操作
4. 按照屏幕提示完成安装

### 方法二：手动克隆运行

1. 打开 [Google Cloud Shell](https://ssh.cloud.google.com)
2. **切换到 home 目录**（重要！）：
   ```bash
   cd ~
   ```
3. 克隆仓库：
   ```bash
   git clone -b GCP-Verson https://github.com/AnnaofArendelle/codespace-desktop.git cloudshell-desktop
   cd cloudshell-desktop
   ```
4. 运行安装脚本（按提示输入密钥）：
   ```bash
   chmod +x install.sh && ./install.sh
   ```

### 预配置环境变量（可选）

如果你不想在安装时交互式输入，可以预先设置：

```bash
# 切换到 home 目录
cd ~

# 一次性设置，持久化到 .bashrc
echo 'export TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxx' >> ~/.bashrc
source ~/.bashrc

# 然后运行安装脚本
git clone -b GCP-Verson https://github.com/AnnaofArendelle/codespace-desktop.git cloudshell-desktop
cd cloudshell-desktop && ./install.sh
```

## 🔌 连接方式

### 1. Web VNC（最简单）

Cloud Shell 会自动代理 8080 端口，直接点击 Web 预览按钮即可访问桌面。

- **预览按钮**: Cloud Shell 工具栏中的 "Web 预览"（选择端口 8080）
- **直接访问**: https://ssh.cloud.google.com/devshell/proxy?port=8080
- **VNC 密码**: `password`（可在脚本中修改 `VNC_PASSWORD` 变量）

### 2. Tailscale + VNC 客户端

适用于需要最佳画质和性能的场景：

1. 在你的设备上安装 [Tailscale](https://tailscale.com/download)
2. 登录同一个 Tailscale 账号
3. 在 [Tailscale 控制台](https://login.tailscale.com/admin/machines) 查看 Cloud Shell 设备的 IP
4. 使用 VNC 客户端连接：
   - **地址**: `<Tailscale-IP>:5900`
   - **密码**: `password`

**推荐 VNC 客户端**:
- Windows: [TigerVNC Viewer](https://tigervnc.org/), [RealVNC](https://www.realvnc.com/)
- macOS: [TigerVNC](https://tigervnc.org/), [Screen Sharing](https://support.apple.com/guide/mac-help/mh11848/mac)
- Linux: Remmina, TigerVNC
- iOS/Android: RealVNC, Jump Desktop

### 3. Tailscale + SSH

适合命令行操作和文件传输：

```bash
ssh root@<Tailscale-IP>
```
- **用户名**: `root`
- **密码**: `cloudshell`

支持 X11 转发运行图形程序：
```bash
ssh -X root@<Tailscale-IP> firefox
```

### 4. Tailscale + RDP（Windows 推荐）

Windows 用户可使用自带的远程桌面客户端：

1. 按 `Win + R`，输入 `mstsc` 打开远程桌面
2. 输入 Tailscale IP 地址
3. 登录信息：
   - **用户名**: `root`
   - **密码**: `cloudshell`

## 📦 持久化说明

Google Cloud Shell 的 `$HOME` 目录是**持久化**的（5GB 存储空间），本项目将 `$HOME` 挂载到 Docker 容器中：

```bash
docker run -d -p 8080:80 -p 5900:5900 -v $HOME:/root ...
```

这意味着：
- ✅ 下载的文件保存在 `$HOME` 中会保留
- ✅ 容器内的 `/root` 目录实际上就是主机的 `$HOME`
- ✅ 重新启动 Cloud Shell 后数据不会丢失
- ✅ 安装的软件（通过 apt）需要重新安装（可以写入脚本中）

## ⚙️ 自定义配置

编辑 `install.sh` 文件修改以下变量：

```bash
# 分辨率设置
DEFAULT_WIDTH=1280
DEFAULT_HEIGHT=720

# 密码设置
VNC_PASSWORD="password"      # VNC 连接密码
ROOT_PASSWORD="cloudshell"   # SSH/RDP 密码

# 容器配置
CONTAINER_NAME="cloudshell-desktop"
DESKTOP_IMAGE="dorowu/ubuntu-desktop-lxde-vnc"
```

## 🔒 安全说明

- **Tailscale**: 所有连接经过 WireGuard 加密，设备需要授权才能加入网络
- **Auth Key**: 建议设置 Ephemeral 属性，Cloud Shell 会话结束后自动清理设备
- **密码**: 首次使用后建议修改默认密码
- **端口**: 仅 Tailscale 网络内可访问，不暴露在公网

## 🌐 网络优化

脚本已内置以下优化：

| 优化项 | 配置 | 效果 |
|--------|------|------|
| TCP Fast Open | 启用 | 减少连接延迟 |
| BBR 拥塞控制 | 启用 | 提升吞吐量 |
| VNC 压缩 | 启用 | 减少带宽占用 |
| 固定分辨率 | 1280x720 | 平衡清晰度与性能 |

## 🛠️ 故障排除

### 权限被拒绝 (Permission denied)

如果遇到 `Permission denied` 错误（尤其是 `.bashrc` 或 `git clone`）：

**问题原因**：当前不在 home 目录下，或者 home 目录权限异常

**解决方案**：
```bash
# 1. 切换到 home 目录
cd ~

# 2. 修复 home 目录权限（如果上述无效）
sudo chown -R $USER:$USER $HOME

# 3. 重新尝试操作
git clone -b GCP-Verson https://github.com/AnnaofArendelle/codespace-desktop.git cloudshell-desktop
cd cloudshell-desktop && ./install.sh
```

### 容器无法启动
```bash
docker logs cloudshell-desktop
```

### Tailscale 未连接
```bash
sudo tailscale status
sudo tailscale up --authkey="$TAILSCALE_AUTHKEY"
```

### 端口未开放
```bash
# 检查服务状态
netstat -tlnp | grep -E ':(22|3389|5900|8080)'
docker ps
```

### Web VNC 无法访问
- 确保 Cloud Shell 的 Web 预览设置为端口 8080
- 检查容器状态: `docker ps`
- 查看日志: `docker logs cloudshell-desktop`

## ⚠️ 限制说明

- **会话时长**: Cloud Shell 会话约 12 小时无活动后会休眠
- **存储空间**: 免费版提供 5GB 持久化存储
- **计算资源**: 1 vCPU, 1.7GB 内存（免费版）
- **无 GPU**: 无法运行需要硬件加速的应用

## 📝 参考项目

本项目参考了以下开源项目：
- [dorowu/ubuntu-desktop-lxde-vnc](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc) - Docker 桌面镜像
- [Tailscale](https://tailscale.com/) - 安全组网方案
- [codespace-desktop](https://github.com/MaxCauIfield/codespace-desktop) - GitHub Codespace 桌面环境

## 📄 许可证

GPL-3.0
