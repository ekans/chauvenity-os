#!/usr/bin/env -S gjs -m
// Unit tests for the pure helpers. Run with: gjs -m test-usage.mjs
//
// Ported from the claude-usage@ducatore GNOME Shell extension with only the
// import path changed. gjs is in the image (GNOME ships it), so these run on
// the machine as well as in CI.

import {PALETTE, WINDOWS, extractToken, formatCountdown, formatPaceDelta, mayRefreshOnClick, paceColor, paceDelta, parseUsage} from './usage.mjs';

let failures = 0;

/** Asserts the call throws, and that the message says why. */
function checkThrows(name, fn, expectedFragment) {
    try {
        fn();
        print(`FAIL ${name}\n       want a thrown error containing ${JSON.stringify(expectedFragment)}\n       got  no error`);
        failures += 1;
    } catch (error) {
        if (error.message.includes(expectedFragment)) {
            print(`ok   ${name}`);
        } else {
            print(`FAIL ${name}\n       want an error containing ${JSON.stringify(expectedFragment)}\n       got  ${JSON.stringify(error.message)}`);
            failures += 1;
        }
    }
}

function check(name, actual, expected) {
    const got = JSON.stringify(actual);
    const want = JSON.stringify(expected);
    if (got === want) {
        print(`ok   ${name}`);
    } else {
        print(`FAIL ${name}\n       want ${want}\n       got  ${got}`);
        failures += 1;
    }
}

// Only the `limits` array carries Fable: the legacy `seven_day_*` per-model
// keys are null for every account now.
const fableLimit = {
    kind: 'weekly_scoped',
    group: 'weekly',
    percent: 22,
    resets_at: '2026-09-14T05:59:59+00:00',
    scope: {model: {id: null, display_name: 'Fable'}},
};

check('reads the Fable weekly carve-out from limits',
    parseUsage({limits: [
        {kind: 'session', percent: 48, resets_at: 'x', scope: null},
        {kind: 'weekly_all', percent: 71, resets_at: 'y', scope: null},
        fableLimit,
    ]}).fable,
    {percent: 22, resetsAt: '2026-09-14T05:59:59+00:00'});

check('ignores a weekly_scoped window scoped to another model',
    parseUsage({limits: [{...fableLimit, scope: {model: {display_name: 'Opus'}}}]}).fable,
    null);

check('ignores a surface-scoped window with no model',
    parseUsage({limits: [{...fableLimit, scope: {surface: 'cowork'}}]}).fable,
    null);

check('tolerates a payload with no limits array',
    parseUsage({five_hour: {utilization: 1, resets_at: 'z'}}).fable,
    null);

check('still reads the two plan-wide windows',
    parseUsage({five_hour: {utilization: 47.6, resets_at: 'a'}, seven_day: null}),
    {fiveHour: {percent: 48, resetsAt: 'a'}, sevenDay: null, fable: null});

// --- pace against the budget line --------------------------------------------
// A window spends its cap evenly if `percent` tracks how much of the window has
// elapsed. The delta is the gap in points, and it is the whole point of the chip.
//
// Fixtures are built from local `Date` parts rather than UTC strings: the working
// week is a local-calendar fact, so the assertions have to hold in any timezone.

const at = (day, hour = 0, minute = 0) => new Date(2026, 8, day, hour, minute);
const iso = (...parts) => at(...parts).toISOString();

// September 2026: the 7th is a Monday, the 12th a Saturday, the 14th a Monday.
const WEEK_RESET = iso(14, 8);        // the weekly window runs Mon 08:00 -> Mon 08:00
const SESSION_RESET = iso(12, 12);    // a five-hour session ending on the Saturday

check('a session window is measured against plain elapsed time',
    // 5 hours, 4h11m left -> 16.3% elapsed, 11% spent
    paceDelta({percent: 11, resetsAt: iso(11, 16, 11)}, WINDOWS.fiveHour, at(11, 12).getTime()),
    -5);

check('a session window ignores the weekend, because a session is not a week',
    // 3 of 5 hours gone on a Saturday morning
    paceDelta({percent: 11, resetsAt: SESSION_RESET}, WINDOWS.fiveHour, at(12, 10).getTime()),
    -49);

check('the weekly line only advances during working hours',
    // Mon 08:00 -> Mon 08:00 holds five 8-to-7 days: 55 hours, 48 of them gone by Friday noon
    paceDelta({percent: 88, resetsAt: WEEK_RESET}, WINDOWS.sevenDay, at(11, 12).getTime()),
    1);

check('an evening does not move the line',
    paceDelta({percent: 88, resetsAt: WEEK_RESET}, WINDOWS.sevenDay, at(9, 23).getTime()),
    28);

check('and the next morning starts where that evening left it',
    paceDelta({percent: 88, resetsAt: WEEK_RESET}, WINDOWS.sevenDay, at(10, 7).getTime()),
    28);

check('the line is fully spent once the last working day ends',
    paceDelta({percent: 88, resetsAt: WEEK_RESET}, WINDOWS.sevenDay, at(11, 19).getTime()),
    -12);

check('the weekend does not move the weekly line',
    paceDelta({percent: 88, resetsAt: WEEK_RESET}, WINDOWS.sevenDay, at(12, 15).getTime()),
    -12);

