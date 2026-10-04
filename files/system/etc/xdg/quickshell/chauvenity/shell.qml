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
// QML every time a file is saved, so the bar changes without restarting the
// session:
//
//     mkdir -p ~/.config/quickshell
//     cp -r /etc/xdg/quickshell/chauvenity ~/.config/quickshell/
//     systemctl --user restart chauvenity-quickshell
//
// The mkdir is not optional: without it `cp -r` creates ~/.config/quickshell
// *as* the copy and the files land one directory too high, where nothing reads
// them. The directory and not just this file, because Quickshell resolves
// `-c chauvenity` to the first `chauvenity/` it finds across the XDG config
// dirs — a lone shell.qml there shadows the whole shipped directory and then
// fails to resolve ClaudeUsage and the rest. And the restart once, because the
// bar that is already running is still watching /etc.
//
// Deliberately a bar and nothing else: notifications come from mako and the
// polkit prompt from mate-polkit, both their own systemd user units, so there
// is no second implementation of either here.
//
// The bar's larger pieces are their own files in this directory, so each can be
// read and edited on its own:
//
//   ClaudeUsage.qml Claude subscription usage, with ClaudeUsageService.qml,
//                   Gauge.qml and usage.mjs
//   usage.mjs       the pure logic, tested by test-usage.mjs (`gjs -m`)

import QtQuick
import Quickshell
import Quickshell.Io
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

    // One poll for the whole session, however many monitors the bar is on.
    ClaudeUsageService {
        id: claudeUsage
    }

    // --- niri state ---------------------------------------------------------
    // Fed by a single `niri msg --json event-stream`, which emits one JSON
    // object per line. Everything below tolerates unknown or missing fields:
    // a niri release that adds an event must not take the bar down.
    property var workspaces: []

    readonly property string focusedTitle:
        (root.focusedWindowId !== null && root.focusedWindowId in root.windowTitles)
            ? root.windowTitles[root.focusedWindowId]
            : ""

    property var windowTitles: ({})
    property var focusedWindowId: null

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
        } else if (ev.WindowsChanged) {
            const titles = {};
            let focused = null;
            for (const w of (ev.WindowsChanged.windows || [])) {
                titles[w.id] = w.title || "";
                if (w.is_focused)
                    focused = w.id;
            }
            root.windowTitles = titles;
            root.focusedWindowId = focused;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            if (!w)
                return;
            const titles = Object.assign({}, root.windowTitles);
            titles[w.id] = w.title || "";
            root.windowTitles = titles;
            if (w.is_focused)
                root.focusedWindowId = w.id;
        } else if (ev.WindowClosed) {
            const titles = Object.assign({}, root.windowTitles);
            delete titles[ev.WindowClosed.id];
            root.windowTitles = titles;
            if (root.focusedWindowId === ev.WindowClosed.id)
                root.focusedWindowId = null;
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            root.focusedWindowId = (id === undefined) ? null : id;
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
                id: workspaceRow
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
                            onClicked: focusWorkspace.running = true

                            // `focus-workspace` takes an index or a name, not
                            // an id, and an index is resolved against the
                            // *focused* output — so the monitor has to be
                            // focused first for a click on another bar to land
                            // on the workspace that was actually clicked.
                            Process {
                                id: focusWorkspace
                                command: ["sh", "-c",
                                          "niri msg action focus-monitor \"$1\" && niri msg action focus-workspace \"$2\"",
                                          "sh",
                                          String(wsItem.modelData.output),
                                          String(wsItem.modelData.idx)]
                            }
                        }
                    }
                }
            }

            // Centre: title of the focused window.
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, bar.width * 0.4)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: root.focusedTitle
                color: root.dimColor
                font.pixelSize: 12
            }

            // Right: Claude usage, volume, battery, clock.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                ClaudeUsage {
                    anchors.verticalCenter: parent.verticalCenter
                    service: claudeUsage
                }

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
