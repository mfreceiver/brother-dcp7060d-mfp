#!/bin/bash
# DCP-7060D 一体化入口：CUPS 打印 + AirSane eSCL 扫描
set -e
mkdir -p /run/cups /var/run/avahi-daemon

# TLS：证书在 /etc/cups/ssl 卷内，清理容器历史垃圾证书
# TLS_CERT_BASENAME: 证书文件主名（不含 .crt/.key），如 myserver.local；
# 为空则跳过 TLS 整理
SSL=/etc/cups/ssl
CN="${TLS_CERT_BASENAME:-mar-nas.local}"
if [ -n "$TLS_CERT_BASENAME" ] && [ -f $SSL/$CN.crt ]; then
  cd $SSL
  for f in *.crt *.key; do
    [ -f "$f" ] || continue
    case "$f" in $CN.crt|$CN.key) ;; *) rm -f "$f";; esac
  done
  short="${CN%%.*}"
  [ -f $short.crt ] || cp $CN.crt $short.crt
  [ -f $short.key ] || cp $CN.key $short.key
fi

# 队列幂等创建（等 cupsd 就绪）；PRINTER_URI 必须由环境注入，如
# usb://Brother/DCP-7060D?serial=<你的序列号>（lsusb -v 或 lpinfo -v 查看）
(
  for i in $(seq 1 30); do
    if lpstat -h localhost -p >/dev/null 2>&1; then
      if ! lpstat -h localhost -p "$PRINTER_NAME" >/dev/null 2>&1; then
        lpadmin -h localhost -p "$PRINTER_NAME" -v "$PRINTER_URI" -m brlaser.ppd \
          -D "Brother DCP-7060D" -o printer-error-policy=retry-job \
          && cupsenable "$PRINTER_NAME" && cupsaccept "$PRINTER_NAME"
      fi
      break
    fi
    sleep 1
  done
) &

# 扫描服务（mDNS 注册走宿主 avahi，经挂载的 dbus socket）
/scan-entry.sh &
exec cupsd -f
