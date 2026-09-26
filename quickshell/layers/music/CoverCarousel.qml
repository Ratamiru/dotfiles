pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D

// Карусель CD-дисков по дуге. Геометрия одна на всех (assets/cd/meshes/disc.mesh,
// из cd_disk.glb через balsam), у каждого инстанса свой материал наклейки
// с обложкой трека. Порядок materials = порядок сабмешей: 0 — корпус, 1 — наклейка.
Item {
    id: carousel
    required property PlayerState player

    // сколько дисков видно с каждой стороны от активного
    property int sideCount: 2
    readonly property real arcRadius: 7
    readonly property real arcStep: 38  // градусов между соседними дисками

    // плавно догоняет currentIndex — по нему и считается раскладка
    property real shownIndex: player.currentIndex
    Behavior on shownIndex {
        NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
    }

    // корпус диска общий для всех инстансов — не трогаем
    Texture {
        id: discBaseColor
        source: Qt.resolvedUrl("../../assets/cd/maps/disc_basecolor.png")
        generateMipmaps: true
        mipFilter: Texture.Linear
    }
    Texture {
        id: discMetalRough
        source: Qt.resolvedUrl("../../assets/cd/maps/disc_metalrough.png")
        generateMipmaps: true
        mipFilter: Texture.Linear
    }
    PrincipledMaterial {
        id: discMaterial
        baseColorMap: discBaseColor
        metalnessMap: discMetalRough
        roughnessMap: discMetalRough
        metalness: 0.6
        roughness: 0.22
        cullMode: PrincipledMaterial.NoCulling
        alphaMode: PrincipledMaterial.Blend
    }

    View3D {
        id: view
        anchors.fill: parent

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        PerspectiveCamera {
            position: Qt.vector3d(0, 0.8, 10)
            eulerRotation.x: -4
            fieldOfView: 30
            // по умолчанию clipNear = 10 — ровно дистанция до диска, срезало бы его
            clipNear: 0.1
            clipFar: 100
        }

        DirectionalLight {
            eulerRotation.x: -25
            eulerRotation.y: -20
            brightness: 1.2
            ambientColor: Qt.rgba(0.35, 0.35, 0.4, 1)
        }
        PointLight {
            position: Qt.vector3d(3, 4, 6)
            brightness: 2
            color: "#c8ccff"
        }

        Repeater3D {
            model: carousel.player.tracks

            delegate: Node {
                id: slot
                required property var modelData
                required property int index

                // смещение от активного диска: 0 — по центру, ±1 — соседи...
                readonly property real offset: index - carousel.shownIndex
                readonly property real absOffset: Math.abs(offset)
                readonly property bool isActive: index === carousel.player.currentIndex
                readonly property real angle: offset * carousel.arcStep * Math.PI / 180

                visible: absOffset < carousel.sideCount + 0.6
                position: Qt.vector3d(
                    Math.sin(angle) * carousel.arcRadius,
                    0,
                    (Math.cos(angle) - 1) * carousel.arcRadius)
                // соседи развёрнуты к центру дуги
                eulerRotation.y: -offset * carousel.arcStep * 0.9
                scale: {
                    const s = 1 - Math.min(absOffset, 1) * 0.25
                    return Qt.vector3d(s, s, s)
                }
                opacity: Math.max(0, 1 - absOffset * 0.38)

                // вращение активного диска, пока играет музыка
                property real spin: 0
                FrameAnimation {
                    running: slot.isActive && carousel.player.playing
                    onTriggered: slot.spin = (slot.spin + frameTime * 60) % 360
                }

                // наклейка в меше смотрит в -Z — разворачиваем к камере
                Node {
                    eulerRotation.y: 180
                    Model {
                        property int trackIndex: slot.index
                        source: Qt.resolvedUrl("../../assets/cd/meshes/disc.mesh")
                        eulerRotation.z: -slot.spin
                        pickable: true
                        materials: [discMaterial, labelMaterial]

                        // наклейка — своя на каждый диск, с обложкой трека
                        PrincipledMaterial {
                            id: labelMaterial
                            metalness: 0
                            roughness: 0.5
                            cullMode: PrincipledMaterial.NoCulling
                            baseColorMap: Texture {
                                sourceItem: Rectangle {
                                    width: 512
                                    height: 512
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: "#3a3a5e" }
                                        GradientStop { position: 1; color: "#1e1e2e" }
                                    }
                                    Image {
                                        anchors.fill: parent
                                        source: slot.modelData.coverUrl
                                        sourceSize: Qt.size(512, 512)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // клик по соседнему диску — играть его; колесо — листать
    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            const hit = view.pick(mouse.x, mouse.y).objectHit
            if (hit && hit.trackIndex !== undefined) {
                if (hit.trackIndex === carousel.player.currentIndex) carousel.player.togglePause()
                else carousel.player.playIndex(hit.trackIndex)
            }
        }
        onWheel: wheel => {
            if (wheelThrottle.running) return
            wheelThrottle.start()
            // не previous(): тот сначала перематывает текущий трек в начало
            const n = carousel.player.tracks.length
            const step = (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) ? 1 : -1
            if (n > 0) carousel.player.playIndex((carousel.player.currentIndex + step + n) % n)
        }
        Timer { id: wheelThrottle; interval: 250 }
    }
}
