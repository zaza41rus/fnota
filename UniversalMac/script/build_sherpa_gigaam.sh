#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
revision=411c7c3ed6232348add92537fdfd61f7f5b6588d
work="$(mktemp -d "${TMPDIR:-/tmp}/fnota-sherpa.XXXXXX")"
trap 'rm -rf "$work"' EXIT

git init --quiet "$work/source"
git -C "$work/source" fetch --depth 1 https://github.com/ai-babai/sherpa-onnx.git "$revision"
git -C "$work/source" checkout --quiet --detach FETCH_HEAD
cmake -S "$work/source" -B "$work/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=ON -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_ENABLE_TTS=OFF -DSHERPA_ONNX_ENABLE_SPEAKER_DIARIZATION=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  -DSHERPA_ONNX_USE_PRE_INSTALLED_ONNXRUNTIME_IF_AVAILABLE=OFF
cmake --build "$work/build" --target sherpa-onnx-c-api

destination="$root/Vendor/sherpa-onnx-gigaam-preview-osx-arm64/lib"
mkdir -p "$destination"
cp "$work/build/lib/libsherpa-onnx-c-api.dylib" "$destination/"
cp "$work/build/_deps/onnxruntime-src/lib/libonnxruntime.dylib" "$destination/"
