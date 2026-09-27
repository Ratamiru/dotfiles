# Как это всё обслуживать

Шелл на Quickshell + WM mango. Конфиг quickshell лежит тут (`~/.config/quickshell`),
биндинги — в `~/.config/mango/config.conf`.

## Структура

```
shell.qml              # точка входа, перечисляет все компоненты
layers/
  PowerMenu.qml         # меню выключения/перезагрузки/сна/выхода
  PowerButton.qml        # кружок-кнопка (иконка + подпись), используется везде
  PowerAction.qml         # кнопка питания + тумблер отложенного выполнения
  ToggleSwitch.qml          # переключатель вкл/выкл
  AudioSink.qml          # OSD громкости + выбор аудио-устройства
  ToolsMenu.qml           # лаунчер утилит (Super+T)
  Notes.qml                # окно заметок
  Projects.qml              # окно списка проектов
  Music.qml                 # музыкальный виджет (Super+M), см. раздел «Музыка»
  music/
    PlayerState.qml         # состояние плеера + JSON IPC с mpv
    SubsonicApi.qml         # клиент Navidrome
    CoverCarousel.qml       # 3D-карусель CD-дисков
    TrackInfo.qml / SeekBar.qml / NavArrows.qml / VolumeSlider.qml
    PillMenu.qml            # кнопка-таблетка с выпадающим списком
assets/cd/                 # меш и текстуры диска (CC-BY-4.0, см. LICENSE.txt)
fonts/                     # Orbitron, Rajdhani (OFL)
projects.json            # список проектов (редактируется руками)
notes-settings.json       # хранит путь к папке с заметками (не трогать руками)
music-settings.json       # url/user/password Navidrome — в .gitignore
music-state.json          # последний выбранный плейлист (не трогать руками)
```

## Горячие клавиши (mango)

| Клавиши | Действие |
|---|---|
| `Super+P` | Power-меню |
| `1`/`2`/`3`/`4` (при открытом power-меню) | Выключить / Перезагрузить / Сон / Выйти |
| `Super+S` | Громкость / выбор аудио-устройства |
| `XF86AudioRaiseVolume` / `LowerVolume` / `Mute` | Громкость без открытия окна |
| `Super+T` | Меню утилит |
| `n` / `p` (при открытом меню утилит) | Заметки / Проекты |
| `Super+M` | Музыка |
| `Space` / `←` / `→` (при открытой музыке) | Пауза / Пред. / След. |
| `↑` / `↓` / `F` (при открытой музыке) | Громкость ±5% / В избранное |
| `XF86AudioPlay` / `Next` / `Prev` | Пауза / След. / Пред. без открытия окна |
| `Escape` (в любом открытом окне) | Закрыть |

Биндинги — в конце `~/.config/mango/config.conf`. Всё, что делает quickshell, идёт
через `spawn,quickshell ipc call <target> <function>`.

## Как это устроено (коротко)

Каждый компонент — независимый `Scope` с `IpcHandler`, слушающим свой `target`.
Есть два типа окон:

- **Эфемерные** (PowerMenu, AudioSink, ToolsMenu) — открываются по хоткею, закрываются
  сами при клике мимо/Escape/выборе действия. Окно физически создаётся и уничтожается
  через `LazyLoader` при каждом открытии/закрытии.
- **Постоянные** (Notes, Projects) — не закрываются от клика мимо, только по крестику
  или Escape. Не перехватывают клики на остальном экране (нет фонового `MouseArea`).

Можно дёргать руками из терминала:
```sh
quickshell ipc call powermenu toggle
quickshell ipc call audiosink toggle
quickshell ipc call notes activate      # открыть (не toggle!)
quickshell ipc call projects activate
quickshell ipc call toolsmenu toggle
quickshell ipc call music toggle        # и playPause / next / previous
```
⚠️ `show` как имя IPC-функции не использовать — это зарезервированное слово в CLI
quickshell (`quickshell ipc show`), вызов молча ничего не сделает. Для "открыть"
используется имя `activate`.

## Проекты (`projects.json`)

