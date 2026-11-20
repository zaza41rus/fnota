# Управление

## По умолчанию

- Fn ×2: выделен текст — перевод выделения; нет выделения — перевод всей страницы Safari/Chrome. Повторное нажатие возвращает оригинал в выбранной области. Без выделения возвращается весь сохранённый оригинал.
- Fn: удерживать во время речи, отпустить для распознавания и вставки. Результат также остаётся в системном буфере обмена. При недоступной автовставке используйте ⌘V.
- Длительность записи не ограничена таймером: запись идёт до отпускания Fn. Длинное аудио читается с диска частями по 25 секунд, чтобы ограничивать память распознавания. На стыках частей возможны ошибки распознавания. Распознавание выполняется после отпускания клавиши, без отправки аудио в сеть. Во время записи выход звука Mac заглушается; после остановки возвращается прежнее состояние.

## Изменение клавиш

Откройте «Настройки», нажмите кнопку рядом с переводом или голосовым вводом, затем нажмите новое сочетание. Esc отменяет настройку. Fn используется с двумя разными жестами: удержание для записи, два быстрых нажатия для перевода. Fn можно назначить отдельной клавишей, для остальных сочетаний нужен модификатор ⌘, ⌥, ⌃ или ⇧. Настройки сохраняются между запусками. Одинаковые обычные сочетания для двух действий не принимаются; Fn разрешена для обоих, поскольку жесты различаются. Для голосовой комбинации, отличной от Fn, можно выбрать удержание или переключение повторным нажатием.

Если сочетание занято другой программой, приложение показывает ошибку регистрации. После предоставления Универсального доступа нажмите «Переподключить клавиши». Fn отслеживается через системный event tap; настройки самой macOS для Fn/Globe не изменяются приложением.

## Вставка

При начале записи запоминаются поле, выделение и текст. После распознавания вставка выполняется только если фокус, выделение и содержимое поля сохранились. Accessibility используется для проверки поля и фокуса; сама диктовка вставляется обычной командой ⌘V, чтобы редакторы не заменяли всё содержимое при AXSelectedText. При потере фокуса текст остаётся в буфере и окне приложения. Парольные поля исключены. Буфер намеренно содержит последнюю диктовку, согласно выбранному пользователем поведению.

## Перевод

В редактируемом тексте используется Accessibility с сохранением выделения результата для обратного переключения. В Safari/Chrome DOM-модуль сохраняет оригинальные текстовые узлы, делит их только на границах выделения и не пересоздаёт ссылки или разметку. Код, формы, editable-поля и translate=no исключены из перевода всей страницы. Пока перевод выполняется, повторное нажатие отменяет его и возвращает изменения этой операции. Изменения самой страницы не перезаписываются при восстановлении.

В других приложениях переводится доступное выделение, а не всё произвольное окно. Для read-only текста результат показывается поверх окна. В браузерах нужно отдельно разрешить JavaScript из Apple Events и автоматизацию для UniversalMac. Внутренние страницы браузеров, PDF-вкладки и чужие iframe не гарантируются.

## Проверено 2026-10-23

- Сборка Xcode, запуск .app и регистрация горячих клавиш.
- Пользователь подтвердил физическую Fn: удержание, вставку в активное поле и результат в буфере обмена.
- Изолированный WebKit: выделение, повторный возврат, перевод страницы, возврат выделения после страницы и затем всего оригинала, исключение полей/кода, откат отменённой операции, отказ от устаревшей операции.
- Реальное выполнение новой браузерной команды в Safari и Chrome ещё требует приёмки; тест WebKit не заменяет эту проверку.

Тест DOM: `swiftc -swift-version 6 -parse-as-library UniversalMac/Tests/BrowserToggleSmoke.swift -o /tmp/universalmac-browser-toggle-test` и `/tmp/universalmac-browser-toggle-test "$PWD/UniversalMac/Resources/browserTranslation.js"` из корня репозитория.

## Дополнение: продолжение диктовки и звук

