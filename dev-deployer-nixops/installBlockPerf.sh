#!/bin/bash

# Exit on any error
set -e

# Make folder for blockperf
cd /run/keys

# Make sure we do a fresh install
rm -rf blockperf

# Pull repo
git clone https://github.com/cardano-foundation/blockperf.git

# Checkout networking team branch
cd blockperf
git checkout bolt12/network-team-patch

# Create a Python virtual environment and activate it
python3 -m venv .venv
source .venv/bin/activate

# Install blockperf via pip
pip install .
