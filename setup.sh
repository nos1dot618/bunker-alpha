#!/usr/bin/env bash
set -xeuo pipefail

sudo apt-get update
sudo apt-get install -y \
  libssl-dev \
  libcurl4-openssl-dev \
  libpam0g-dev
