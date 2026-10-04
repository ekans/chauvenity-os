// Pure helpers for reading and rendering Claude subscription usage.
//
// Ported unchanged from the claude-usage@ducatore GNOME Shell extension. No
// toolkit imports here on purpose, and the `.mjs` extension is load-bearing:
// Qt loads a `.mjs` file as an ECMAScript module, so ClaudeUsage.qml can
// `import "usage.mjs" as Usage` while `gjs -m test-usage.mjs` imports the very
// same file. One copy of the logic, tested outside any UI.

const WARNING_PERCENT = 75;
const ALARM_PERCENT = 90;

// How far past the budget line a window has to be before the delta is worth
// pointing at. Without a band the chip flips colour every poll while you sit on
// the line, which is exactly where you sit most of the time.
const PACE_TOLERANCE_POINTS = 5;

/** The shortest gap between two fetches a click is allowed to cause. */
const CLICK_FLOOR_SECONDS = 5;

/**
 * How long each window is, and whether its budget line waits for the weekend.
 * The API reports only when a window resets, never when it started, so the
 * length is the one thing that has to be known here.
 *
 * The weekly caps are spent over working hours: the line they should be followed
 * against reaches 100% when the last working day ends, not when the clock runs
 * out. Measured against wall-clock time instead, every Friday reads as a blowout
 * and every Monday as a surplus that is really just two idle days and seven
 * nights. A session window is short enough to sit inside one working day, so it
 * stays literal.
 */
export const WINDOWS = {
    fiveHour: {minutes: 5 * 60, workdays: false},
    sevenDay: {minutes: 7 * 24 * 60, workdays: true},
    fable: {minutes: 7 * 24 * 60, workdays: true},
};

/**
 * Whether a click gets its fetch. Measured from when the last refresh *started*,
 * and from every refresh rather than only the clicked ones: a slow request must
 * not earn the next click an earlier turn, and a poll that landed a second ago
 * has already answered the question the click is asking.
 */
export function mayRefreshOnClick(lastRefreshStartedAtMs, nowMs) {
    return lastRefreshStartedAtMs === null ||
        nowMs - lastRefreshStartedAtMs >= CLICK_FLOOR_SECONDS * 1000;
}

/** The hours the cap is actually spent in, Monday through Friday. */
const WORKDAY = {firstWeekday: 1, lastWeekday: 5, fromHour: 8, toHour: 19};

/**
 * Minutes between two instants that fall inside working hours. Walked a local day
 * at a time — eight iterations for the longest window here — and every boundary
 * built from calendar parts, because neither the length of a day nor the distance
 * to 08:00 is a constant across a daylight-saving change.
 */
function workingMinutesBetween(startMs, endMs) {
    if (endMs <= startMs)
        return 0;

    const midnight = new Date(startMs);
    midnight.setHours(0, 0, 0, 0);

    let total = 0;
    for (let dayStart = midnight.getTime(); dayStart < endMs;) {
        const day = new Date(dayStart);
        const [year, month, date, weekday] =
            [day.getFullYear(), day.getMonth(), day.getDate(), day.getDay()];
        const nextDay = new Date(year, month, date + 1).getTime();

        if (weekday >= WORKDAY.firstWeekday && weekday <= WORKDAY.lastWeekday) {
            const from = Math.max(startMs, new Date(year, month, date, WORKDAY.fromHour).getTime());
            const to = Math.min(endMs, new Date(year, month, date, WORKDAY.toHour).getTime());
            total += Math.max(0, to - from) / 60000;
        }
        dayStart = nextDay;
    }
    return total;
}

// Anthropic's official brand colours (anthropics/skills, brand-guidelines).
export const PALETTE = {
    dark: '#141413',
    light: '#faf9f5',
    midGray: '#b0aea5',
    orange: '#d97757',
};

/** Access token Claude Code stores for the logged-in subscription. */
export function extractToken(credentials) {
    const token = credentials?.claudeAiOauth?.accessToken;
    if (!token)
        throw new Error('No Claude subscription token in ~/.claude/.credentials.json — log in with `claude`');
    return token;
}

