// Reads Claude subscription usage once per session, however many monitors the
// bar is drawn on. shell.qml instantiates exactly one of these outside the
// per-screen Variants, and hands it to each ClaudeUsage view; the views hold
// no state. Done per screen instead, this would poll an endpoint the comment
// below calls aggressively rate limited once per monitor.
//
// Not a `pragma Singleton`: that needs a qmldir for the type to resolve, and
// a qmldir turns this directory into an explicit module where every component
// must be listed by hand — so adding a .qml and forgetting the entry breaks
// the bar at runtime. Bad trade for a directory meant to be edited live.
//
// Token handling, and its one known limit:
//
//   - the token is read from ~/.claude/.credentials.json on every refresh,
//     because Claude Code rotates it in place;
//   - it is sent as an Authorization header through QML's own XMLHttpRequest.
//     There is no curl and no Process, so it never reaches a command line, and
//     nothing here logs it;
//   - BUT Qt follows HTTP redirects and replays the Authorization header when
//     it does, including to a different origin, and QML 0.2.1 exposes no way
//     to turn that off. The responseURL check below refuses to *use* a
//     response that came from anywhere else — but by then the token has
//     already been sent there. Closing that would mean shelling out to curl
//     (which does not follow redirects) and passing the header on stdin.

import QtQuick
import Quickshell
import Quickshell.Io
import "usage.mjs" as Usage

Item {
    id: service

    property bool hasCredentials: false
    property var usage: null
    property bool failed: false

    // 0 means "never fetched", which is also what makes the click floor
    // allow the first click: now - 0 is always past it.
    property double lastRefreshStartedAt: 0

    // Recomputed on every tick so the countdowns move without a request.
    property double nowMs: Date.now()

    // Re-exported so the view needs no import of its own.
    readonly property var windows: Usage.WINDOWS

    readonly property int pollIntervalSeconds: 300
    readonly property int tickIntervalSeconds: 60

    readonly property string usageUrl: "https://api.anthropic.com/api/oauth/usage"
    readonly property string oauthBeta: "oauth-2025-04-20"
    // The endpoint puts requests from unknown clients in an aggressively rate
    // limited bucket, so identify as Claude Code. Only the prefix matters.
    readonly property string userAgent: "claude-code/2.1.235"

    // Empty when HOME is unset, which leaves FileView with nothing to load and
    // the widget hidden, rather than reading "undefined/.claude/...".
    readonly property string credentialsPath: {
        const home = Quickshell.env("HOME");
        return home ? home + "/.claude/.credentials.json" : "";
    }

    function refresh() {
        service.lastRefreshStartedAt = Date.now();
        credentials.reload();
    }

    /**
     * A click is somebody asking, so it fetches — but only past the floor,
     * which is what keeps a double-click from becoming a burst.
     */
    function refreshOnRequest() {
        if (Usage.mayRefreshOnClick(service.lastRefreshStartedAt, Date.now()))
            service.refresh();
    }

    function fail(reason) {
        // Deliberately logs the reason and never the token or the file body.
        console.warn("[claude-usage] " + reason);
        service.failed = true;
    }

    function fetchUsage(token) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.responseURL && xhr.responseURL !== service.usageUrl) {
                service.fail("usage request was redirected to " + xhr.responseURL
                             + "; not using the response");
                return;
            }
            if (xhr.status === 401) {
                service.fail("Claude login expired — run `claude` to sign in again");
                return;
            }
            if (xhr.status !== 200) {
                service.fail(xhr.status === 0
                    ? "could not reach api.anthropic.com"
                    : "api.anthropic.com returned HTTP " + xhr.status);
                return;
            }
            try {
                service.usage = Usage.parseUsage(JSON.parse(xhr.responseText));
                service.failed = false;
                service.nowMs = Date.now();
            } catch (error) {
                service.fail(error.message);
            }
        };
        xhr.open("GET", service.usageUrl);
        xhr.setRequestHeader("Authorization", "Bearer " + token);
        xhr.setRequestHeader("anthropic-beta", service.oauthBeta);
        xhr.setRequestHeader("User-Agent", service.userAgent);
        xhr.send();
    }

    FileView {
        id: credentials

        path: service.credentialsPath
        // Never let Quickshell echo the file: it holds the token.
        printErrors: false

        onLoaded: {
            let token = null;
            try {
                token = Usage.extractToken(JSON.parse(credentials.text()));
            } catch (error) {
                // No token in the file is the same situation as no file: this
                // machine is not signed in, so show nothing.
                service.hasCredentials = false;
                return;
            }
            service.hasCredentials = true;
            service.fetchUsage(token);
        }

        onLoadFailed: {
            service.hasCredentials = false;
        }
    }

    Component.onCompleted: service.refresh()

    Timer {
        interval: service.pollIntervalSeconds * 1000
        running: true
        repeat: true
        onTriggered: service.refresh()
    }

    // The countdowns come from reset timestamps already in hand, so they tick
    // down without spending a request.
    Timer {
        interval: service.tickIntervalSeconds * 1000
        running: true
        repeat: true
        onTriggered: service.nowMs = Date.now()
    }
}