check('and has not moved it by Sunday night either',
    paceDelta({percent: 88, resetsAt: WEEK_RESET}, WINDOWS.sevenDay, at(13, 23).getTime()),
    -12);

check('the Fable carve-out follows the same working week',
    paceDelta({percent: 22, resetsAt: WEEK_RESET}, WINDOWS.fable, at(12, 15).getTime()),
    -78);

check('a window with no reset time has no measurable pace',
    paceDelta({percent: 50, resetsAt: null}, WINDOWS.sevenDay, at(11, 12).getTime()),
    null);

check('a missing window has no pace',
    paceDelta(null, WINDOWS.sevenDay, at(11, 12).getTime()),
    null);

check('a window holding no working hours at all has no pace to measure',
    // Saturday 00:00 to Monday 00:00: the Monday working day starts after it ends
    paceDelta({percent: 40, resetsAt: iso(14)}, {minutes: 2 * 24 * 60, workdays: true},
        at(13, 12).getTime()),
    null);

check('a window past its reset is fully elapsed, never more',
    paceDelta({percent: 90, resetsAt: iso(11, 10)}, WINDOWS.fiveHour, at(11, 12).getTime()),
    -10);

check('a reset further out than the window itself reads as freshly started',
    // clock skew must not make the delta explode past what was actually spent
    paceDelta({percent: 12, resetsAt: iso(11, 22)}, WINDOWS.fiveHour, at(11, 12).getTime()),
    12);

check('ahead of the line points up',
    formatPaceDelta(27),
    '▲27');

check('behind the line points down, without repeating the sign',
    formatPaceDelta(-5),
    '▼5');

check('exactly on the line is neither',
    formatPaceDelta(0),
    '=0');

check('no measurable pace shows nothing',
    formatPaceDelta(null),
    '');

check('a delta past the tolerance is painted with the accent',
    paceColor(27),
    PALETTE.orange);

check('a delta inside the tolerance stays quiet',
    paceColor(4),
    PALETTE.midGray);

check('being under the line is always quiet',
    paceColor(-30),
    PALETTE.midGray);


// --- the click floor ---------------------------------------------------------
// Clicking asks for a refresh. The floor is what stops a double-click, or a
// finger held on the indicator, from becoming a burst of requests.

const CLICKED_AT = Date.parse('2026-09-11T12:00:00Z');

check('a click refreshes when nothing has been fetched yet',
    mayRefreshOnClick(null, CLICKED_AT),
    true);

check('a second click inside the floor is refused',
    mayRefreshOnClick(CLICKED_AT - 4900, CLICKED_AT),
    false);

check('a click exactly on the floor is allowed',
    mayRefreshOnClick(CLICKED_AT - 5000, CLICKED_AT),
    true);

check('a click well after the floor is allowed',
    mayRefreshOnClick(CLICKED_AT - 60000, CLICKED_AT),
    true);


// --- the countdown ------------------------------------------------------------
// Read off reset timestamps the panel already holds, so these tick without
// spending a request. The units change as the remaining time grows.

const COUNTDOWN_NOW = Date.parse('2026-09-11T12:00:00Z');
const inMinutes = m => new Date(COUNTDOWN_NOW + m * 60000).toISOString();

check('a window with no reset time has no countdown to show',
    formatCountdown(null, COUNTDOWN_NOW),
    'unknown');

check('a window already past its reset reads as due now',
    formatCountdown(inMinutes(-1), COUNTDOWN_NOW),
    'now');

check('a reset exactly now reads as due now, not as zero minutes',
    formatCountdown(inMinutes(0), COUNTDOWN_NOW),
    'now');

check('under an hour is minutes alone',
    formatCountdown(inMinutes(45), COUNTDOWN_NOW),
    '45m');

check('over an hour is hours and minutes',
    formatCountdown(inMinutes(70), COUNTDOWN_NOW),
    '1h 10m');

check('over a day drops the minutes, because they stop mattering',
    formatCountdown(inMinutes(4 * 1440 + 19 * 60 + 30), COUNTDOWN_NOW),
    '4d 19h');


// --- reading the token ---------------------------------------------------------
// The one job of extractToken is to tell "signed in" from "not signed in"
// clearly: the panel hides itself on the second, so a wrong answer here is the
// difference between a working chip and no chip at all.

check('reads the access token Claude Code stored',
    extractToken({claudeAiOauth: {accessToken: 'sk-ant-oat-example'}}),
    'sk-ant-oat-example');

checkThrows('refuses a credentials file with no oauth section',
    () => extractToken({}),
    'No Claude subscription token');

checkThrows('refuses an oauth section with no access token',
    () => extractToken({claudeAiOauth: {refreshToken: 'r'}}),
    'No Claude subscription token');

checkThrows('refuses an empty access token rather than sending one',
    () => extractToken({claudeAiOauth: {accessToken: ''}}),
    'No Claude subscription token');

checkThrows('refuses a file that parsed to nothing',
    () => extractToken(null),
    'No Claude subscription token');


if (failures)
    printerr(`${failures} failing test(s)`);
imports.system.exit(failures ? 1 : 0);
