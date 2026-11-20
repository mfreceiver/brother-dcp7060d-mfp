# Brother DCP-7060D 一体化容器（打印 + 扫描）

单容器同时提供：

- **打印**：CUPS + 自编译 [brlaser](https://github.com/pdewacht/brlaser) 过滤器，IPP/IPPS（631），mDNS 自动发现（Mac/安卓/Windows 直接当网络打印机用）
- **扫描**：自编译 [AirSane](https://github.com/SimulPiscator/AirSane)（eSCL/AirScan 协议，8090）+ 官方 brscan4 后端，mDNS `_uscan._tcp` 广播（Mac 图像捕捉 / Windows Scan / Mopria Scan 直接用）

最终镜像约 336MB（多阶段构建：trixie-slim + cups/ghostscript 栈 + airsaned + brother4）。

## 依赖的宿主服务

容器不自建 mDNS/D-Bus，直接复用宿主的（Debian 系发行版）：

```bash
sudo apt install avahi-daemon
sudo systemctl enable --now avahi-daemon
```

## 使用

1. 查打印机序列号：`lsusb -v -d 04f9: | grep iSerial`（或 `lpinfo -v`）
2. 按 `docker-compose.yml` 内注释填 `PRINTER_URI`，`docker compose up -d --build`
3. TLS（可选，安卓/IPP-over-TLS 需要）：生成 `CN=<hostname>.local` 的自签证书放入挂载的 `/etc/cups/ssl/`，文件主名通过 `TLS_CERT_BASENAME` 告知

## USB 掉线

USB 复合设备偶发挂死时，重插后重启容器即可（URI 用 serial 锁定，不随 USB 口变化）：

```bash
docker restart brother-mfp
```

## 已知取舍

- brscan4 装到非标准路径 `/usr/lib64/sane/`，构建时已做符号链接；`dll.conf` 后端名必须是 `brother4`（导出符号 `_sane_brother4_*`），写 `brscan4` 会报 `unable to find _sane_brscan4_init`
- eSCL 的 mDNS 广播端口取容器内端口，所以 8090 必须原样映射
- 仅在 Debian trixie 宿主 + Brother DCP-7060D 上验证过；其他 brlaser/brscan4 支持的型号理论上改 `PRINTER_URI`/`PRINTER_NAME` 即可
