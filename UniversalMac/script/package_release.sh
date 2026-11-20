#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/dist.noindex/fnota.app"
RELEASE_DIR="$ROOT_DIR/release"
STAGE_DIR="$(mktemp -d /tmp/universalmac-dmg.XXXXXX)"
RW_IMAGE="$STAGE_DIR/../$(basename "$STAGE_DIR")-rw.dmg"
MOUNT_DIR="$(mktemp -d /tmp/universalmac-volume.XXXXXX)"
cleanup() { hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true; rm -rf "$STAGE_DIR"; rm -f "$RW_IMAGE"; rmdir "$MOUNT_DIR" 2>/dev/null || true; }
trap cleanup EXIT
mkdir -p "$RELEASE_DIR"
codesign --verify --deep --strict "$APP"
ditto "$APP" "$STAGE_DIR/fnota.app"
ln -s /Applications "$STAGE_DIR/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE_DIR/.VolumeIcon.icns"
SetFile -a C "$STAGE_DIR"
cat > "$STAGE_DIR/Установка.txt" <<'GUIDE'
fnota 0.1.0
Apple Silicon (M1 и новее), macOS 27 и новее.

1. Перетащите fnota.app на папку Applications.
2. Откройте приложение из Applications. Нажмите значок волны в верхней
   строке меню. Если модели ещё не установлены, нажмите Install model
   возле Dictation или Browser translation.
3. При недостающих разрешениях в меню появится Permissions. Нажмите
   этот пункт и Continue в пошаговом окне. Разрешите микрофон и Универсальный доступ
   (в macOS 27 — Device Control and Data Access).
4. Для перевода Chrome откройте обычную страницу, затем меню
   View → Developer → Allow JavaScript from Apple Events: нужна галочка.
5. Для Safari включите Develop → Allow JavaScript from Apple Events.
   При необходимости включите меню Develop в Settings → Advanced.
6. Приложение проверяет запущенные браузеры автоматически и показывает
   только проблемы. Системные запросы
   автоматизации нужно подтвердить самостоятельно на каждом Mac.

Управление: удерживать fn для диктовки, отпустить для вставки.
fn два раза быстро — перевод выделения; без выделения — всей страницы Safari/Chrome.
Повторное нажатие возвращает оригинал. Клавиши фиксированы: fn и fn ×2.

Библиотеки внутри приложения. Раскройте Dictation / Browser translation
в меню значка и нажмите имя модели: откроется управление моделями.
Без модели доступна кнопка Install model. В Settings внутри меню
меняются язык интерфейса и запуск при входе. После скачивания работа полностью локальная.
Модели хранятся в ~/Library/Application Support/UniversalMac/Models;
их можно выбирать, удалять и скачивать повторно. Запуск терминала, исходники, Python и сервер не нужны.
Настройки macOS хранятся системой отдельно — это нормальная работа macOS.
Не запускайте приложение прямо с образа: сначала скопируйте в Applications.

Эта локальная сборка имеет ad-hoc подпись, без Developer ID/notarization.
При передаче на другой Mac Gatekeeper может запросить отдельное разрешение
в System Settings → Privacy & Security. Не отключайте защиту системы.
Для обычной установки без такого предупреждения нужен релиз, подписанный
сертификатом Apple Developer ID и прошедший notarization.

PDF не поддерживается. Работа с закрытой крышкой включается вместе с режимом бодрствования.
При первом включении нужна установка системного помощника с подтверждением администратора.
Удаление помощника: Settings → About fnota → Remove closed-lid helper.
GUIDE
hdiutil create -volname fnota -srcfolder "$STAGE_DIR" -format UDRW -ov "$RW_IMAGE"
hdiutil attach -nobrowse -mountpoint "$MOUNT_DIR" "$RW_IMAGE" >/dev/null
SetFile -a C "$MOUNT_DIR"
hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$RW_IMAGE" -format UDZO -ov -o "$RELEASE_DIR/fnota-0.1.0-arm64.dmg"
swift "$ROOT_DIR/script/set_file_icon.swift" "$APP/Contents/Resources/AppIcon.icns" "$RELEASE_DIR/fnota-0.1.0-arm64.dmg"
shasum -a 256 "$RELEASE_DIR/fnota-0.1.0-arm64.dmg" > "$RELEASE_DIR/SHA256SUMS.txt"
echo "$RELEASE_DIR/fnota-0.1.0-arm64.dmg"
