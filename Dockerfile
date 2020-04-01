#
# Building V8 for alpine is a real pain. We have to compile from source, because it has to be
# linked against musl, and we also have to recompile some of the build tools as the official
# build workflow tends to assume glibc by including vendored tools that link against it.
#
# The general strategy is this:
#
#   1. Build GN for alpine (this is a build dependency)
#   2. Use depot_tools to fetch the V8 source and dependencies (needs glibc)
#   3. Build V8 for alpine
#
# STEP 1
# Build GN for alpine
#
FROM alpine:latest as gn-builder

# This is the GN commit that we want to build. Most commits will probably build just fine but
# this happened to be the latest commit when I did this.
ARG GN_COMMIT=82d673acb802cee21534c796a59f8cdf26500f53

RUN echo 1

RUN \
  apk add --update --virtual .gn-build-dependencies \
    alpine-sdk \
    binutils-gold \
    clang \
    curl \
    git \
    llvm9 \
    ninja \
    python \
    tar \
    xz \

  # Two quick fixes: we need the LLVM tooling in $PATH, and we
  # also have to use gold instead of ld.
  && PATH=$PATH:/usr/lib/llvm9/bin \
  && cp -f /usr/bin/ld.gold /usr/bin/ld \

  # Clone and build gn
  && git clone https://gn.googlesource.com/gn /tmp/gn \
  && git -C /tmp/gn checkout ${GN_COMMIT} \
  && cd /tmp/gn \
  && python build/gen.py \
  && ninja -C out \
  && cp -f /tmp/gn/out/gn /usr/local/bin/gn \

  # Remove build dependencies and temporary files
  && apk del .gn-build-dependencies \
  && rm -rf /tmp/* /var/tmp/* /var/cache/apk/*

#
# STEP 2
# Use depot_tools to fetch the V8 source and dependencies
#
# The depot_tools scripts have a hard dependency on glibc (or at least a soft one that I didn't
# bother figuring out). Fortunately we only need it to actually download the source and its dependencies
# so we can do this in a place with glibc, and then pass the results on to an alpine builder.
#
FROM debian:9 as source

# The V8 version we want to use. It's assumed that this will be a version tag, but it's just
# used as "git commit $V8_VERSION" so anything that git can resolve will work.
ARG V8_VERSION=8.0.426.27

RUN \
  set -x && \
  apt-get update && \
  apt-get install -y \
    git \
    curl \
    python && \

  # Clone depot_tools
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /tmp/depot_tools && \
  PATH=$PATH:/tmp/depot_tools && \

  # fetch V8
  cd /tmp && \
  fetch v8 && \
  cd /tmp/v8 && \
  git checkout ${V8_VERSION} && \
  gclient sync && \

  # cleanup
  apt-get remove --purge -y \
    git \
    curl \
    python && \
  apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/*

#
# STEP 3
# Build V8 for alpine
#
FROM alpine:latest as v8

COPY --from=source /tmp/v8 /tmp/v8
COPY --from=gn-builder /usr/local/bin/gn /tmp/v8/buildtools/linux64/gn

RUN \
  apk add --update --virtual .v8-build-dependencies \
    curl \
    g++ \
    gcc \
    glib-dev \
    icu-dev \
    libstdc++ \
    linux-headers \
    make \
    ninja \
    python \
    tar \
    xz \

  # Configure our V8 build
  && cd /tmp/v8 && \
  ./tools/dev/v8gen.py x64.release -- \
    binutils_path=\"/usr/bin\" \
    target_os=\"linux\" \
    target_cpu=\"x64\" \
    v8_target_cpu=\"x64\" \
    v8_enable_future=true \
    is_official_build=true \
    is_component_build=true \
    is_cfi=false \
    is_clang=false \
    use_custom_libcxx=false \
    use_sysroot=false \
    use_gold=false \
    use_allocator_shim=false \
    treat_warnings_as_errors=false \
    symbol_level=0 \
    strip_debug_info=true \
    v8_use_external_startup_data=false \
    v8_enable_i18n_support=false \
    v8_enable_gdbjit=false \
    v8_static_library=true \
    v8_experimental_extra_library_files=[] \
    v8_extra_library_files=[] \

  # Build V8
  && ninja -C out.gn/x64.release -j $(getconf _NPROCESSORS_ONLN) \

  # Brag
  && find /tmp/v8/out.gn/x64.release -name '*.a'

#
# STEP 4
# Export libv8 to /v8
#

RUN mkdir /v8
RUN mkdir /v8/lib
RUN cp -R /tmp/v8/include /v8/include
RUN cp /tmp/v8/out.gn/x64.release/d8 /v8/lib/
RUN cp /tmp/v8/out.gn/x64.release/libchrome_zlib.so /v8/lib/
RUN cp /tmp/v8/out.gn/x64.release/libv8.so /v8/lib/
RUN cp /tmp/v8/out.gn/x64.release/libv8_libbase.so /v8/lib/
RUN cp /tmp/v8/out.gn/x64.release/libv8_libplatform.so /v8/lib/
RUN strip --strip-debug --strip-unneeded /v8/lib/*.so
RUN ls /v8

RUN echo done
