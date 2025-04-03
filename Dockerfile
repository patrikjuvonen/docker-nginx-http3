##################################################
# Nginx with Quiche (HTTP/3), Brotli, Headers More
# and ModSec modules.
##################################################
# This is a fork of:
# github.com/ranadeeppolavarapu/docker-nginx-http3
#
# Special in this fork:
# - ModSecurity for nginx (SpiderLabs) with
#   coreruleset
# - HPACK enabled and nginx quiche patch by
#   kn007/patch
# - BoringSSL OCSP enabled with kn007/patch
# - Removed nginx debug build
#
# Thanks to ranadeeppolavarapu/docker-nginx-http3
# for doing the ground work!
##################################################

FROM alpine:edge AS deps

ARG NGINX_VERSION=1.23.4
ARG QUICHE_CHECKOUT=fde75a22236837680ca6108a7b25964aef39c846
ARG MODSEC_TAG=v3/master
ARG MODSEC_NGX_TAG=master
ARG NJS_TAG=0.8.9

ARG BUILD_DATE
ARG VCS_REF
ARG GITHUB_REF
ARG GITHUB_RUN_ID
ARG GITHUB_RUN_NUMBER
ARG GITHUB_RUN_ATTEMPT

ARG GPG_KEYS=13C82A63B603576156E30A4EA0EA981B66B0D967

ARG CONFIG=" \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-pcre-jit \
  --with-http_ssl_module \
  --with-http_realip_module \
  --with-http_addition_module \
  --with-http_sub_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_random_index_module \
  --with-http_secure_link_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --with-http_xslt_module=dynamic \
  --with-http_image_filter_module=dynamic \
  --with-http_geoip_module=dynamic \
  --with-http_perl_module=dynamic \
  --with-threads \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  --with-stream_geoip_module=dynamic \
  --with-http_slice_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-compat \
  --with-file-aio \
  --with-http_v2_module \
  --with-http_v2_hpack_enc \
  --with-http_v3_module \
  --with-openssl=/usr/src/quiche/quiche/deps/boringssl \
  --with-quiche=/usr/src/quiche \
  --add-module=/usr/src/ngx_brotli \
  --add-module=/usr/src/headers-more-nginx-module \
  --add-module=/usr/src/njs/nginx \
  --add-module=/usr/src/nginx_cookie_flag_module \
  --add-module=/usr/src/ModSecurity-nginx \
  --with-cc-opt=-Wno-error \
  --with-select_module \
  --with-poll_module \
"

RUN set -eux \
  && echo $NGINX_VERSION $QUICHE_CHECKOUT $MODSEC_TAG $MODSEC_NGX_TAG $NJS_TAG $BUILD_DATE $VCS_REF $GITHUB_REF $GITHUB_RUN_ID $GITHUB_RUN_NUMBER $GITHUB_RUN_ATTEMPT $GPG_KEYS $CONFIG \
  && addgroup -S nginx \
  && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
  && apk update \
  && apk upgrade \
  && apk add --no-cache ca-certificates openssl \
  && update-ca-certificates \
  && apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  pcre-dev \
  zlib-dev \
  linux-headers \
  gnupg \
  libxslt-dev \
  gd-dev \
  geoip-dev \
  perl-dev \
  && apk add --no-cache --virtual .brotli-build-deps \
  autoconf \
  libtool \
  automake \
  git \
  g++ \
  cmake \
  go \
  perl \
  rust \
  cargo \
  patch \
  && apk add --no-cache --virtual .modsec-build-deps \
  libxml2-dev \
  byacc \
  flex \
  libstdc++ \
  libmaxminddb-dev \
  lmdb-dev \
  file

WORKDIR /usr/src/

FROM deps AS clone_ngx_brotli
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/google/ngx_brotli

FROM deps AS clone_headers-more-nginx-module
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/openresty/headers-more-nginx-module

FROM deps AS clone_njs
RUN git clone --branch $NJS_TAG --depth=1 --recursive --shallow-submodules https://github.com/nginx/njs

FROM deps AS clone_nginx_cookie_flag_module
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/AirisX/nginx_cookie_flag_module

FROM deps AS clone_quiche
RUN git clone --recursive https://github.com/cloudflare/quiche \
  && cd quiche \
  && git checkout --recurse-submodules $QUICHE_CHECKOUT

