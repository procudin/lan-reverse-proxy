FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    bsdextrautils build-essential ca-certificates curl file gawk gettext-base git jq \
    libncurses-dev libssl-dev python3 python3-setuptools rsync unzip \
    wget xsltproc zlib1g-dev zstd swig \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 builder && mkdir -p /cache /work && chown builder:builder /cache /work
USER builder
WORKDIR /work