Системная вставка диктовки оставляет курсор после новой фразы. При следующем запуске перед новой фразой добавляется пробел, если предыдущий символ не пробельный. В окне помощника результат также накапливается. В буфере остаётся последний фрагмент для ручной вставки, а кнопка «Скопировать результат» копирует накопленный текст.

Выход звука заглушается только на время записи, исходное mute-состояние возвращается при отпускании клавиши, ошибке запуска и штатном завершении. Для восстановления после аварийного выхода исходное состояние сохраняется в настройках и проверяется при следующем запуске. Аппаратные устройства без поддержки свойства mute возвращают понятную ошибку. Переключение устройства вывода во время записи отдельно не проверено.

Проверка длинного аудио: файл 136,449 с успешно распознан через тот же Swift-адаптер, прежнее ограничение 120 с удалено. Время тестового распознавания — около 4 с на текущем Mac; это не гарантия для любой речи и длины файла.

Safari: пользователь подтвердил работу перевода. Chrome: остаётся отказ JavaScript из Apple Events; успех перевода в Chrome не подтверждён.

## Обновление управления одной клавишей

- Удержание Fn дольше 0,22 с запускает диктовку до отпускания. Два коротких нажатия с промежутком до 0,35 с запускают перевод / возврат оригинала без записи микрофона.
- Быстрый одиночный тап ничего не делает. Если второе нажатие удерживать, запускается диктовка вместо перевода.
- Дубли и отмена event tap сбрасывают состояние; незавершённый короткий тап не переносится на новую регистрацию.
- «Не давать компьютеру заснуть» — переключатель без таймера. Выключение возвращает штатный сон macOS. Защита при низком заряде батареи и перегреве сохранена.
- PDF-модуль и импорты PDFKit/Vision удалены. PDF-функций в приложении нет.

Проверено: тесты автомата Fn; включение/выключение IOPM assertion через UI и pmset; отсутствие PDFKit/Vision в прямых зависимостях установленного executable. Физический двойной Fn проверяется пользователем отдельно.

## Системная панель и бодрствование дисплея

Верхняя панель использует публичный MenuBarExtra.window и стандартный SwiftUI Toggle.switch: без нарисованного вручную переключателя и частных контролов Wi-Fi. Включённый режим создаёт два IOPM assertion: PreventUserIdleSystemSleep и PreventUserIdleDisplaySleep. Оба освобождаются при выключении и завершении приложения; выбор пользователя сохраняется для следующего запуска. Защиты при перегреве и низком заряде сохранены.

Диагностика на целевом Mac: старый режим удерживал только систему, а параметры Lock Screen разрешали выключить дисплей через 2 минуты на батарее / 10 минут от адаптера и требовали пароль через 5 минут после этого. Журнал также содержит Clamshell Sleep — закрытие крышки не подавляется. Настройки пароля и блокировки не изменялись. Проверено создание обоих реальных assertion через pmset; длительная проверка полного интервала простоя отдельно не проводилась.

## Только настройки и вставка в активное поле

Главное окно и страницы ручной диктовки/перевода удалены. Приложение запускается в фоне без активации и не открывает окно поверх браузера. В панели меню остаются действия и «Настройки…». Настройки используют стандартную сцену Settings с вкладками «Основные», «Модели», «Сон и питание». Службы запускаются из AppDelegate и не зависят от открытия настроек.

Перед записью панель помощника при необходимости закрывается и возвращается фокус в предыдущее внешнее приложение. Для диктовки допускается изменение текста/курсора внутри того же сфокусированного поля; смена приложения или поля по-прежнему отменяет автовставку, сохраняя результат в буфере. Перевод выделения сохраняет строгую проверку исходного текста.

Вставка после window-style панели: собственные окна скрываются до захвата поля; фокус читается через системный AXFocusedUIElement с резервом на приложение. Для веб-редакторов разрешены AXGroup/AXWebArea, а не только AXTextArea. Paste отправляется конкретному PID через CGEvent с privateState, без зависимости от глобального состояния Fn. Переход в другое приложение/поле блокирует вставку. В журнал выводятся только причина отказа/тип AX-элемента, без текста диктовки.

