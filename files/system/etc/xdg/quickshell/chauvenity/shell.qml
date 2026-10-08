pragma ComponentBehavior: Bound

// chauvenity-os default Quickshell bar for the niri session.
//
// Quickshell resolves `qs -c chauvenity` against the XDG config directories in
// order, so this file is only used when the user has not written their own:
//
//     ~/.config/quickshell/chauvenity/shell.qml   <- wins if it exists
//     /etc/xdg/quickshell/chauvenity/shell.qml    <- this file
//
// To take it over, copy the whole directory and edit; Quickshell reloads the
// QML every time a file is saved:
//
//     mkdir -p ~/.config/quickshell
//     cp -r /etc/xdg/quickshell/chauvenity ~/.config/quickshell/
//     systemctl --user restart chauvenity-quickshell
//
// Why each line matters: https://github.com/ekans/chauvenity-os#taking-it-over
//
// Deliberately a bar and nothing else. The image ships no notification
// daemon: serve org.freedesktop.Notifications from your own copy of this bar
// (Quickshell.Services.Notifications), so it changes without an image build.
// The polkit prompt comes from mate-polkit, its own systemd user unit.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

ShellRoot {
    id: root

    // Palette, kept in one place so a copy of this file is easy to retheme.
    readonly property color bgColor: "#1c1b22"
    readonly property color fgColor: "#deddda"
    readonly property color dimColor: "#77767b"
    readonly property color accentColor: "#62a0ea"
    readonly property int barHeight: 32

    // --- niri state ---------------------------------------------------------
    // Fed by a single `niri msg --json event-stream`, which emits one JSON
    // object per line. Everything below tolerates unknown or missing fields:
    // a niri release that adds an event must not take the bar down.
    property var workspaces: []

    function handleEvent(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }

        if (ev.WorkspacesChanged) {
            const list = (ev.WorkspacesChanged.workspaces || []).slice();
            list.sort((a, b) => (a.idx || 0) - (b.idx || 0));
            root.workspaces = list;
        } else if (ev.WorkspaceActivated) {
            // The event carries only {id, focused}. Activating a workspace
            // deactivates every other workspace *on the same output*, and niri
            // does not say so — without this the pills of previously visited
            // workspaces stay lit for the rest of the session.
            const activated = ev.WorkspaceActivated;
            const target = root.workspaces.find(ws => ws.id === activated.id);
            const output = target ? target.output : null;
            root.workspaces = root.workspaces.map(ws => {
                const isTarget = ws.id === activated.id;
                const next = Object.assign({}, ws);
                if (isTarget)
                    next.is_active = true;
                else if (output !== null && ws.output === output)
                    next.is_active = false;
                if (activated.focused)
                    next.is_focused = isTarget;
                return next;
            });
        }
    }

    Process {
        id: niriEvents
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => root.handleEvent(line)
        }
        // Without this, a stream that dies for any reason leaves the
        // workspaces and the title frozen for the rest of the session, with
        // nothing on screen to say so. Keyed on `running` rather than the
        // `exited` signal, whose parameter types qmllint cannot resolve.
        onRunningChanged: {
            if (!niriEvents.running)
                restartEvents.restart();
        }
    }

    Timer {
        id: restartEvents
        interval: 1000
        onTriggered: niriEvents.running = true
    }

    // --- services -----------------------------------------------------------

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Pipewire only publishes volume for nodes something is tracking.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // --- the bar ------------------------------------------------------------

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData

            // Only this output's workspaces. Without the filter every bar
            // lists every monitor's workspaces.
            readonly property var outputWorkspaces:
                root.workspaces.filter(ws => ws.output === bar.modelData.name)

            screen: bar.modelData
            color: root.bgColor
            implicitHeight: root.barHeight

            anchors {
                top: true
                left: true
                right: true
            }

            // Left: workspace indices.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: bar.outputWorkspaces

                    Rectangle {
                        id: wsItem
                        required property var modelData

                        readonly property bool isFocused: !!wsItem.modelData.is_focused
                        readonly property bool isActive: !!wsItem.modelData.is_active

                        width: Math.max(24, label.implicitWidth + 12)
                        height: 22
                        radius: 4
                        color: wsItem.isFocused ? root.accentColor : "transparent"

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: wsItem.modelData.name || String(wsItem.modelData.idx)
                            color: wsItem.isFocused
                                ? root.bgColor
                                : (wsItem.isActive ? root.fgColor : root.dimColor)
                            font.pixelSize: 12
                            font.bold: wsItem.isFocused
                        }

                        MouseArea {
                            anchors.fill: parent
                            // `focus-workspace` takes an index or a name, not
                            // an id, and an index is resolved against the
                            // *focused* output — so the monitor has to be
                            // focused first for a click on another bar to land
                            // on the workspace that was actually clicked.
                            onClicked: Quickshell.execDetached(
                                ["sh", "-c",
                                 "niri msg action focus-monitor \"$1\" && niri msg action focus-workspace \"$2\"",
                                 "sh",
                                 String(wsItem.modelData.output),
                                 String(wsItem.modelData.idx)])
                        }
                    }
                }
            }

            // Centre: title of the focused window. activeToplevel is only
            // cleared when its window closes, not when focus moves to an empty
            // workspace, hence the `activated` check.
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, bar.width * 0.4)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                // Any client sets its own title. AutoText would render markup
                // in it, <img src="https://…"> included, and fetch that URL.
                textFormat: Text.PlainText
                text: ToplevelManager.activeToplevel?.activated
                    ? ToplevelManager.activeToplevel.title
                    : ""
                color: root.dimColor
                font.pixelSize: 12
            }

            // Right: volume, battery, clock.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    id: volumeText
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property var sink: Pipewire.defaultAudioSink
                    visible: !!(volumeText.sink && volumeText.sink.audio)
                    text: !volumeText.visible
                        ? ""
                        : (volumeText.sink.audio.muted
                            ? "vol muted"
                            : "vol " + Math.round(volumeText.sink.audio.volume * 100) + "%")
                    color: root.fgColor
                    font.pixelSize: 12
                }

                Text {
                    id: batteryText
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property var battery: UPower.displayDevice
                    visible: !!(batteryText.battery && batteryText.battery.isLaptopBattery)
                    text: !batteryText.visible
                        ? ""
                        : Math.round(batteryText.battery.percentage * 100) + "%"
                          + (batteryText.battery.state === UPowerDeviceState.Charging ? " +" : "")
                    color: root.fgColor
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
                    color: root.fgColor
                    font.pixelSize: 12
                }
            }
        }
    }
}
