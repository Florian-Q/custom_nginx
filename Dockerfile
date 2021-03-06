FROM florianq/last_libressl:latest AS libressl
FROM florianq/last_mod-security:latest as modsecurity
FROM florianq/last_owasp-modsecurity-crs:latest as owasp-modsecurity-crs

FROM nginx:latest AS nginx-build


RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
 # remove apt-utils \
    ca-certificates \
    automake \
    autoconf \
    build-essential \
    git \
    curl \
    wget \
    zlib1g-dev      \
    libssl-dev      \
    libpcre3-dev    \
    libxml2-dev     \
    libyajl-dev     \
    lua5.2-dev      \
    libgeoip-dev    \
    libcurl4-openssl-dev \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

RUN cd /opt && \
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

RUN cd /opt && \
git clone --recursive https://github.com/google/ngx_brotli.git

COPY --from=libressl /libressl /usr/local/libressl
COPY --from=modsecurity /usr/local/modsecurity/ /usr/local/modsecurity/

# Determine the latest stable version's download URL, assumed to be 
# the first `/download/nginx-*.tar.gz`-like link following the header 
# "Stable version".
RUN downloadVersion=$(curl -s 'http://nginx.org/en/download.html' | \
	awk 'BEGIN{FS="Stable version"} {print $2}' | \
	grep -o '/download/nginx-[0-9.]*\.tar\.gz' | \
	head -n 1) \
	&& echo "Download version stable of Nginx : $downloadVersion" \
	&& curl -o /opt/nginx-last.tar.gz https://nginx.org"$downloadVersion"

RUN tar xvzf /opt/nginx-last.tar.gz -C /opt \
	&& rm -f /opt/nginx-last.tar.gz \
	&& mv /opt/nginx-* /opt/nginx-last

RUN cd /opt/nginx-last && \
./configure \
        --prefix=/usr/local/nginx \
        --sbin-path=/usr/local/nginx/nginx \
        --modules-path=/usr/local/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/run/nginx.pid \
        --lock-path=/var/lock/nginx.lock \
        --user=www-data \
        --group=www-data \
        --with-pcre-jit \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_flv_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_sub_module \
        --with-http_stub_status_module \
        --with-http_v2_module \
        --with-http_secure_link_module \
        --with-stream \
        --with-stream_realip_module \
        --add-module=/opt/ModSecurity-nginx \
        --add-module=/opt/ngx_brotli \
        --with-openssl=/usr/local/libressl \
        --with-cc-opt='-g -O2 -specs=/usr/share/dpkg/no-pie-compile.specs -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
        --with-ld-opt='-specs=/usr/share/dpkg/no-pie-link.specs -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
        --with-http_dav_module

RUN cd /opt/nginx-last && \
make && \
make install && \
make modules

## True conteneur
FROM ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive

# Libraries for ModSecurity, and curl
RUN apt update && \
apt-get install --no-install-recommends --no-install-suggests -y \
    ca-certificates \
    libcurl4-openssl-dev  \
    libyajl-dev \
    lua5.2-dev \
    libgeoip-dev \
    curl \ 
    vim \
    libxml2
RUN apt clean && \
rm -rf /var/lib/apt/lists/*

COPY --from=modsecurity /usr/local/modsecurity/ /usr/local/modsecurity
RUN ldconfig

COPY --from=nginx-build /usr/local/nginx/nginx /usr/local/nginx/nginx
COPY --from=nginx-build /etc/nginx /etc/nginx
COPY --from=nginx-build /usr/local/nginx/html /usr/local/nginx/html

# NGiNX Create log dirs
RUN mkdir -p /var/log/nginx/
RUN touch /var/log/nginx/access.log
RUN touch /var/log/nginx/error.log
# default error template html
RUN mkdir -p /var/www
RUN html="<!DOCTYPE html> \
<html> \
</html>" \
&& echo "$html" > /var/www/error.html

## Install ModSecurity conf recommended 
RUN sed -i '38i modsecurity on;\n\tmodsecurity_rules_file /etc/nginx/modsecurity.d/include.conf;' /etc/nginx/nginx.conf
RUN mkdir -p /etc/nginx/modsecurity.d
RUN echo "include /etc/nginx/modsecurity.d/modsecurity.conf" > /etc/nginx/modsecurity.d/include.conf
COPY --from=modsecurity /modsecurity/modsecurity.conf-recommended /etc/nginx/modsecurity.d
COPY --from=modsecurity /modsecurity/unicode.mapping /etc/nginx/modsecurity.d
RUN cd /etc/nginx/modsecurity.d && \
    mv modsecurity.conf-recommended modsecurity.conf

## Install OWASP ModSecurity Core Rule Set
COPY --from=owasp-modsecurity-crs /owasp-modsecurity-crs/rules /etc/nginx/modsecurity.d/rules
COPY --from=owasp-modsecurity-crs /owasp-modsecurity-crs/crs-setup.conf /etc/nginx/modsecurity.d
RUN echo "include /etc/nginx/modsecurity.d/crs-setup.conf">>/etc/nginx/modsecurity.d/include.conf
RUN echo "include /etc/nginx/modsecurity.d/rules/*.conf">>/etc/nginx/modsecurity.d/include.conf
RUN sed -i -e 's/SecRuleEngine DetectionOnly/SecRuleEngine On/g' /etc/nginx/modsecurity.d/modsecurity.conf

# Update nginx config
COPY ⁄ /
RUN chmod +x /start.sh
## Move nginx.conf file in /etc/nginx/config/
RUN rm -rf /etc/nginx/nginx.conf && rm -f /etc/nginx/nginx.conf.default && rm -r /etc/nginx/conf.d
RUN mkdir -p /etc/nginx/config
RUN cp -R /etc/nginx/config.default/. /etc/nginx/config
RUN ln -s ./config/nginx.conf /etc/nginx/nginx.conf
RUN ln -s ./config/conf.d /etc/nginx/conf.d


EXPOSE 80 443

STOPSIGNAL SIGTERM

ENTRYPOINT ["/bin/sh", "/start.sh"]
CMD ["/usr/local/nginx/nginx","-g","daemon off;"]

# inspire to : https://hub.docker.com/r/krish512/modsecurity/dockerfile