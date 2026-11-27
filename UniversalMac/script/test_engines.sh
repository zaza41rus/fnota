#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT_DIR="$PWD"
BUILD_DIR="$(mktemp -d /tmp/universalmac-test.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT
NATIVE_LIB="$ROOT_DIR/Vendor/sherpa-onnx-gigaam-preview-osx-arm64/lib"
clang -c NativeCore/NativeBridge.c -o "$BUILD_DIR/speech.o"
clang++ -w -std=c++17 -c NativeCore/TranslationBridge.cc -I Vendor/CTranslate2-4.8.3/include -I Vendor/sentencepiece-0.2.1/src -o "$BUILD_DIR/translation.o"
swiftc -swift-version 6 -parse-as-library Models/ModelManifest.swift Services/Localization.swift Services/SpeechEngine.swift Services/TranslationEngine.swift Services/BPETokenizer.swift Tests/EngineSmoke.swift -import-objc-header NativeCore/include/NativeBridge.h "$BUILD_DIR/speech.o" "$BUILD_DIR/translation.o" Vendor/native-libs/libsentencepiece.a Vendor/native-libs/libctranslate2.4.8.3.dylib -L "$NATIVE_LIB" -lsherpa-onnx-c-api -lc++ -Xlinker -rpath -Xlinker "$NATIVE_LIB" -Xlinker -rpath -Xlinker "$ROOT_DIR/dist.noindex/UniversalMac.app/Contents/Frameworks" -o "$BUILD_DIR/test"
install_name_tool -change /DLC/ctranslate2/.dylibs/libctranslate2.4.8.3.dylib @rpath/libctranslate2.4.8.3.dylib "$BUILD_DIR/test"
"$BUILD_DIR/test" "$1" "$ROOT_DIR/DevModels/gigaam-v3-e2e-ctc-int8" "$ROOT_DIR/../models/translate-en_ru-1_9"
