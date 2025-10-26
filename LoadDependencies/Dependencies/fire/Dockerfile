FROM asmirnov80/for_fire AS builder

COPY . /app
WORKDIR /app/

RUN ./container_build.sh

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

ARG FIRE_VERSION=FIRE7

# only install runtimes, not development libraries / compilers
RUN apt-get update && \
    apt-get install -y libstdc++6 mpich zlib1g libgomp1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy only the built application from the builder stage
RUN mkdir -p /app/FIRE7
COPY --from=builder /local/FIRE7 /app/FIRE7
ENV LD_LIBRARY_PATH=/app/FIRE7/usr/lib:/app/FIRE7/extra/fuel/usr/lib
