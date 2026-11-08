#!/usr/bin/env bash
# 一键部署 NapCat（QQ 协议端）+ AstrBot（机器人框架）——适用于 Linux 设备
# 用法：sudo bash install-napcat-astrbot.sh
set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

[ "$(id -u)" -eq 0 ] || { echo -e "${RED}[x]${NC} 请用 root 运行"; exit 1; }

log "1/4 检查 Docker"
if ! command -v docker >/dev/null 2>&1; then
  warn "未检测到 Docker，安装中…"
  curl -fsSL https://get.docker.com | sh || {
    echo -e "${RED}[x]${NC} Docker 安装失败，请手动安装"; exit 1; }
fi
systemctl enable --now docker >/dev/null 2>&1 || true

log "2/4 启动 NapCat 容器（QQ 协议端，端口 3000/3001/6099）"
if docker ps -a --format '{{.Names}}' | grep -qx napcat; then
  docker start napcat
else
  docker run -d --name napcat --restart unless-stopped \
    -p 3000:3000 -p 3001:3001 -p 6099:6099 \
    -v napcat_config:/app/napcat/config \
    mlikiowa/napcat-docker:latest || warn "NapCat 镜像拉取/启动失败（可手动 docker pull）"
fi

log "3/4 安装 AstrBot 依赖（Python3 + git）"
command -v python3 >/dev/null || apt-get update -y && apt-get install -y python3 python3-pip git 2>/dev/null || true

log "4/4 部署并启动 AstrBot"
cd /opt
if [ ! -d /opt/AstrBot ]; then
  git clone --depth 1 https://github.com/Soulter/AstrBot || {
    echo -e "${RED}[x]${NC} AstrBot 克隆失败"; exit 1; }
fi
cd /opt/AstrBot
pip3 install -r requirements.txt --break-system-packages >/dev/null 2>&1 || \
  pip3 install -r requirements.txt >/dev/null 2>&1 || true
nohup python3 main.py > /opt/astrbot.log 2>&1 &
sleep 3

echo
echo -e "${GREEN}完成！${NC}"
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "  NapCat:  ws://${IP}:3001  （QQBot/协议端）"
echo "  NapCat  WebUI: http://${IP}:6099"
echo "  AstrBot: 面板 http://${IP}:5000  （默认端口，可在配置改）"
echo "  日志: tail -f /opt/astrbot.log"
echo