/** Shape the /api/oauth/usage payload down to the three windows we display. */
export function parseUsage(payload) {
    if (payload === null || typeof payload !== 'object')
        throw new Error('Unexpected usage payload from api.anthropic.com');

    return {
        fiveHour: parseWindow(payload.five_hour),
        sevenDay: parseWindow(payload.seven_day),
        fable: parseScopedModelLimit(payload.limits, 'Fable'),
    };
}

/**
 * A model's slice of the weekly cap. Only the self-describing `limits` array
 * carries it: the legacy `seven_day_opus` / `seven_day_sonnet` keys report null
 * for every account, so there is nothing to fall back to.
 */
function parseScopedModelLimit(limits, displayName) {
    if (!Array.isArray(limits))
        return null;

    const limit = limits.find(entry =>
        entry?.kind === 'weekly_scoped' &&
        entry?.scope?.model?.display_name === displayName);
    if (!limit)
        return null;

    return {
        percent: Math.round(limit.percent ?? 0),
        resetsAt: limit.resets_at ?? null,
    };
}

function parseWindow(window) {
    if (window === null || typeof window !== 'object')
        return null;

    return {
        percent: Math.round(window.utilization ?? 0),
        resetsAt: window.resets_at ?? null,
    };
}

/** Time left before a window resets, e.g. "1h 10m" or "4d 19h". */
export function formatCountdown(resetsAt, nowMs) {
    if (!resetsAt)
        return 'unknown';

    const remainingMinutes = Math.floor((Date.parse(resetsAt) - nowMs) / 60000);
    if (remainingMinutes <= 0)
        return 'now';

    const days = Math.floor(remainingMinutes / 1440);
    const hours = Math.floor((remainingMinutes % 1440) / 60);
    const minutes = remainingMinutes % 60;

    if (days > 0)
        return `${days}d ${hours}h`;
    if (hours > 0)
        return `${hours}h ${minutes}m`;
    return `${minutes}m`;
}

/**
 * Points spent above (or below) the budget line — the line that reaches 100%
 * exactly when the window's usable time runs out. Positive means you are ahead of
 * budget and will run out early; the sign is what the chip is for.
 *
 * Points rather than a ratio on purpose: `used / elapsed` is unbounded at the
 * start of a window, where a single message reads as several times the pace.
 */
export function paceDelta(window, spec, nowMs) {
    if (!window?.resetsAt)
        return null;

    const resetsAtMs = Date.parse(window.resetsAt);
    const startsAtMs = resetsAtMs - spec.minutes * 60000;
    // Clamped at both ends: a window past its reset is fully elapsed, and a reset
    // further out than the window itself is clock skew, not a fresh window.
    const atMs = Math.min(resetsAtMs, Math.max(startsAtMs, nowMs));

    const spent = spec.workdays
        ? workingMinutesBetween(startsAtMs, atMs)
        : (atMs - startsAtMs) / 60000;
    const whole = spec.workdays
        ? workingMinutesBetween(startsAtMs, resetsAtMs)
        : spec.minutes;
    if (whole <= 0)
        return null;

    return Math.round(window.percent - (spent / whole) * 100);
}

/** The delta as the panel says it: a direction and a magnitude. */
export function formatPaceDelta(delta) {
    if (delta === null)
        return '';
    if (delta > 0)
        return `▲${delta}`;
    if (delta < 0)
        return `▼${-delta}`;
    return '=0';
}

/**
 * Only overspending is painted. Being under the line is the normal case and
 * needs no attention, and the arrow already carries the direction, so the accent
 * never has to be read as colour alone.
 */
export function paceColor(delta) {
    if (delta !== null && delta >= PACE_TOLERANCE_POINTS)
        return PALETTE.orange;
    return PALETTE.midGray;
}

export function formatPercent(window) {
    return window ? `${window.percent}%` : '–';
}

/**
 * How to paint a percentage on the dark top bar. The brand palette has a single
 * warm accent, so the alarm state escalates by inverting onto it rather than by
 * reaching for a colour Anthropic does not use.
 */
export function usageStyle(percent) {
    if (percent >= ALARM_PERCENT)
        return {color: PALETTE.dark, background: PALETTE.orange};
    if (percent >= WARNING_PERCENT)
        return {color: PALETTE.orange, background: null};
    return {color: PALETTE.light, background: null};
}
