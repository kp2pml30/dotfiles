#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

TURN_END_TIMEOUT_S=300
COMPACT_TIMEOUT_S=900
SETTLE_TIMEOUT_S=30
# Longer input reaches Claude Code as a paste placeholder, which submit cannot verify or erase
MAX_TEXT_CHARS=500

herdr() {
	timeout 30 herdr "$@"
}

die() {
	echo "claude-self-compact: $1" >&2
	exit 1
}

fail() {
	echo "$(date -Is) $session failed: $1" >&2
	herdr notification show "Self-compact failed" --body "$1" >/dev/null || true
	exit 1
}

one_line() {
	local text
	text=$(printf %s "$1" | tr -s '[:space:]' ' ')
	text=${text# }
	printf %s "${text% }"
}

agent_field() {
	herdr agent get "$pane" | jq -r ".result.agent.$1"
}

wait_idle() {
	local deadline=$((SECONDS + $1)) stable=0
	while ((SECONDS < deadline)); do
		case $(agent_field agent_status) in
		idle | done) ((++stable >= 3)) && return 0 ;;
		*) stable=0 ;;
		esac
		sleep 1
	done
	return 1
}

# The live box is the only ❯ followed by NBSP; a dim remainder is a ghost suggestion, not a draft
box_is_clear() {
	local line clear=$'^❯\xc2\xa0[[:space:]]*($|\x01)'
	line=$(herdr pane read "$pane" --source visible --format ansi |
		sed -E $'s/\e\\[2m/\\x01/g; s/\e\\[[0-9;]*m//g; s/\r$//' | grep -a '^❯' | tail -n 1) || return 1
	[[ $line =~ $clear ]]
}

box_text() {
	herdr pane read "$pane" --source visible |
		awk -v prompt=$'❯\xc2\xa0' '
			index($0, prompt) == 1 { box = substr($0, length(prompt) + 1); inside = 1; next }
			/^─/ { inside = 0 }
			inside { box = box $0 }
			END { print box }' |
		tr -d '[:space:]'
}

erase() {
	local keys=() i
	for ((i = 0; i < $1; i++)); do
		keys+=(backspace)
	done
	herdr pane send-keys "$pane" "${keys[@]}" >/dev/null || true
}

# Types only into a clear box and presses Enter only on an exact match, so a draft is never lost
submit() {
	local text=$1 expected i
	expected=$(printf %s "$text" | tr -d '[:space:]')
	box_is_clear || return 1
	herdr pane send-text "$pane" "$text" >/dev/null || return 1
	for ((i = 0; i < 30; i++)); do
		[[ $(box_text) == "$expected" ]] && break
		sleep 0.1
	done
	if ((i == 30)); then
		erase "${#text}"
		return 1
	fi
	herdr pane send-keys "$pane" enter >/dev/null
	for ((i = 0; i < 30; i++)); do
		[[ $(box_text) != "$expected" ]] && return 0
		sleep 0.1
	done
	erase "${#text}"
	return 1
}

# Raw quotes cannot occur inside a JSON string, so tool output mentioning this cannot match
boundaries() {
	grep -cF '"subtype":"compact_boundary"' "$transcript" || true
}

wait_boundary() {
	local before=$1 deadline=$((SECONDS + COMPACT_TIMEOUT_S))
	while ((SECONDS < deadline)); do
		(($(boundaries) > before)) && return 0
		sleep 2
	done
	return 1
}

worker() {
	local instructions=$1 continuation=$2 before
	wait_idle "$TURN_END_TIMEOUT_S" || fail "turn did not end within ${TURN_END_TIMEOUT_S}s"
	before=$(boundaries)
	submit "/compact${instructions:+ $instructions}" || fail "input box unavailable or holds a draft, /compact not sent"
	echo "$(date -Is) $session compact submitted"
	wait_boundary "$before" || fail "no compaction within ${COMPACT_TIMEOUT_S}s, not resuming"
	wait_idle "$SETTLE_TIMEOUT_S" || fail "agent busy after compaction, not resuming"
	submit "$continuation" || fail "input box unavailable or holds a draft, not resuming"
	echo "$(date -Is) $session resumed"
}

[[ ${HERDR_ENV:-} == 1 && -n ${HERDR_PANE_ID:-} ]] || die "not running inside a herdr pane"
session=${CLAUDE_CODE_SESSION_ID:?not running inside Claude Code}
pane=$HERDR_PANE_ID
transcript=$(find "$HOME/.claude/projects" -mindepth 2 -maxdepth 2 -name "$session.jsonl" -print -quit)
[[ -n $transcript ]] || die "no transcript for session $session"

if [[ ${1:-} == --worker ]]; then
	worker "$2" "$3"
	exit 0
fi

continuation="Compaction finished. Continue the task you were working on."
words=()
while (($#)); do
	case $1 in
	--continue)
		(($# >= 2)) || die "--continue needs a message"
		continuation=$2
		shift 2
		;;
	--)
		shift
		words+=("$@")
		break
		;;
	-*) die "usage: claude-self-compact.sh [--continue MESSAGE] [COMPACT_INSTRUCTIONS...]" ;;
	*)
		words+=("$1")
		shift
		;;
	esac
done
instructions=$(one_line "${words[*]}")
continuation=$(one_line "$continuation")

[[ -n $continuation && $continuation != [/!]* ]] || die "--continue message must be plain text"
((${#instructions} + 9 <= MAX_TEXT_CHARS)) || die "instructions exceed $((MAX_TEXT_CHARS - 9)) characters"
((${#continuation} <= MAX_TEXT_CHARS)) || die "--continue message exceeds $MAX_TEXT_CHARS characters"
[[ $(agent_field agent) == claude ]] || die "pane $pane does not host Claude Code"

log=${XDG_CACHE_HOME:-$HOME/.cache}/claude-self-compact.log
mkdir -p "$(dirname "$log")"

# Inherited by the worker, so the lock lasts until it exits
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/claude-self-compact-$session.lock"
flock -n 9 || die "a self-compaction is already pending for this session"

setsid "$0" --worker "$instructions" "$continuation" </dev/null >>"$log" 2>&1 &
echo "Self-compaction scheduled: end your turn now, without further tool calls. Log: $log"
