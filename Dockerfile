ARG IMAGE=amd64/ubuntu:20.04
FROM $IMAGE as builder

COPY resource/sources.list /etc/apt/sources.list

WORKDIR /app

RUN apt-get update && \
    apt-get install -y libfontconfig1 libpcre3 libpcre3-dev git dpkg-dev libpng-dev libssl-dev && \
    apt-get source nginx && \
    git clone https://github.com/chobits/ngx_http_proxy_connect_module && \
    cd /app/nginx-* && \
    patch -p1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_1018.patch && \
    cd /app/nginx-* && \
    ./configure --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-threads \
    --add-module=/app/ngx_http_proxy_connect_module && \
    make -j$(grep processor /proc/cpuinfo | wc -l) && \
    make install -j$(grep processor /proc/cpuinfo | wc -l)

FROM $IMAGE

LABEL maintainer='<>'

COPY nginx.conf/nginx_whitelist.conf /usr/local/nginx/conf/nginx.conf
COPY --from=builder /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx
## save apt-get update step
COPY --from=builder /var/lib/apt/lists/ /var/lib/apt/lists/

RUN apt-get install -y --no-install-recommends libssl-dev && \
    mkdir -p /usr/local/nginx/logs/ && \
    touch /usr/local/nginx/logs/error.log && \
    apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

EXPOSE 443

CMD ["/usr/local/nginx/sbin/nginx", "-g","daemon off;"]