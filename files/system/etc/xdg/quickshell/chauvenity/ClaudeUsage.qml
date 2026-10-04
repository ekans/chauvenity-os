pragma ComponentBehavior: Bound

// Claude subscription usage in the bar: the 5-hour session window, the weekly
// cap and the Fable weekly carve-out. A port of the claude-usage@ducatore
// GNOME Shell extension.
//
// A view and nothing else — every piece of state, and the single poll shared
// by all monitors, lives in the one ClaudeUsageService that shell.qml creates
// and passes in. The arithmetic and
// formatting live in usage.mjs, shared verbatim with the extension and covered
// by test-usage.mjs.
//
// A MouseArea rather than a Row with a fill-anchored MouseArea inside it: Row
// refuses `fill` anchors on its children and silently stops laying out if one
// appears.

import QtQuick

MouseArea {
    id: root

    required property ClaudeUsageService service

    // Stays out of the bar until a usable reading exists. A machine that has
    // never run `claude` has nothing to say, and an error that can only clear
    // by the user doing something they may never do is worse than no chip.
    visible: root.service.hasCredentials
    implicitWidth: gauges.implicitWidth
    implicitHeight: gauges.implicitHeight

    // A click is somebody asking for a fresh reading.
    onClicked: root.service.refreshOnRequest()

    Row {
        id: gauges
        spacing: 0

        Gauge {
            caption: "5h"
            spec: root.service.windows.fiveHour
            window: root.service.usage ? root.service.usage.fiveHour : null
            failed: root.service.failed
            nowMs: root.service.nowMs
        }

        Gauge {
            caption: "7d"
            spec: root.service.windows.sevenDay
            window: root.service.usage ? root.service.usage.sevenDay : null
            failed: root.service.failed
            nowMs: root.service.nowMs
        }

        Gauge {
            caption: "fable"
            spec: root.service.windows.fable
            window: root.service.usage ? root.service.usage.fable : null
            failed: root.service.failed
            nowMs: root.service.nowMs
        }
    }
}
