
# bump: kvazaar /KVAZAAR_VERSION=([\d.]+)/ https://github.com/ultravideo/kvazaar.git|^2
# bump: kvazaar after ./hashupdate Dockerfile KVAZAAR $LATEST
# bump: kvazaar link "Release notes" https://github.com/ultravideo/kvazaar/releases/tag/v$LATEST
ARG KVAZAAR_VERSION=2.1.0
ARG KVAZAAR_URL="https://github.com/ultravideo/kvazaar/archive/v$KVAZAAR_VERSION.tar.gz"
ARG KVAZAAR_SHA256=bbdd3112182e5660a1c339e30677f871b6eac1e5b4ff1292ee1ae38ecbe11029

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG KVAZAAR_URL
ARG KVAZAAR_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O kvazaar.tar.gz "$KVAZAAR_URL" && \
  echo "$KVAZAAR_SHA256  kvazaar.tar.gz" | sha256sum --status -c - && \
  mkdir kvazaar && \
  tar xf kvazaar.tar.gz -C kvazaar --strip-components=1 && \
  rm kvazaar.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/kvazaar/ /tmp/kvazaar/
WORKDIR /tmp/kvazaar
RUN \
  apk add --no-cache --virtual build \
    build-base autoconf automake libtool pkgconf && \
  ./autogen.sh && \
  ./configure --disable-shared --enable-static && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path kvazaar && \
  ar -t /usr/local/lib/libkvazaar.a && \
  readelf -h /usr/local/lib/libkvazaar.a && \
  # Cleanup
  apk del build

FROM scratch
ARG ALPINE_VERSION
ARG KVAZAAR_VERSION
COPY --from=build /usr/local/lib/pkgconfig/kvazaar.pc /usr/local/lib/pkgconfig/kvazaar.pc
COPY --from=build /usr/local/lib/libkvazaar.a /usr/local/lib/libkvazaar.a
COPY --from=build /usr/local/include/kvazaar.h /usr/local/include/kvazaar.h
