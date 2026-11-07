#!/bin/sh
# iSH 协议端 + QQBot 一键启动（iPhone 当服务器）
# 用法：sh ish-qq-protocol.sh
# 功能：
#   1. 解压并配置 go-cqhttp（OneBot 协议端，正向 WS :3001）
#   2. 检查/填写 QQ 号
#   3. 启动 go-cqhttp（扫码登录）
#   4. 启动 QQBot（连 127.0.0.1:3001）
# 注意：go-cqhttp 使用旧版 QQ 协议，登录可能被风控/失败——尽力适配，结果不可控。

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

echo "==== 1/4 准备 go-cqhttp ===="
if [ ! -x ./go-cqhttp ]; then
  if [ -f go-cqhttp_linux_386.tar.gz ]; then
    tar -xzf go-cqhttp_linux_386.tar.gz
    chmod +x go-cqhttp
  else
    echo "!! 缺少 go-cqhttp_linux_386.tar.gz"
    exit 1
  fi
fi

echo "==== 2/4 检查配置 ===="
if [ ! -f config.yml ]; then
  echo "!! 缺少 config.yml，请确认离线包完整"
  exit 1
fi
if grep -q "uin: 0" config.yml; then
  echo ""
  echo "!!! 请先编辑 config.yml：把  uin: 0  改成你的 QQ 号"
  echo "    编辑命令：nano config.yml   （保存：Ctrl+O 回车，退出：Ctrl+X）"
  echo "    改完后再运行一次：sh ish-qq-protocol.sh"
  exit 0
fi

echo "==== 3/4 启动 go-cqhttp（协议端 WS :3001）==== "
echo "首次会显示二维码：请用手机 QQ 扫码登录（iSH 终端也会生成 qrcode.png）"
nohup ./go-cqhttp -c config.yml > /tmp/gocqhttp.log 2>&1 &
echo "go-cqhttp 已后台启动（日志 /tmp/gocqhttp.log）"
sleep 6

echo "==== 4/4 启动 QQBot ===="
if [ -d /opt/qqbot ]; then
  cd /opt/qqbot
  nohup python3 run.py --no-tray > /tmp/qqbot.log 2>&1 &
  sleep 3
  echo "QQBot 已启动（日志 /tmp/qqbot.log）"
else
  echo "!! 未发现 /opt/qqbot，请先运行 ish-install.sh 安装 QQBot"
fi

echo ""
echo "完成！检查命令："
echo "  tail -f /tmp/gocqhttp.log"
echo "  tail -f /tmp/qqbot.log"
echo "App「接入」页填写：http://127.0.0.1:6199"