// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A N I M E   P A N E L                                                  │
// │   a shelf of posters, and the big one at the top                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Controls
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// Rows of posters, the way a streaming service shows them: one big one
// with its story at the top, shelves under it, a search field above.
// The catalogue is AniList; the watching is ani-cli's.
Item {
    id: root

    signal closed()

    Component.onCompleted: AnimeService.load()

    Keys.onEscapePressed: root.closed()

    // ── THE TOP ─────────────────────────────────────────────────────────────

    Item {
        id: top

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 40

        TextField {
            id: field

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(420, parent.width * 0.5)
            placeholderText: "search anime…"
            text: AnimeService.query
            color: Theme.text
            placeholderTextColor: Theme.textMuted
            font.family: Theme.fontBar
            font.pixelSize: Theme.fontSizeSmall
            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.surfaceIn(QsWindow.window)
                border.color: Theme.borderIn(QsWindow.window)
                border.width: 1
            }
            onAccepted: AnimeService.search(text)
        }

        PillButton {
            anchors.left: field.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            icon: "󰍉"
            onClicked: AnimeService.search(field.text)
        }

        PillButton {
            anchors.left: field.parent.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "clear"
            icon: "󰅖"
            onClicked: {
                field.text = ""
                AnimeService.load()
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: AnimeService.busy ? "…" : (AnimeService.films ? "anilist · tmdb" : "anilist")
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }

    // ── THE HERO ─────────────────────────────────────────────────────────────

    Item {
        id: hero

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: top.bottom
        anchors.topMargin: 12
        height: Math.max(200, parent.height * 0.42)

        readonly property var show: AnimeService.hero

        // The picture behind it, dimmed so the words read.
        Image {
            anchors.fill: parent
            source: hero.show && hero.show.banner ? hero.show.banner : ""
            fillMode: Image.PreserveAspectCrop
            opacity: 0.5
            smooth: true
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.scrim }
                GradientStop { position: 0.65; color: "transparent" }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: Math.min(520, hero.width * 0.55)
            spacing: 8

            Text {
                width: parent.width
                elide: Text.ElideRight
                font.family: Theme.fontBar
                font.pixelSize: 30
                font.bold: true
                color: Theme.text
                text: hero.show ? hero.show.title : ""
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.accent
                text: hero.show ? [hero.show.year, hero.show.score ? "★ " + hero.show.score : "",
                                  hero.show.genres.slice(0, 3).join(" · ")].filter(Boolean).join("   ") : ""
            }

            Text {
                width: parent.width
                maximumLineCount: 3
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                font.family: Theme.fontBar
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
                text: hero.show ? hero.show.description : ""
            }

            Row {
                spacing: 10

                PillButton {
                    text: "watch"
                    icon: "󰐊"
                    active: true
                    onClicked: AnimeService.watch(hero.show)
                }

                PillButton {
                    text: "trailer"
                    icon: "󰜕"
                    onClicked: {}
                }
            }
        }
    }

    // ── THE SHELVES ─────────────────────────────────────────────────────────

    ListView {
        id: shelves

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hero.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        clip: true
        spacing: 14
        model: AnimeService.rows
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: shelf

            required property var modelData
            required property int index

            width: shelves.width
            height: 200

            Text {
                id: label

                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.top: parent.top
                font.family: Theme.fontBar
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
                text: shelf.modelData.title
            }

            ListView {
                id: posters

                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.top: label.bottom
                anchors.topMargin: 6
                height: parent.height - 26
                orientation: ListView.Horizontal
                spacing: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: shelf.modelData.items

                delegate: Item {
                    id: card

                    required property var modelData
                    required property int index

                    width: 118
                    height: 168

                    Rectangle {
                        id: frame

                        anchors.fill: parent
                        radius: 6
                        color: Theme.surfaceIn(QsWindow.window)
                        border.color: card.hovered ? Theme.accent : "transparent"
                        border.width: card.hovered ? 2 : 0
                        scale: card.hovered ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: card.modelData.cover
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            clip: true
                        }
                    }

                    property bool hovered: hover.hovered

                    HoverHandler { id: hover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AnimeService.hero = card.modelData
                    }
                }
            }
        }
    }
}
