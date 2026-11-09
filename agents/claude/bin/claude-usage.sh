#!/usr/bin/env bash
# Prints the account's session and weekly limits by reading /usage from a throwaway Claude TUI
set -euo pipefail

timeout_s=${CLAUDE_USAGE_TIMEOUT:-45}
# Must already be trusted: the folder trust dialog is never answered here
dir=${CLAUDE_USAGE_DIR:-$HOME/dotfiles}
sock=claude-usage-$$
tm() { tmux -L "$sock" "$@"; }
trap 'tm kill-server 2>/dev/null || true' EXIT

screen() { tm capture-pane -p -J -S - 2>/dev/null || true; }

fail() {
	echo "claude-usage: $1" >&2
	screen | tail -30 >&2
	exit 1
}

wait_for() {
	local deadline=$((SECONDS + timeout_s))
	until screen | grep -Pzq "$1"; do
		tm has-session 2>/dev/null || fail "claude exited early"
		((SECONDS < deadline)) || fail "timed out waiting for: $1"
		sleep 0.25
	done
}

tm -f /dev/null new-session -d -x 120 -y 70 -c "$dir" claude
wait_for '❯'
if screen | grep -q 'I trust this folder'; then
	fail "$dir is not trusted by Claude; set CLAUDE_USAGE_DIR to a folder that is"
fi
tm send-keys -l /usage
sleep 0.5
tm send-keys Enter
wait_for 'Current week \(all models\)[^\n]*\n[^\n]*% used[^\n]*\n[^\n]*Resets'

screen | awk '
	/Current session/            { label = "session"; next }
	/Current week \(all models\)/ { label = "week"; next }
	/Current week \(/            { label = ""; next }
	label && match($0, /[0-9]+% used/) { used[label] = substr($0, RSTART, RLENGTH - 5); next }
	label && /Resets/ { sub(/^.*Resets /, ""); sub(/[[:space:]│]+$/, ""); resets[label] = $0; label = "" }
	END {
		if (!("session" in used) || !("week" in used)) exit 1
		printf "session %s resets %s\n", used["session"], resets["session"]
		printf "week %s resets %s\n", used["week"], resets["week"]
	}
' || fail "could not parse /usage"
