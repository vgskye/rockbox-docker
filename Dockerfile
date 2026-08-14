FROM debian:bookworm-20260803@sha256:813017f3d62be4b5891a7acca6a01bdcd4b8513daa81b1ab99d3a50385b26931 AS snap

COPY docker-snapshot /etc/apt/apt.conf.d/
COPY debian.sources /etc/apt/sources.list.d/debian.sources

FROM snap AS base

RUN apt-get update
RUN apt-get install -y \
    build-essential \
    git \
    perl \
    curl \
    texinfo \
    flex \
    bison \
    bzip2 \
    gettext \
    gtk-doc-tools \
    gzip \
    zip \
    patch \
    automake \
    libtool \
    libtool-bin \
    autoconf \
    libmpc-dev \
    gawk \
    python3 \
    python3-lzo \
    python3-setuptools \
    mtd-utils \
    xorriso \
    wget \
    subversion \
    libncurses5-dev \
    texlive-latex-base \
    texlive-binaries \
    texlive-latex-extra \
    tex4ht \
    texlive-fonts-recommended \
    lmodern \
    texlive-base \
    libsdl1.2-dev \
    libsdl1.2debian \
    libsdl2-dev

FROM base as toolchain

RUN mkdir /rockbox
RUN cd /rockbox && git init
# GitHub mirror is faster
RUN cd /rockbox && git remote add origin https://github.com/Rockbox/rockbox.git
RUN cd /rockbox && git fetch --depth 1 origin 2d2b03d314455112afa7dd8d369874ae0233a3e1
RUN cd /rockbox && git checkout FETCH_HEAD

ENV MAKEFLAGS -j$(nproc)
ENV SOURCE_DATE_EPOCH 0

RUN cd /rockbox && ./tools/rockboxdev.sh --target=x --prefix=/rbtoolchain
RUN cd /rockbox && ./tools/rockboxdev.sh --target=y --prefix=/rbtoolchain
RUN cd /rockbox && ./tools/rockboxdev.sh --target=m --prefix=/rbtoolchain
RUN cd /rockbox && ./tools/rockboxdev.sh --target=a --prefix=/rbtoolchain
RUN cd /rockbox && ./tools/rockboxdev.sh --target=i --prefix=/rbtoolchain

FROM base AS ndk-base

RUN dpkg --add-architecture i386 && apt-get update 
RUN apt-get -y install unzip openjdk-17-jdk build-essential zip apksigner libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386

FROM ndk-base AS ndk

RUN wget -O /sdk.zip https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip

RUN unzip /sdk.zip && rm /sdk.zip
RUN mkdir -p /android-sdk/cmdline-tools
RUN mv /cmdline-tools /android-sdk/cmdline-tools/latest

RUN yes | /android-sdk/cmdline-tools/latest/bin/sdkmanager --install "platforms;android-19" "build-tools;19.1.0"

RUN wget -O /ndk.zip https://dl.google.com/android/repository/android-ndk-r10e-linux-x86_64.zip
RUN unzip /ndk.zip && rm /ndk.zip && mv /android-ndk-r10e /android-ndk

FROM ndk-base

COPY --from=toolchain /rbtoolchain /rbtoolchain
COPY --from=ndk /android-ndk /android-ndk
COPY --from=ndk /android-sdk /android-sdk

RUN apt-get install -y ccache strip-nondeterminism qt6-base-dev qt6-tools-dev qt6-5compat-dev qt6-svg-dev qt6-svg-dev qt6-multimedia-dev libxkbcommon-dev cmake pkg-config
# qt6-base-dev qt6-tools-dev qt6-5compat-dev qt6-svg-dev qt6-svg-dev build-essential cmake pkg-config qt6-multimedia-dev libxkbcommon-dev

ENV ANDROID_SDK_PATH=/android-sdk ANDROID_NDK_PATH=/android-ndk ANDROID_NDK_ROOT=/android-ndk PATH=/rbtoolchain/bin:$PATH