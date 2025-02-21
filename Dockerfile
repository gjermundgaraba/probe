FROM golang:1.23-alpine AS go-builder

SHELL ["/bin/sh", "-ecuxo", "pipefail"]

RUN apk add --no-cache ca-certificates build-base git

WORKDIR /code

ADD go.mod go.sum ./
RUN set -eux; \
    export ARCH=$(uname -m); \
    WASM_VERSION=$(go list -m all | grep github.com/CosmWasm/wasmvm || true); \
    if [ ! -z "${WASM_VERSION}" ]; then \
      WASMVM_VERS=$(echo $WASM_VERSION | awk '{print $2}');\
      wget -O /lib/libwasmvm_muslc.$(uname -m).a https://github.com/CosmWasm/wasmvm/releases/download/${WASMVM_VERS}/libwasmvm_muslc.$(uname -m).a;\
    fi; \
    go mod download;

# Copy over code
COPY . /code

# force it to use static lib (from above) not standard libgo_cosmwasm.so file
# then log output of file /code/bin/probed
# then ensure static linking
RUN LEDGER_ENABLED=false BUILD_TAGS=muslc LINK_STATICALLY=true make build

# --------------------------------------------------------
FROM alpine:3.16

COPY --from=go-builder /code/build/probed /usr/bin/probed

# Install dependencies used for Starship
RUN apk add --no-cache curl make bash jq sed

WORKDIR /opt

# rest server, tendermint p2p, tendermint rpc
EXPOSE 1317 26656 26657

CMD ["/usr/bin/probed", "version"]
