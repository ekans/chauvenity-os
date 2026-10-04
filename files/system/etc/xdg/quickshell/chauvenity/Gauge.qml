pragma ComponentBehavior: Bound

// One window of Claude usage: its caption, the percentage spent, how far that
// is from the budget line, and how long until it resets.
//
// The styling is the GNOME extension's, translated from inline CSS to QML
// properties: same sizes, same spacings, same brand palette, same rule that
// only overspending gets the accent colour.

import QtQuick
import "usage.mjs" as Usage

Row {
    id: gauge

    required property string caption
    required property var spec
    required property var window
    required property bool failed
    required property double nowMs

    readonly property var delta: gauge.failed ? null : Usage.paceDelta(gauge.window, gauge.spec, gauge.nowMs)
    readonly property var style: gauge.window
        ? Usage.usageStyle(gauge.window.percent)
        : ({color: Usage.PALETTE.midGray, background: null})

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    spacing: 0

    Text {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 8
        text: gauge.caption
        font.pixelSize: 10
        color: Usage.PALETTE.midGray
    }

    // The alarm state inverts onto the accent rather than reaching for a colour
    // Anthropic does not use, so the pill is only drawn at that point.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: value.implicitWidth + (visibleBackground ? 10 : 0)
        height: value.implicitHeight + (visibleBackground ? 2 : 0)
        radius: 9
        color: visibleBackground ? gauge.style.background : "transparent"

        readonly property bool visibleBackground: !gauge.failed && !!gauge.style.background

        Text {
            id: value
            anchors.centerIn: parent
            text: gauge.failed ? "?" : Usage.formatPercent(gauge.window)
            font.pixelSize: 12
            font.bold: true
            color: gauge.failed ? Usage.PALETTE.orange : gauge.style.color
            leftPadding: 3
        }
    }

    // Sits with the percentage rather than with the countdown: it says
    // something about what was spent, not about what is left.
    Text {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 3
        text: Usage.formatPaceDelta(gauge.delta)
        font.pixelSize: 10
        color: Usage.paceColor(gauge.delta)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 4
        text: (gauge.failed || !gauge.window)
            ? ""
            : "· " + Usage.formatCountdown(gauge.window.resetsAt, gauge.nowMs)
        font.pixelSize: 10
        color: Usage.PALETTE.midGray
    }
}