Когда приложение не предоставляет AXFocusedUIElement, диктовка сохраняет PID и числовой идентификатор активного окна. Вставка разрешается только при сохранении того же приложения и окна; известные защищённые поля исключены. Для настольных приложений сначала вызывается доступная системная команда Paste (⌘V) через меню; резерв — обычная системная комбинация клавиш. Для Chrome/Safari сохранена отправка в исходный PID. Отсутствие AX-поля больше не означает автоматический отказ и ручную вставку из буфера.

## Упрощённые настройки

Автозапуск представлен одним стандартным Toggle.switch. Значение читается из SMAppService.mainApp.status, а не из отдельной копии настройки; требование подтверждения macOS показывается отдельно. После возвращения из системных настроек статус обновляется.

Отдельные кнопки «Разрешить управление полями ввода» и «Переподключить клавиши» удалены. Доступ к вставке выдаётся в мастере разрешений, где назначение объяснено обычным языком. Новое сочетание регистрируется сразу после записи; изменение разрешения Accessibility отслеживается при активации приложений, без ручного переподключения. Во время записи/обработки и настройки сочетания повторная регистрация не выполняется.

В верхней панели остаются только переключатель бодрствования, «Настройки…» и «Завершить». Строки статуса сна, ручной диктовки и ручного перевода удалены. Неактивный выбор режима удержания не показывается для Fn.

## Окно настроек при Fn

Скрывается только всплывающая панель с собственным идентификатором UniversalMac.StatusPanel. Окно Settings не скрывается и не закрывается. Возврат в предыдущее внешнее приложение выполняется только при уходе из этой панели, а не при Fn внутри настроек. Проверка на настоящих окнах AppKit подтверждает, что Settings остаётся видимым в обоих случаях (Tests/SettingsWindowSmoke.swift).

## Управление моделью перевода

В «Настройки → Модели» отдельно показаны модели диктовки и перевода. Все рабочие модели хранятся в `~/Library/Application Support/UniversalMac/Models`, приложение не содержит весов. На новом Mac их нужно скачать через настройки; затем работа офлайн. Старые модели перед установкой облегчённого приложения переносит `script/migrate_models.swift` с побайтовой проверкой SHA-256; исходные файлы не удаляются этим скриптом.

Каталог диктовки содержит два проверенных варианта GigaAM v3: E2E CTC INT8 (319 871 127 байт, с пунктуацией/нормализацией) и CTC INT8 (319 183 360 байт, без встроенной пунктуации). Русский язык, MIT, sherpa-onnx на CPU. Оба экспорта закреплены на ревизии 6888903da215c7735f51101d939f3bfa679fb2b8, скачиваются со сверкой SHA-256. Загрузка идёт во временную папку; выбор меняется только после проверки обоих файлов. Можно скачать другую модель, выбрать установленную и удалить любую установленную модель; удалённая не восстанавливается сама. Другие семейства из общего каталога sherpa-onnx требуют отдельного адаптера.

Argos en→ru 1.9 занимает 216 506 540 байт (206,48 МиБ / 216,51 МБ). Поддерживаются импорт совместимой папки или .argosmodel/ZIP, официальный онлайн-каталог и скачивание. Импорт копирует файлы в управляемую папку. Модель активируется после проверки metadata en→ru, файлов CTranslate2/SentencePiece и реального пробного перевода. Ошибка сохраняет текущую модель. Перед сменой/удалением отменяется текущий перевод, выгружаются handle и кэш. Удаление допускается только для непосредственных дочерних папок управляемого хранилища перевода. В официальном каталоге на 24.10.2026 одна версия en→ru; приложение не заявляет произвольную модель совместимой.

## Multilingual catalog and independent features (24 October 2026)

The model-card interaction was checked against Handy's public `src/components/settings/models/ModelsSettings.tsx` and model selector: download/use, installed selection and delete are separate visible states. UniversalMac has a native SwiftUI implementation; it does not use Handy files, runtime or caches.

