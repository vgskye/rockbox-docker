FROM debian:trixie-20260803@sha256:34cd9e9fd437c0a095ec39cb2e73422c9f30821b0d0848ed74fd0d43bae4d958 AS snap

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
RUN apt-get -y install unzip build-essential zip apksigner libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses6:i386
RUN wget -O /zulu17.deb https://cdn.azul.com/zulu/bin/zulu17.68.17-ca-jdk17.0.20-linux_amd64.deb
RUN apt-get -y install /zulu17.deb
RUN rm /zulu17.deb

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

RUN apt-get install -y ccache strip-nondeterminism qt6-base-dev qt6-tools-dev qt6-5compat-dev qt6-svg-dev qt6-multimedia-dev qt6-speech-dev libxkbcommon-dev cmake pkg-config libusb-1.0-0-dev

RUN rm /bin/sh && ln -s /bin/bash /bin/sh
RUN mkdir -p /android-sdk/tools/bin
COPY avdmanager /android-sdk/tools/bin

ENV ANDROID_SDK_PATH=/android-sdk ANDROID_NDK_PATH=/android-ndk ANDROID_NDK_ROOT=/android-ndk PATH=/rbtoolchain/bin:$PATH