# Сборка fnota

Текущий проект рассчитан на Apple Silicon и macOS 27+. Используйте Xcode с SDK macOS 27, установленные Command Line Tools и рабочий `xcode-select`.

## Нативные зависимости

Разместите артефакты arm64 в `UniversalMac/Vendor`. Имена и пути используются Xcode и скриптом упаковки.

| Компонент | Файлы внутри Vendor |
| --- | --- |
| [sherpa-onnx v2.0.0](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v2.0.0), macOS arm64 shared no-TTS | `sherpa-onnx-v2.0.0-osx-arm64-shared-no-tts/lib/{libsherpa-onnx-c-api.dylib,libonnxruntime.dylib}` |
| [CTranslate2 4.8.3](https://github.com/OpenNMT/CTranslate2/tree/v4.8.3) | Заголовки в `CTranslate2-4.8.3/include`, библиотека `native-libs/libctranslate2.4.8.3.dylib` |
| [SentencePiece 0.2.1](https://github.com/google/sentencepiece/tree/v0.2.1) | Заголовки в `sentencepiece-0.2.1/src`, статическая библиотека `native-libs/libsentencepiece.a` |

Сборка из чистого клона требует самостоятельной подготовки библиотек. Автоматического установщика зависимостей пока нет. При сборке собственных библиотек проверьте их загрузочные пути командой `otool -L`. Скрипт перенастраивает install name CTranslate2 на путь к библиотеке внутри приложения.

```sh
bash UniversalMac/script/build_and_run.sh --build-only
```

Скрипт собирает и ad hoc подписывает приложение в `UniversalMac/dist.noindex/fnota.app`. Для создания локального DMG выполните `bash UniversalMac/script/package_release.sh`. Модели устанавливаются отдельно в приложении. Библиотеки и модели сохраняют свои лицензии при распространении.

Исторические заметки в `UniversalMac/docs` и отдельные тестовые скрипты содержат предположения о каталогах моделей и могут расходиться с текущими настройками. Основной вход для сборки — `UniversalMac/UniversalMac.xcodeproj`.