English is the default interface. General → Interface language switches between English, Russian and Spanish using native `.lproj` strings. Individual dictation, translation and Keep Awake switches persist. Disabled dictation/translation shortcuts are unregistered; a disabled feature does not delete its model automatically.

Speech catalog: GigaAM v3 E2E CTC and CTC INT8 (Russian), plus Whisper Tiny multilingual INT8, 103,609,903 bytes, pinned sherpa-onnx export revision 65176e2deb88badc814a94058666cadccc29b61c. Whisper language is detected automatically. Model cards describe language coverage and qualitative tradeoffs; there are no invented benchmark scores. Downloads use temporary folders and verified SHA-256.

Translation uses the complete official Argos language-pair catalog (100 pairs at verification). The user chooses From/To. A direct pair is preferred; otherwise a two-model route through English is offered when both packages exist. Installed cards can be selected without another download. Both SentencePiece and native subword-nmt BPE packages are supported. BPE punctuation tokenization is a native implementation, not the Python Moses runtime; four Spanish punctuation/numeric fixtures matched the Argos reference tokenizer, but complete Moses equivalence for every language is not claimed. Package compatibility is checked with actual native inference before selecting it. Catalog presence alone is not a quality benchmark. Two-hop translation may compound errors.

A two-model route holds separate engines/caches, rather than reloading both weights for every page node. Switching/deleting unloads both engines. If any saved route member is missing, it is not silently replaced with another language. Browser text collection accepts Unicode letters/numbers rather than an English-only regex; the selected source language is the user's choice. Existing original/selection restoration semantics remain unchanged.

Keep Awake: 0 = off; steps of five minutes up to 120; final step = unlimited. Optional application selection uses its bundle identifier and checks running applications every two seconds, including background applications. If absent, assertions are released while the mode waits; they are reacquired when the app starts. A finite timer keeps counting while waiting. On app relaunch an enabled finite session starts a fresh interval. Both system/display idle assertions are used; lid closing, manual lock and macOS security policy remain effective. Battery/thermal protections remain in place.

The settings window/Settings scene has been removed. All controls are under the native MenuBarExtra window: duration slider, a native menu containing only regular running applications (including Terminal), and inline DisclosureGroup sections for general settings, speech/translation models and permissions. No custom Wi-Fi artwork is used. Power-adapter-only mode is removed. The list refreshes on popover appearance and application launch/termination. A selected app remains the condition after it exits, but is not an entry in the available-running-app menu; the mode waits until it runs again.

Selecting a running application immediately enables unlimited Keep Awake. When that selected bundle identifier is no longer running, the mode turns off (slider 0), rather than waiting/restarting on a later launch. The two-second condition timer works even with the menu closed. Clearing the selection removes the application condition; the current duration remains in effect.

The final slider is 200 pt wide, with one-minute steps: 0 off, 1–120 minutes, 121 unlimited. Selecting a running app moves it to 121 automatically. Existing five-minute-scale preferences migrate once so their meaning is preserved (old 25 → unlimited, old 6 → 30 minutes).

Menu appearance: regular native control size, 14 pt body, 15 pt header. The 340 pt menu measures its content height instead of reserving a tall blank window; scrolling starts only at the screen-height cap. DisclosureGroup uses a shared public SwiftUI style: full-width native plain Button label with trailing SF chevron, so the title and the arrow both toggle expansion. Quit is a full-width plain text row pinned below the scrolling content. No Settings/WindowGroup scene or preview window is shipped.

Menu sizing follow-up: the slider has no tick marks; its binding still rounds to one-minute values. It fills available row width. The scroll content measures its uncompressed height using onGeometryChange. StatusPanelMarker forwards the capped desired size to its own public NSWindow, preserving the top/right edges, because MenuBarExtra may retain its initial frame. Scroll starts only at the available-screen-height cap. MenuPanelSizingSmoke verifies grow/shrink/top-edge/other-window isolation using real AppKit windows.

