import QtQuick
import Quickshell
import Quickshell.Io

// Единый источник правды о воспроизведении. Звук — отдельный процесс mpv,
// общаемся через его JSON IPC по unix-сокету. mpv живёт независимо от
// quickshell: закрытие окна (и даже рестарт quickshell) музыку не трогает,
// при старте просто переподключаемся к уже работающему mpv.
//
// Весь текущий плейлист загружен в mpv целиком, поэтому переход на следующий
// трек mpv делает сам, а currentIndex — это просто его playlist-pos.
Scope {
    id: player

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/mpv-music.sock"

    // [{ id, name }] — первым всегда "вся библиотека" (id "")
    property var sources: [{ id: "", name: "Вся библиотека" }]
    property string sourceId: ""
    readonly property string sourceName: {
        const s = player.sources.find(s => s.id === player.sourceId)
        return s ? s.name : ""
    }

    // [{ id, title, artist, album, duration, coverUrl, streamUrl }]
    property var tracks: []
    property int currentIndex: 0
    readonly property var currentTrack: player.tracks[player.currentIndex] ?? null

    property real position: 0
    property real duration: 0
    property bool paused: true
    readonly property bool playing: player.mpvConnected && !player.paused && player.mpvCount > 0
    property bool mpvConnected: false
    // сколько треков сейчас в плейлисте mpv; 0 — mpv простаивает
    property int mpvCount: 0

    property bool loading: false
    property string errorText: ""

    SubsonicApi {
        id: api
        onReadyChanged: player.init()
    }

    // ---------- состояние между запусками (какой плейлист выбран) ----------

    property bool stateLoaded: false
    property bool hasSavedState: false
    FileView {
        id: stateFile
        path: Qt.resolvedUrl(Quickshell.shellDir + "/music-state.json")
        onLoaded: {
            try {
                player.sourceId = JSON.parse(stateFile.text()).sourceId ?? ""
                player.hasSavedState = true
            } catch (e) {}
            player.stateLoaded = true
            player.init()
        }
        onLoadFailed: {
            player.stateLoaded = true
            player.init()
        }
    }

    property bool initialized: false
    function init() {
        if (player.initialized || !api.ready || !player.stateLoaded) return
        player.initialized = true
        api.fetchPlaylists(function(list, err) {
            if (err) player.errorText = err
            player.sources = [{ id: "", name: "Вся библиотека" }].concat(list)
            // первый запуск — по умолчанию первый плейлист, если он есть
            if (!player.hasSavedState && list.length > 0) player.sourceId = list[0].id
            player.fetchTracks(player.sourceId, false)
        })
        // mpv мог остаться играть с прошлого запуска
        player.connectMpv()
    }

    function fetchTracks(id, andPlay) {
        player.loading = true
        api.fetchTracks(id, function(list, err) {
            player.loading = false
            player.errorText = err
            player.sourceId = id
            player.tracks = list
            if (player.currentIndex >= list.length) player.currentIndex = 0
            if (andPlay && list.length > 0) player.loadIntoMpv(0)
        })
    }

    // Выбор плейлиста в шапке — сразу загружаем и играем с первого трека
    function playSource(id) {
        stateFile.setText(JSON.stringify({ sourceId: id }))
        player.currentIndex = 0
        player.fetchTracks(id, true)
    }

    // ---------- управление ----------

    function loadIntoMpv(startIndex) {
        player.send(["stop"])  // stop заодно очищает плейлист mpv
        for (const t of player.tracks) player.send(["loadfile", t.streamUrl, "append"])
        player.send(["playlist-play-index", startIndex])
        player.send(["set_property", "pause", false])
        player.currentIndex = startIndex
    }

    function playIndex(i) {
        if (i < 0 || i >= player.tracks.length) return
        if (player.mpvCount !== player.tracks.length) {
            player.loadIntoMpv(i)
            return
        }
        player.send(["playlist-play-index", i])
        player.send(["set_property", "pause", false])
        player.currentIndex = i
    }

    function togglePause() {
        if (player.mpvCount === 0) player.playIndex(player.currentIndex)
        else player.send(["cycle", "pause"])
    }

    function next() {
        if (player.tracks.length === 0) return
        player.playIndex((player.currentIndex + 1) % player.tracks.length)
    }

    function previous() {
        if (player.tracks.length === 0) return
        // как в обычных плеерах: если трек уже играет больше 3с — сначала в начало
        if (player.mpvCount > 0 && player.position > 3) player.seek(0)
        else player.playIndex((player.currentIndex - 1 + player.tracks.length) % player.tracks.length)
    }

    function seek(seconds) {
        player.position = seconds
        player.send(["seek", seconds, "absolute"])
    }

    // ---------- mpv IPC ----------

    property var pending: []

    function send(command) {
        if (player.mpvConnected) {
            player.socket.write(JSON.stringify({ command: command }) + "\n")
            player.socket.flush()
        } else {
            player.pending.push(command)
            player.ensureMpv()
        }
    }

    // mpv поднимаем лениво — при первой команде, если к сокету не подключиться
    property int connectAttempts: 0
    function ensureMpv() {
        if (reconnectTimer.running) return
        // через pgrep: если mpv на этом сокете уже жив, второй не поднимаем —
        // новый mpv перехватил бы сокет, а старый продолжил бы играть сиротой.
        // Шаблон с ^: иначе pgrep найдёт саму эту sh-обёртку по её аргументам
        Quickshell.execDetached(["sh", "-c",
            'pgrep -f "^[^ ]*mpv .*=$1\\$" >/dev/null || exec mpv --idle=yes --no-video --no-terminal --input-ipc-server="$1"',
            "sh", player.socketPath])
        player.connectAttempts = 0
        reconnectTimer.start()
    }

    Timer {
        id: reconnectTimer
        interval: 150
        repeat: true
        onTriggered: {
            if (player.mpvConnected) { stop(); return }
            if (++player.connectAttempts > 60) {
                player.errorText = "mpv не запускается — установлен?"
                player.pending = []
                stop()
                return
            }
            player.connectMpv()
        }
    }

    // Quickshell Socket после неудачного подключения залипает навсегда
    // (внутренний QLocalSocket не сбрасывается, повторный connected = true
    // ничего не делает), а destroy() на нём запрещён — поэтому каждая попытка
    // это пересоздание объекта через LazyLoader.
    // выставляется из самого Socket при подключении — LazyLoader.item
    // в этот момент ещё может быть не проставлен
    property Socket socket: null

    function connectMpv() {
        socketLoader.active = false
        socketLoader.active = true
    }

    LazyLoader {
        id: socketLoader
        active: false

        Socket {
            id: sock
            path: player.socketPath
            connected: true

            onConnectedChanged: {
                if (!sock.connected) {
                    if (player.socket === sock) player.socket = null
                    player.mpvConnected = false
                    player.paused = true
                    player.mpvCount = 0
                    return
                }
                player.socket = sock
                player.mpvConnected = true
                player.errorText = ""
                const props = ["time-pos", "duration", "pause", "playlist-pos", "playlist-count"]
                for (let i = 0; i < props.length; i++) player.send(["observe_property", i + 1, props[i]])
                const queued = player.pending
                player.pending = []
                for (const c of queued) player.send(c)
            }

            parser: SplitParser {
                onRead: data => player.handleMpvMessage(data)
            }
        }
    }

    function handleMpvMessage(data) {
        let msg
        try { msg = JSON.parse(data) } catch (e) { return }
        if (msg.event !== "property-change") return
        const v = msg.data
        switch (msg.name) {
        case "time-pos": player.position = v ?? 0; break
        case "duration": player.duration = v ?? 0; break
        case "pause": player.paused = v ?? true; break
        case "playlist-count": player.mpvCount = v ?? 0; break
        // -1 когда плейлист доигран — оставляем последний диск по центру
        case "playlist-pos": if (v >= 0) player.currentIndex = v; break
        }
    }
}
