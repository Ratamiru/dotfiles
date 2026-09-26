import QtQuick
import Quickshell
import Quickshell.Io

// Клиент Navidrome по Subsonic-протоколу. Креды — в music-settings.json
// (в .gitignore): { "url": "http://host:4533", "user": "...", "password": "..." }
// Пароль по сети не ходит: на каждую ссылку своя соль и token = md5(password + salt).
Scope {
    id: api
    property string baseUrl: ""
    property string user: ""
    property string password: ""
    readonly property bool ready: baseUrl !== "" && user !== ""

    FileView {
        id: settingsFile
        path: Qt.resolvedUrl(Quickshell.shellDir + "/music-settings.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(settingsFile.text())
                // пароль — первым: ready зависит от url/user, и init() в
                // PlayerState стартует сразу, как только ready станет true
                api.password = s.password ?? ""
                api.user = s.user ?? ""
                api.baseUrl = (s.url ?? "").replace(/\/+(app\/?)?$/, "")
            } catch (e) {
                console.warn("music-settings.json: " + e)
            }
        }
    }

    function authQuery() {
        const salt = Math.random().toString(36).slice(2, 10)
        return "u=" + encodeURIComponent(api.user)
            + "&t=" + Qt.md5(api.password + salt)
            + "&s=" + salt + "&v=1.16.1&c=quickshell&f=json"
    }

    function url(endpoint, params) {
        let q = api.authQuery()
        for (const k in params) q += "&" + k + "=" + encodeURIComponent(params[k])
        return api.baseUrl + "/rest/" + endpoint + ".view?" + q
    }

    // Ссылки генерим один раз на трек и храним — иначе каждая новая соль
    // даёт новый URL и Image/mpv теряют кэш.
    function streamUrl(id) { return api.url("stream", { id: id }) }
    function coverUrl(coverArtId) {
        return coverArtId ? api.url("getCoverArt", { id: coverArtId, size: 512 }) : ""
    }

    // callback(response | null, errorText)
    function request(endpoint, params, callback) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                callback(null, "HTTP " + xhr.status)
                return
            }
            try {
                const r = JSON.parse(xhr.responseText)["subsonic-response"]
                if (r.status !== "ok") callback(null, r.error?.message ?? "subsonic error")
                else callback(r, "")
            } catch (e) {
                callback(null, String(e))
            }
        }
        xhr.open("GET", api.url(endpoint, params))
        xhr.send()
    }

    function toTrack(song) {
        return {
            id: song.id,
            title: song.title ?? "",
            artist: song.displayArtist ?? song.artist ?? "",
            album: song.album ?? "",
            duration: song.duration ?? 0,
            coverUrl: api.coverUrl(song.coverArt),
            streamUrl: api.streamUrl(song.id)
        }
    }

    // callback([{ id, name, songCount }])
    function fetchPlaylists(callback) {
        api.request("getPlaylists", {}, function(r, err) {
            if (!r) { callback([], err); return }
            const list = (r.playlists?.playlist ?? []).map(p => ({ id: p.id, name: p.name, songCount: p.songCount }))
            callback(list, "")
        })
    }

    // id === "" — вся библиотека (пустой search3 в Navidrome отдаёт все треки)
    function fetchTracks(id, callback) {
        if (id === "") {
            api.request("search3", { query: "", songCount: 500, albumCount: 0, artistCount: 0 }, function(r, err) {
                callback(r ? (r.searchResult3?.song ?? []).map(api.toTrack) : [], err)
            })
        } else {
            api.request("getPlaylist", { id: id }, function(r, err) {
                callback(r ? (r.playlist?.entry ?? []).map(api.toTrack) : [], err)
            })
        }
    }
}
