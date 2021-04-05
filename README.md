# docker-nginx-http3

[![Docker Pulls](https://img.shields.io/docker/pulls/patrikjuvonen/docker-nginx-http3?color=brightgreen)](https://hub.docker.com/r/patrikjuvonen/docker-nginx-http3)
[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/patrikjuvonen/docker-nginx-http3)](https://hub.docker.com/r/patrikjuvonen/docker-nginx-http3)
[![Docker Cloud Automated build](https://img.shields.io/docker/cloud/automated/patrikjuvonen/docker-nginx-http3?color=brightgreen)](https://hub.docker.com/r/patrikjuvonen/docker-nginx-http3)
[![MicroBadger](https://images.microbadger.com/badges/image/patrikjuvonen/docker-nginx-http3.svg)](https://microbadger.com/images/patrikjuvonen/docker-nginx-http3)
![GitHub](https://img.shields.io/github/license/patrikjuvonen/docker-nginx-http3)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](code_of_conduct.md)

Alpine Linux image with nginx `1.19.9` (mainline) with HTTP/3 (QUIC), TLSv1.3, 0-RTT, brotli, NJS, Cookie-Flag, headers, ModSecurity with coreruleset and BoringSSL with OCSP support. All built on the bleeding edge. Built on the edge, for the edge.

Total size is only about ~38 MB uncompressed and ~14 MB compressed.

This is a fork of [ranadeeppolavarapu/docker-nginx-http3](https://github.com/ranadeeppolavarapu/docker-nginx-http3). Thanks to him for doing the ground work.

Special in this fork:

- [ModSecurity for nginx](https://github.com/SpiderLabs/ModSecurity-nginx) (SpiderLabs) with [coreruleset](https://github.com/coreruleset/coreruleset/)
- BoringSSL OCSP enabled with [kn007/patch](https://github.com/kn007/patch/)
- Removed nginx debug build

HTTP/3 support provided from the smart people at [Cloudflare](https://cloudflare.com) with the [cloudflare/quiche](https://github.com/cloudflare/quiche) project.

Images for this are available on [Docker Hub](https://hub.docker.com/r/patrikjuvonen/docker-nginx-http3).

**Latest**: `docker pull patrikjuvonen/docker-nginx-http3`

## Usage

This is a base image like the default _nginx_ image. It is meant to be used as a drop-in replacement for the nginx base image.

Best practice example Nginx configs are available in this repo. See [_nginx.conf_](nginx.conf) and [_h3.nginx.conf_](h3.nginx.conf).

Example:

```Dockerfile
# Nginx HTTP/3 Image
FROM patrikjuvonen/docker-nginx-http3:latest

# Copy your certs.
COPY localhost.key /etc/ssl/private/
COPY localhost.pem /etc/ssl/

# Copy your configs.
COPY nginx.conf /etc/nginx/
COPY h3.nginx.conf /etc/nginx/conf.d/
```

H3 runs over UDP so, you will need to port map both TCP and UDP. Ex: `docker run -p 80:80 -p 443:443/tcp -p 443:443/udp ...`

**NOTE**: Please note that you need a valid [CA](https://en.wikipedia.org/wiki/Certificate_authority) signed certificate for the client to upgrade you to HTTP/3. [Let's Encrypt](https://letsencrypt.org/) is a option for getting a free valid CA signed certificate.

## Contributing

Contributions are welcome. Please feel free to contribute 😊.

## Features

- HTTP/3 (QUIC) via Cloudflare's quiche
- HTTP/2 (with Server Push)
- HTTP/2
- BoringSSL (Google's flavor of OpenSSL)
- TLS 1.3 **with 0-RTT support**
- Brotli compression
- [headers-more-nginx-module](https://github.com/openresty/headers-more-nginx-module)
- [NJS](https://www.nginx.com/blog/introduction-nginscript/)
- [nginx_cookie_flag_module](https://www.nginx.com/products/nginx/modules/cookie-flag/)
- PCRE [JIT compilation](http://nginx.org/en/docs/ngx_core_module.html#pcre_jit) enabled
- Alpine Linux (total size of **10 MB** compressed)

### In this fork

- [ModSecurity for nginx](https://github.com/SpiderLabs/ModSecurity-nginx) (SpiderLabs) with [coreruleset](https://github.com/coreruleset/coreruleset/)
- BoringSSL OCSP enabled with [kn007/patch](https://github.com/kn007/patch/)
- Removed nginx debug build

## Future Additions

Possible additions in the future pending IETF spec approvals.

- [Facebook's zstd over the web](https://tools.ietf.org/html/rfc8478)

## HTTP/3 ENABLED!

Using Chrome Canary with the following CLI flags:

```bash
--flag-switches-begin --enable-quic --quic-version=h3-29 --enable-features=EnableTLS13EarlyData --flag-switches-end
```

Run on Mac OS (**darwin**):

```bash
"/Applications/Google Chrome Canary.app Contents/MacOS/Google Chrome Canary" \
  --flag-switches-begin \
  --enable-quic \
  --quic-version=h3-29 \
  --enable-features=EnableTLS13EarlyData \
  --flag-switches-end
```

Windows:

![Windows Chrome Canary](https://user-images.githubusercontent.com/13495525/68124347-21b9d380-ff4a-11e9-9963-e1102762c466.JPG)

### HTTP/3 (QUIC) Proof

Since HTTP/3 is experimental, we have to be sensible with it. Therefore, below is HTTP/3 in production on one of my web apps 🙃.

![h3](https://user-images.githubusercontent.com/7084995/67162952-831d5800-f337-11e9-9297-05241a693cc4.png)

## HTTP/2 with Server Push

![alt](https://user-images.githubusercontent.com/7084995/67162942-654ff300-f337-11e9-9dc0-6d7a915d517c.png)

## TLS v1.3

![ssllabs](https://user-images.githubusercontent.com/7084995/67164526-89b4cb00-f349-11e9-87a2-d2dc81610ed4.png)

### 0-RTT Proof

![tls-0-rtt](https://user-images.githubusercontent.com/7084995/67163692-08a50600-f340-11e9-830c-c8a11c824a1f.png)

### Testing 0-RTT

```bash
host=domain.example.com # Replace your domain.
echo -e "GET / HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n" > request.txt
openssl s_client -connect $host:443 -tls1_3 -sess_out session.pem -ign_eof < request.txt
openssl s_client -connect $host:443 -tls1_3 -sess_in session.pem -early_data request.txt
```
