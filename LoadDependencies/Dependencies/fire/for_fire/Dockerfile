FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update \
    && which mv \
    && apt-get install -y g++ \
    && g++ --version \
    && apt-get install -y curl \
    && apt-get install -y wget \
    && apt-get install -y cmake \
    && apt-get install -y libtool \
    && apt-get install -y build-essential \
    && apt-get install -y zlib1g-dev \
    && apt-get install -y git \
    && apt-get install -y autoconf \
    && apt-get install -y automake \
    && apt-get install -y mpich \
    && export RUSTUP_INIT_SKIP_PATH_CHECK=yes \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && export RUSTUP_INIT_SKIP_PATH_CHECK=yes \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
