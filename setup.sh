#!/usr/bin/env bash
set -xeuo pipefail

sudo apt-get update
sudo apt-get install -y \
  libssl-dev \
  libcurl4-openssl-dev \
  libpam0g-dev

mkdir -p "creds/"
openssl genpkey -algorithm RSA -out "creds/proxy_server.key" -pkeyopt rsa_keygen_bits:2048
# Generate a self signed certificate.
openssl req -new -x509 -key "creds/proxy_server.key" -out "creds/proxy_server.crt" -days 365
