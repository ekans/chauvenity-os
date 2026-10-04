#!/usr/bin/env bash
# Bring the base image's Qt 6 up to the release Fedora built quickshell
# against, so the bar can actually start.
#
# Fedora builds quickshell against whatever Qt is current, but the RPM only
# requires `libQt6Core.so.6(Qt_6.11)` — a soname-level dependency that any
# 6.11.x satisfies. When bluefin-dx lags Fedora by a patch release, dnf is
# therefore perfectly happy to install quickshell next to the older Qt, and
# `qs` then dies at load time:
#
#   qs: symbol lookup error: qs: undefined symbol:
#   _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6
#
# That shipped in the first build of this session: Qt 6.11.1 in the base,
# quickshell built against 6.11.2, no bar at all.
#
# This cannot be expressed through the dnf module. `install:` maps to
# `dnf install`, and dnf5's install is "install if absent" — given an
# already-present qt6-qtbase it prints "Nothing to do" and leaves the old one
# in place. Only `dnf upgrade` moves it. Hence a script.
#
# The glob is deliberate: it upgrades exactly the qt6 packages the base
# happens to ship, with no hardcoded list to drift. It is a no-op whenever the
# base is already current, which is what it will be most of the time — the
# upgrade only has anything to do in the window between a Fedora Qt update and
# bluefin-dx picking it up.

set -euo pipefail

echo "Qt before:"
rpm -qa 'qt6-*' --qf '  %{NAME} %{VERSION}-%{RELEASE}\n' | sort

dnf -y upgrade 'qt6-*'

echo "Qt after:"
rpm -qa 'qt6-*' --qf '  %{NAME} %{VERSION}-%{RELEASE}\n' | sort

# Fail the build rather than ship a bar that cannot start.
qs --version
