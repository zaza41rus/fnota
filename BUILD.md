# Build fnota

Use an Apple Silicon Mac running macOS 27 or later, with the macOS 27 SDK, Xcode Command Line Tools, and an active Xcode installation selected with `xcode-select`.

## Native dependencies

Place these arm64 artifacts under `UniversalMac/Vendor`. The Xcode project and packaging scripts use the paths below.

| Component | Paths under Vendor |
| --- | --- |
| [sherpa-onnx GigaAM preview](https://github.com/ai-babai/sherpa-onnx/tree/411c7c3ed6232348add92537fdfd61f7f5b6588d), macOS arm64 | `sherpa-onnx-gigaam-preview-osx-arm64/lib/{libsherpa-onnx-c-api.dylib,libonnxruntime.dylib}` |
| [CTranslate2 4.8.3](https://github.com/OpenNMT/CTranslate2/tree/v4.8.3) | Headers in `CTranslate2-4.8.3/include`, library `native-libs/libctranslate2.4.8.3.dylib` |
| [SentencePiece 0.2.1](https://github.com/google/sentencepiece/tree/v0.2.1) | Headers in `sentencepiece-0.2.1/src`, static library `native-libs/libsentencepiece.a` |

A fresh clone requires you to prepare these libraries. With CMake and Ninja installed, run `bash UniversalMac/script/build_sherpa_gigaam.sh` to build the pinned sherpa-onnx revision and stage it with ONNX Runtime. Check custom library load paths with `otool -L`. The build script updates the CTranslate2 install name to point inside the app bundle.

```sh
bash UniversalMac/script/build_and_run.sh --build-only
```

The script creates an ad hoc signed app at `UniversalMac/dist.noindex/fnota.app`. To build a local disk image, run `bash UniversalMac/script/package_release.sh`. Install models separately in fnota. Keep the native library and model license notices when redistributing them.

The main build entry point is `UniversalMac/UniversalMac.xcodeproj`. Some development notes and tests in the source tree refer to historical model paths.
