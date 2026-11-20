#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
BUILD_DIR="$(mktemp -d /tmp/um-speech-integration.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT
NATIVE_LIB="$ROOT_DIR/Vendor/sherpa-onnx-v2.0.0-osx-arm64-shared-no-tts/lib"
clang -c NativeCore/NativeBridge.c -o "$BUILD_DIR/speech.o"
swiftc -swift-version 6 -parse-as-library Models/ModelManifest.swift Services/Localization.swift Services/ModelStore.swift Services/SpeechEngine.swift Tests/SpeechCatalogIntegrationSmoke.swift -import-objc-header NativeCore/include/NativeBridge.h "$BUILD_DIR/speech.o" -L "$NATIVE_LIB" -lsherpa-onnx-c-api -Xlinker -rpath -Xlinker "$NATIVE_LIB" -o "$BUILD_DIR/test"
"$BUILD_DIR/test" "${1:?model root required}"