FROM deps AS clone_modsecurity
RUN set -eux \
  && git clone --recursive --branch $MODSEC_TAG --single-branch https://github.com/SpiderLabs/ModSecurity \
  && cd ModSecurity \
  && ./build.sh \
  && ./configure --with-lmdb --enable-examples=no \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make -j$(getconf _NPROCESSORS_ONLN) install \
  && strip /usr/local/modsecurity/bin/* \
  && strip /usr/local/modsecurity/lib/*.so.* \
  && strip /usr/local/modsecurity/lib/*.a

FROM deps AS clone_modsecurity-nginx
RUN git clone --depth=1 --recursive --shallow-submodules --branch $MODSEC_NGX_TAG --single-branch https://github.com/SpiderLabs/ModSecurity-nginx

FROM deps AS clone_coreruleset
RUN git clone --depth=1 https://github.com/coreruleset/coreruleset /usr/local/share/coreruleset \
  && cp /usr/local/share/coreruleset/crs-setup.conf.example /usr/local/share/coreruleset/crs-setup.conf

FROM deps AS clone_nginx
COPY nginx.patch /usr/src/nginx.patch
RUN set -eux \
  && wget -q https://raw.githubusercontent.com/kn007/patch/ce70f81a3098afe0e27a8e579b77b6fb32870c54/nginx_with_quic.patch \
  && wget -q https://raw.githubusercontent.com/kn007/patch/cd03b77647c9bf7179acac0125151a0fbb4ac7c8/Enable_BoringSSL_OCSP.patch \
  && wget -qO nginx.tar.gz https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz \
  && wget -qO nginx.tar.gz.asc https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc \
  && export GNUPGHOME="$(mktemp -d)" \
  && found=''; \
  for server in \
  ha.pool.sks-keyservers.net \
  hkp://keyserver.ubuntu.com:80 \
  hkp://p80.pool.sks-keyservers.net:80 \
  pgp.mit.edu \
  ; do \
  echo "Fetching GPG key $GPG_KEYS from $server"; \
  gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
  gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
  && rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
  && tar -zxC /usr/src -f nginx.tar.gz \
  && rm nginx.tar.gz \
  && cd /usr/src/nginx-$NGINX_VERSION \
  && patch -p01 < /usr/src/nginx_with_quic.patch \
  && patch -p01 < /usr/src/Enable_BoringSSL_OCSP.patch \
  && patch -p01 < /usr/src/nginx.patch

FROM deps AS builder
COPY --from=clone_nginx /usr/src/nginx-$NGINX_VERSION /usr/src/nginx-$NGINX_VERSION
COPY --from=clone_coreruleset /usr/local/share/coreruleset /usr/local/share/coreruleset
COPY --from=clone_modsecurity /usr/local/modsecurity /usr/local/modsecurity
COPY --from=clone_modsecurity-nginx /usr/src/ModSecurity-nginx /usr/src/ModSecurity-nginx
COPY --from=clone_quiche /usr/src/quiche /usr/src/quiche
COPY --from=clone_ngx_brotli /usr/src/ngx_brotli /usr/src/ngx_brotli
COPY --from=clone_headers-more-nginx-module /usr/src/headers-more-nginx-module /usr/src/headers-more-nginx-module
COPY --from=clone_njs /usr/src/njs /usr/src/njs
COPY --from=clone_nginx_cookie_flag_module /usr/src/nginx_cookie_flag_module /usr/src/nginx_cookie_flag_module
RUN set -eux \
  && mkdir /root/.cargo \
  && echo $'[net]\ngit-fetch-with-cli = true' > /root/.cargo/config.toml \
  && cd /usr/src/nginx-$NGINX_VERSION \
  && ./configure $CONFIG --build="docker-nginx-http3-$VCS_REF-$BUILD_DATE-$GITHUB_REF-$GITHUB_RUN_ID-$GITHUB_RUN_NUMBER-$GITHUB_RUN_ATTEMPT ModSecurity-$(git --git-dir=/usr/src/ModSecurity/.git rev-parse --short HEAD) ModSecurity-nginx-$(git --git-dir=/usr/src/ModSecurity-nginx/.git rev-parse --short HEAD) coreruleset-$(git --git-dir=/usr/local/share/coreruleset/.git rev-parse --short HEAD) quiche-$(git --git-dir=/usr/src/quiche/.git rev-parse --short HEAD) ngx_brotli-$(git --git-dir=/usr/src/ngx_brotli/.git rev-parse --short HEAD) headers-more-nginx-module-$(git --git-dir=/usr/src/headers-more-nginx-module/.git rev-parse --short HEAD) njs-$(git --git-dir=/usr/src/njs/.git rev-parse --short HEAD) nginx_cookie_flag_module-$(git --git-dir=/usr/src/nginx_cookie_flag_module/.git rev-parse --short HEAD)" \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make -j$(getconf _NPROCESSORS_ONLN) install

RUN set -eux \
  && rm -rf /etc/nginx/html/ \
  && mkdir /etc/nginx/conf.d/ \
  && mkdir /etc/nginx/modsec/ \
  && mkdir -p /usr/share/nginx/html/ \
  && install -m644 /usr/src/nginx-$NGINX_VERSION/html/index.html /usr/share/nginx/html/ \
  && install -m644 /usr/src/nginx-$NGINX_VERSION/html/50x.html /usr/share/nginx/html/ \
  && ln -s /usr/lib/nginx/modules /etc/nginx/modules \
  && strip /usr/sbin/nginx* \
  && strip /usr/lib/nginx/modules/*.so \
  && find /usr/local/share/coreruleset \! -name '*.conf' -type f -mindepth 1 -maxdepth 1 -delete \
  && find /usr/local/share/coreruleset \! -name 'rules' -type d -mindepth 1 -maxdepth 1 | xargs rm -rf \
  && rm -rf /etc/nginx/*.default /etc/nginx/*.so \
  && rm -rf /usr/src \
  \
  # Bring in gettext so we can get `envsubst`, then throw
  # the rest away. To do this, we need to install `gettext`
  # then move `envsubst` out of the way so `gettext` can
  # be deleted completely, then move `envsubst` back.
  && apk add --no-cache --virtual .gettext "gettext>=0.21-r2" \
  && mv /usr/bin/envsubst /tmp/ \
  \
  && runDeps="$( \
  scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
  | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
  | sort -u \
  | xargs -r apk info --installed \
  | sort -u \
  )" \
  && apk add --no-cache --virtual .nginx-rundeps $runDeps \
  && apk del .modsec-build-deps \
  && apk del .brotli-build-deps \
  && apk del .build-deps \
  && apk del .gettext \
  && rm -rf /root/.cargo \
  && rm -rf /var/cache/apk/* \
  && mv /tmp/envsubst /usr/local/bin/ \
  # Create self-signed certificate
  && mkdir -p /etc/ssl/private \
  && openssl req -x509 -newkey rsa:4096 -nodes -keyout /etc/ssl/private/localhost.key -out /etc/ssl/localhost.pem -days 365 -sha256 -subj '/CN=localhost'

COPY --from=clone_modsecurity /usr/src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
COPY --from=clone_modsecurity /usr/src/ModSecurity/unicode.mapping /etc/nginx/modsec/unicode.mapping

FROM alpine:edge

COPY --from=builder /usr/sbin/nginx /usr/sbin/
COPY --from=builder /usr/lib/libbrotli* /usr/lib/
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /usr/share/nginx/html/* /usr/share/nginx/html/
COPY --from=builder /etc/nginx/ /etc/nginx/
COPY --from=builder /usr/local/bin/envsubst /usr/local/bin/
COPY --from=builder /etc/ssl/private/localhost.key /etc/ssl/private/
COPY --from=builder /etc/ssl/localhost.pem /etc/ssl/
COPY --from=builder /usr/local/share/coreruleset /usr/local/share/coreruleset/
COPY --from=builder /usr/local/modsecurity /usr/local/modsecurity/

RUN \
  apk add --no-cache \
  # Bring in tzdata so users could set the timezones through the environment
  # variables
  tzdata \
  # Dependencies
  pcre \
  pcre2 \
  libgcc \
  libintl \
  # ModSecurity dependencies
  libxml2-dev \
  yajl-dev \
  geoip-dev \
  libstdc++ \
  libmaxminddb-dev \
  lmdb-dev \
  && addgroup -S nginx \
  && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
  # forward request and error logs to docker log collector
  && mkdir -p /var/log/nginx \
  && touch /var/log/nginx/access.log /var/log/nginx/error.log \
  && chown nginx: /var/log/nginx/access.log /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

COPY modsec/* /etc/nginx/modsec/

# Recommended nginx configuration. Please copy the config you wish to use.
# COPY nginx.conf /etc/nginx/
# COPY h3.nginx.conf /etc/nginx/conf.d/

RUN nginx -V

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
