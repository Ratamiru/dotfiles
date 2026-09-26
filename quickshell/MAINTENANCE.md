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
projects.json            # список проектов (редактируется руками)
notes-settings.json       # хранит путь к папке с заметками (не трогать руками)
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