Правится руками. Формат:
```json
[
  { "name": "quickshell", "path": "/home/ratamiru/.config/quickshell" },
  { "name": "Katana like", "path": "/mnt/bigchita/projects/GODOT/katana-like/" }
]
```
- Не забывайте запятые между объектами и между полями — файл читается через
  `JSON.parse`, при синтаксической ошибке список молча станет пустым (без явной
  ошибки на экране).
- Изменения подхватываются на лету (`watchChanges: true`) — не нужно перезапускать
  quickshell, просто сохраните файл.
- Клик по проекту открывает `foot -D <path>` (терминал в этой директории).

## Заметки

- Папка с заметками меняется прямо в шапке окна (поле пути, Enter — применить).
  Текущее значение хранится в `notes-settings.json`, руками его лучше не редактировать.
- Папка создаётся автоматически при сохранении первой заметки в ней.
- Автосохранение — через 800мс после последней правки, плюс форс-сохранение при
  переключении файла/папки/закрытии окна.

## Музыка

Navidrome (`http://debian:4533`, tailnet) → mpv. Креды — в `music-settings.json`:
```json
{ "url": "http://debian:4533", "user": "...", "password": "..." }
```

- **mpv** — отдельный процесс (`mpv --idle --input-ipc-server=$XDG_RUNTIME_DIR/mpv-music.sock`),
  поднимается лениво при первом play. Закрытие окна и даже рестарт quickshell музыку
  не останавливают — при старте виджет просто переподключается к сокету.
  Остановить совсем: `pkill -f '^[^ ]*mpv .*mpv-music'`.
- В mpv загружается **весь** плейлист, поэтому следующий трек mpv включает сам.
- Выбор источника — кнопка справа сверху; сразу начинает играть с первого трека.
  «Вся библиотека» — до 500 треков, «★ Избранное» — треки со звёздочкой в Navidrome.
- ♥ в шапке (или `F`) — поставить/снять звёздочку текущему треку (прямо в Navidrome).
  Если снять её в «Избранном», трек пропадёт из списка при следующей загрузке.
- Сортировка — кнопка рядом с источником; запоминается в `music-state.json`.
  Играющий трек не прерывается: в mpv `playlist-clear` (оставляет текущий) +
  дописываем остальные + `playlist-move`. Порядок в виджете при подключении
  подстраивается под плейлист mpv (observe `playlist`), так что рестарт quickshell
  после «Случайно» ничего не ломает.
- Клик по соседнему диску — играть его, по центральному — пауза; колесо — листать.
- Модель диска: `cd disk.glb` → `balsam` → `assets/cd/meshes/disc.mesh`. UV наклейки
  в исходнике были кусками старого атласа — перед конвертом переписаны на планарную
  проекцию 0..1 (обложка на весь диск). Текстуры корпуса ужаты до 512×512.
- Грабли: Quickshell `Socket` после неудачного подключения залипает навсегда
  (повторный `connected = true` ничего не делает, `destroy()` запрещён) —
  поэтому сокет живёт в `LazyLoader` и пересоздаётся на каждую попытку.

## Отладка

Логи конкретного запуска — в строке `Saving logs to ...` при старте:
```sh
quickshell                      # запустить в терминале, увидите ERROR/WARN сразу
cat /run/user/1000/quickshell/by-id/<id>/log.qslog
```
Частые грабли в этом конфиге (на будущее, если будете править QML):
- **Anchors внутри `Row`/`Column`**: нельзя анкорить ось, которой управляет
  позиционер (`left/right/horizontalCenter/fill/centerIn` — в `Row`; `top/bottom/…` —
  в `Column`). Ловится как `WARN scene: ... Row will not function`.
- **`Component.onCompleted: x = someBinding`** может повести себя не так, как
  ожидаешь при живых зависимых биндингах — надёжнее явное состояние
  (`property bool open` + `x: open ? A : B`), так и сделано в PowerMenu/AudioSink/ToolsMenu.
- Функции QML не могут начинаться с заглавной буквы.
- Тип называется `PwObjectTracker` (маленькая `w`), не `PWObjectTracker`.

## Проверка конфига без перезапуска сессии

```sh
pkill -f '^quickshell$'
quickshell            # правки в layers/*.qml подхватятся, ошибки будут в stdout
```