Final tray layout at user request: only Keep Awake switch, running-application menu and Settings row. No duration slider, expandable settings or Quit row in the tray. Settings uses the native SwiftUI Settings scene, with General / Models / Keep Awake / Permissions tabs; the timer and model management are retained there. The Settings action dismisses only the marked status panel and opens/activates the separate settings window. The green native switch enables unlimited Keep Awake; selecting a running app still enables it until that app closes. UI language selection remains English/Russian/Spanish. Quit is available at the bottom of General settings.

Tray follow-up: when Keep Awake is off, only its switch and Settings are visible. When on, Application and Time rows appear. The Time value shows ∞ or H:MM duration; its native popover accepts 1–120 minutes or Unlimited. Choosing time clears the application condition; choosing a running application enables Unlimited until that app closes. Switching on starts unrestricted Unlimited, clearing stale application selections. The same mutually exclusive timer behavior applies in Settings. The marked native panel resizes to the measured full menu height when these rows appear/disappear, preserving its 320 pt width and top edge.

Timer priority: Time displays remaining M:SS / H:MM:SS and updates every second in common run-loop modes. Selecting a program before setting a timer cannot keep the mode on after expiry: setting time clears the application condition. Selecting another program while a finite timer is running preserves its existing deadline and does not restart/extend it; program exit does not override that running timer. The countdown test uses an injected monotonic clock to verify program→timer, decrement, subsequent program changes and exact zero/IOPM assertion release.

Tray ordering: Keep Awake and its conditional indented Application/Time rows, divider, dictation shortcut row, divider, browser translation shortcut row, divider, Settings. No checkbox or enable toggle in the shortcut rows. Enable/disable is controlled in Settings; a disabled feature has tertiary label color and its native shortcut button is disabled. Keep Awake also reflects its feature setting rather than reenabling itself via a disabled tray switch.

Keep Awake settings tab and its duplicate controls have been removed. Sleep/application/timer control is exclusively in the tray. The separate legacy awakeEnabled feature gate is no longer used, so an old disabled preference cannot leave the only tray switch inaccessible. Dictation and translation retain their independent enable switches in General settings.

Permissions are consolidated into General; the separate Permissions tab and old multi-button wizard are removed. PermissionDiagnostics shows only missing grants/failed browser probes. If everything relevant is healthy the block disappears. Disabled dictation does not require microphone permission; Accessibility is required only while dictation/translation is enabled. One Check and set up action sequences microphone, Accessibility and automation requests; manual microphone/Accessibility steps resume automatically after the grant is detected on app activation. System approvals remain native user actions. Browser probes apply only to running Chrome/Safari, first preflight automation with askUserIfNeeded=false, then execute a constant ready-check JavaScript with a three-second timeout. They do not read page text or activate/launch browsers. Browser JavaScript-from-Apple-Events errors remain visible with browser-menu instructions. Healthy browser checks are cached for 30 seconds between activations; opening Settings forces a check and outstanding errors retry on return. A separate BrowserTranslation instance prevents probes from changing an active translation's browser/session state.

Simplified design: fixed Fn hold for dictation, double Fn for translation; shortcut customization controls and recorder implementation removed. Legacy saved custom shortcuts are ignored. Speech/translation availability is derived from the selected model files. In the tray, each available feature expands to its active model/route; clicking it opens the model management window. With no selected valid model its feature label is inactive and a separate Install model button opens management. Existing install/select/import/delete and language-pair catalog remain available. Settings expands inline to interface language and launch-at-login only. Permissions is a red row only while diagnostics has missing/failed checks; it opens a one-current-step wizard using the existing sequenced permission flow. Quit is centered at the bottom. The settings scene is reused solely for model management and the permission wizard, not general settings. Model availability changes refresh Fn registration; missing models do not leave active handlers. FeatureAvailabilitySmoke tests fixed default keys against legacy saved bindings and a real isolated model copy followed by deletion.

Menu separators now appear only at the bottom of expanded trees: enabled Keep Awake after its Application/Time rows, and each expanded dictation/translation/settings disclosure after its children. Collapsed trees and the permissions/quit rows have no permanent separators. Fn subtitles use the same 14 pt body size with secondary color. Model management is one window with Dictation and Text translation tabs; opening from the tray selects the matching tab, and users can freely switch to the other model type in that window.
