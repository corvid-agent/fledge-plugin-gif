#!/bin/sh
set -e
swift build -c release
mkdir -p bin
cp .build/release/fledge-plugin-gif bin/fledge-gif
