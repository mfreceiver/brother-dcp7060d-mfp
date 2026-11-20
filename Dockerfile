# Brother DCP-7060D 一体化容器：打印(brlaser/CUPS) + 扫描(brscan4/AirSane eSCL)
# ---------- 构建阶段A：brlaser ----------
FROM docker.1ms.run/library/debian:trixie-slim AS brlaser-build
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake make g++ libcups2-dev libcupsfilters-dev cups-ppdc
COPY brlaser-src.tar.gz /tmp/
RUN cd /tmp && tar xzf brlaser-src.tar.gz && cd brlaser \
 && cmake -DCMAKE_BUILD_TYPE=Release . && make -j$(nproc) rastertobrlaser \
 && ppdc brlaser.drv -d /tmp/ppd \
 && mkdir /out && cp rastertobrlaser /out/ \
 && cp "$(ls /tmp/ppd/*7060* | head -1)" /out/brlaser.ppd

# ---------- 构建阶段B：airsaned ----------
FROM docker.1ms.run/library/debian:trixie-slim AS airsane-build
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake make g++ libxml2-dev libavahi-client-dev libavahi-common-dev \
    libjpeg-dev libpng-dev libsane-dev libusb-1.0-0-dev
COPY airsane-src.tar.gz /tmp/
RUN cd /tmp && tar xzf airsane-src.tar.gz && cd AirSane \
 && cmake -DCMAKE_BUILD_TYPE=Release . && make -j$(nproc) \
 && find . -name airsaned -type f -exec cp {} /out-air/ \; 2>/dev/null; \
    mkdir -p /out2 && find . -name airsaned -type f -exec cp {} /out2/ \;

# ---------- 运行阶段 ----------
FROM docker.1ms.run/library/debian:trixie-slim
USER root
ENV TZ=Asia/Shanghai \
    PRINTER_URI="" \
    PRINTER_NAME="Brother_DCP-7060D" \
    TLS_CERT_BASENAME=""
RUN apt-get update && apt-get install -y --no-install-recommends \
    cups cups-filters cups-client ghostscript poppler-utils \
    libusb-1.0-0 libjpeg62-turbo libpng16-16 libxml2 \
    libavahi-client3 libavahi-common3 libdbus-1-3 libsane1 \
    ca-certificates curl \
 && curl -fsSL https://download.brother.com/pub/com/linux/linux/packages/brscan4-0.4.11-1.amd64.deb -o /tmp/b4.deb \
 && dpkg -i /tmp/b4.deb 2>/dev/null || apt-get -f install -y \
 && rm -f /tmp/b4.deb \
 && ln -sf /usr/lib64/sane/libsane-brother4.so.1 /usr/lib/x86_64-linux-gnu/sane/libsane-brother4.so.1 \
 && ln -sf /usr/lib64/sane/libsane-brother4.so /usr/lib/x86_64-linux-gnu/sane/libsane-brother4.so \
 && echo brother4 >> /etc/sane.d/dll.conf \
 && cd /usr/lib/x86_64-linux-gnu/sane \
 && ls | grep -vE "sane-(dll|brother4|airscan)" | xargs -r rm -f \
 && rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/* /usr/share/locale/* /usr/share/ppd/* \
 && apt-get purge -y --auto-remove curl 2>/dev/null || true
COPY --from=brlaser-build /out/rastertobrlaser /usr/lib/cups/filter/
COPY --from=brlaser-build /out/brlaser.ppd /usr/share/cups/model/brlaser.ppd
COPY --from=airsane-build /out2/airsaned /usr/local/bin/airsaned
COPY entrypoint.sh /entrypoint.sh
COPY scan-entry.sh /scan-entry.sh
RUN chmod +x /entrypoint.sh /scan-entry.sh /usr/lib/cups/filter/rastertobrlaser /usr/local/bin/airsaned
EXPOSE 631 631/udp 8090
ENTRYPOINT ["/entrypoint.sh"]
