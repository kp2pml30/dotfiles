#!/usr/bin/env python3
"""Compact a Claude Code conversation after it has sat idle in a herdr pane.

Claude Code has no idle timer past the fixed 60s `idle_prompt` notification,
and no hook can trigger compaction directly, so this drives the TUI from
outside: `arm` (Notification hook) schedules a detached `fire`, which submits
`/compact` through herdr's socket API once the pane has stayed idle long
enough. `cancel` (UserPromptSubmit) and `cleanup` (SessionEnd) tear it down.
`compacted` (PostCompact hook) records when a compaction actually happened --
by any route, ours or auto or a manual `/compact` -- so the cooldown that keeps
a chat from re-compacting too soon is keyed off real compactions, not attempts.

Outside a herdr pane every subcommand is a no-op.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# Claude Code emits the idle_prompt notification at a fixed 60s of idleness,
# so a timer armed by that hook only needs to cover the remainder.
NOTIF_LEAD_SECONDS = 60

# After a compaction fires, suppress further compactions of the same session for
# idle_seconds * this. A fresh compaction already needs another full idle period
# (idle_seconds) before it could naturally re-fire, so this only adds a small
# margin on top -- just enough that a chat can't re-compact within essentially
# one idle window. The transcript file is append-only (compaction adds a summary
# rather than shrinking it), so the size guard alone never re-blocks; and unlike
# `.fired` this cooldown survives UserPromptSubmit.
COMPACT_COOLDOWN_MULTIPLIER = 1.2

STATE_DIR = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'claude-idle-compact'

# Structured diagnostic log: one JSON object per line. Written from every entry
# point (including the early no-op returns the plaintext `log` never covered) so
# an idle cycle that schedules nothing still leaves a trace of why.
JLOG_PATH = Path.home() / '.cache' / 'claude-auto-compact.jsonl'


def env_int(name: str, default: int) -> int:
	try:
		return int(os.environ[name])
	except (KeyError, ValueError):
		return default


def log(session_id: str, message: str) -> None:
	"""Append to the shared log. Never raises: hooks must not break a session."""
	try:
		STATE_DIR.mkdir(parents=True, exist_ok=True)
		stamp = datetime.now().astimezone().isoformat(timespec='seconds')
		with (STATE_DIR / 'log').open('a', encoding='utf-8') as handle:
			handle.write(f'{stamp} idle-compact[{session_id}] {message}\n')
	except OSError:
		pass


def jlog(session_id: str, event: str, **fields: object) -> None:
	"""Append one JSON record (one line) to JLOG_PATH. Never raises."""
	try:
		record = {
			'ts': datetime.now().astimezone().isoformat(timespec='seconds'),
			'pid': os.getpid(),
			'event': event,
			'session_id': session_id or None,
			**fields,
		}
		line = (json.dumps(record, ensure_ascii=False) + '\n').encode('utf-8')
		JLOG_PATH.parent.mkdir(parents=True, exist_ok=True)
		# O_APPEND + a single write keeps concurrent hooks from interleaving
		# bytes within a line.
		fd = os.open(JLOG_PATH, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
		try:
			os.write(fd, line)
		finally:
			os.close(fd)
	except (OSError, ValueError, TypeError):
		pass


def pane_id() -> str | None:
	return os.environ.get('HERDR_PANE_ID') or None


def read_hook_input(args: argparse.Namespace) -> tuple[str, str]:
	"""Return (session_id, transcript_path), preferring flags over stdin JSON."""
	session_id = getattr(args, 'session_id', None) or ''
	transcript = getattr(args, 'transcript', None) or ''
	if session_id and transcript:
		return session_id, transcript
	if sys.stdin.isatty():
		return session_id, transcript
	try:
		payload = json.loads(sys.stdin.read() or '{}')
	except json.JSONDecodeError:
		return session_id, transcript
	return (
		session_id or str(payload.get('session_id') or ''),
		transcript or str(payload.get('transcript_path') or ''),
	)


def kill_pending(session_id: str) -> None:
	"""Best-effort kill of a running timer. The token check is the real guard."""
	try:
		pid = int((STATE_DIR / f'{session_id}.pid').read_text())
	except (OSError, ValueError):
		return
	try:
		os.kill(pid, 15)
	except OSError:
		pass


def reset(session_id: str) -> None:
	"""Invalidate any pending timer. Never creates the state dir: if `arm`
	never ran there is nothing to cancel, and non-herdr sessions leave no
	droppings behind."""
	if not STATE_DIR.is_dir():
		return
	(STATE_DIR / f'{session_id}.gen').write_text(secrets.token_hex(16))
	(STATE_DIR / f'{session_id}.fired').unlink(missing_ok=True)
	kill_pending(session_id)


def cmd_arm(args: argparse.Namespace) -> int:
	pane = pane_id()
	session_id, transcript = read_hook_input(args)

	if pane is None:
		jlog(session_id, 'arm', scheduled=False, reason='no_herdr_pane')
		return 0

	if not session_id:
		jlog(session_id, 'arm', scheduled=False, reason='no_session_id', pane=pane)
		return 0

	STATE_DIR.mkdir(parents=True, exist_ok=True)

	# Already compacted during this idle stretch: don't compact the compaction.
	# Cleared when the user submits their next prompt.
	if (STATE_DIR / f'{session_id}.fired').exists():
		jlog(session_id, 'arm', scheduled=False, reason='already_fired', pane=pane)
		return 0

	# Cooldown: a compaction fired recently. Unlike `.fired`, this survives the
	# user's prompts, so a single chat can't re-compact until the window elapses.
	now = time.time()
	try:
		last_ts = float((STATE_DIR / f'{session_id}.last').read_text())
	except (OSError, ValueError):
		last_ts = 0.0
	cooldown = args.idle_seconds * COMPACT_COOLDOWN_MULTIPLIER
	if last_ts and now - last_ts < cooldown:
		jlog(
			session_id,
			'arm',
			scheduled=False,
			reason='cooldown',
			pane=pane,
			since_last=round(now - last_ts),
			cooldown=cooldown,
		)
		return 0

	kill_pending(session_id)  # supersede a timer from an earlier idle stretch

	token = secrets.token_hex(16)
	(STATE_DIR / f'{session_id}.gen').write_text(token)

	sleep_for = max(0, args.idle_seconds - NOTIF_LEAD_SECONDS)
	jlog(
		session_id,
		'arm',
		scheduled=True,
		pane=pane,
		idle_seconds=args.idle_seconds,
		sleep_for=sleep_for,
		transcript=transcript or None,
		min_transcript_bytes=args.min_transcript_bytes,
	)
	subprocess.Popen(
		[
			sys.executable,
			str(Path(__file__).resolve()),
			'fire',
			'--session-id',
			session_id,
			'--pane-id',
			pane,
			'--sleep-for',
			str(sleep_for),
			'--token',
			token,
			'--transcript',
			transcript,
			'--min-transcript-bytes',
			str(args.min_transcript_bytes),
		],
		stdin=subprocess.DEVNULL,
		stdout=subprocess.DEVNULL,
		stderr=subprocess.DEVNULL,
		start_new_session=True,
	)
	return 0


def herdr_run(session_id: str, *argv: str) -> tuple[bool, str]:
	"""Run a herdr command. Returns (ok, detail) where detail is stderr/stdout
	(herdr reports errors as JSON on one of them). Every call we make is a quick
	socket request, so a short timeout is a safe backstop."""
	try:
		result = subprocess.run(
			['herdr', *argv],
			capture_output=True,
			text=True,
			timeout=30,
			check=False,
		)
	except (OSError, subprocess.SubprocessError) as exc:
		log(session_id, f'herdr {" ".join(argv)} failed: {exc}')
		jlog(session_id, 'herdr', argv=list(argv), ok=False, error=repr(exc))
		return False, repr(exc)
	detail = result.stderr.strip() or result.stdout.strip()
	if result.returncode != 0:
		log(session_id, f'herdr {" ".join(argv)} exited {result.returncode}: {detail}')
		jlog(
			session_id,
			'herdr',
			argv=list(argv),
			ok=False,
			returncode=result.returncode,
			output=detail[:500],
		)
		return False, detail
	jlog(session_id, 'herdr', argv=list(argv), ok=True, output=(detail or None))
	return True, detail


def cmd_fire(args: argparse.Namespace) -> int:
	session_id = args.session_id
	STATE_DIR.mkdir(parents=True, exist_ok=True)
	(STATE_DIR / f'{session_id}.pid').write_text(str(os.getpid()))

	jlog(session_id, 'fire_wake', pane=args.pane_id, slept=args.sleep_for)

	time.sleep(args.sleep_for)

	# A prompt submitted while we slept bumps the generation token.
	try:
		current = (STATE_DIR / f'{session_id}.gen').read_text()
	except OSError:
		current = ''
	if current != args.token:
		log(session_id, 'superseded, not compacting')
		jlog(session_id, 'fire_skip', reason='superseded')
		return 0

	if args.min_transcript_bytes > 0 and args.transcript:
		try:
			size = Path(args.transcript).stat().st_size
		except OSError:
			size = 0
		if size and size < args.min_transcript_bytes:
			log(
				session_id,
				f'transcript {size}B < {args.min_transcript_bytes}B, not worth compacting',
			)
			jlog(
				session_id,
				'fire_skip',
				reason='transcript_too_small',
				size=size,
				min=args.min_transcript_bytes,
			)
			return 0

	# Mark before sending: the compaction turn makes the agent busy and then
	# idle again, which would otherwise re-arm and compact a second time. The
	# cooldown timestamp (`.last`) is written by the PostCompact hook when the
	# compaction actually lands, not here -- a send that doesn't compact should
	# not start a cooldown.
	fired = STATE_DIR / f'{session_id}.fired'
	fired.touch()

	# herdr's `agent prompt` does NOT reliably submit a slash command to Claude
	# Code: it types the text but the Enter often doesn't register, and herdr
	# then returns `agent_prompt_stalled` (observed on every real /compact --
	# "no observed state change within 5000 ms; status is idle"). Sending the
	# text and the Enter as two explicit pane events does land. herdr cannot
	# observe the compaction as a state change, so there is no reliable post-hoc
	# confirmation: the `.fired` guard and the cooldown above -- not a wait --
	# are what keep a single chat from compacting more than once per window.
	ok, detail = herdr_run(session_id, 'pane', 'send-text', args.pane_id, '/compact')
	if ok:
		ok, detail = herdr_run(session_id, 'pane', 'send-keys', args.pane_id, 'enter')
		if not ok:
			# The text landed but the Enter did not: clear the stranded
			# `/compact` from the input box (best effort) so it neither appends
			# to the next fire's `/compact` nor gets submitted as a prefix of a
			# returning user's next prompt.
			herdr_run(session_id, 'pane', 'send-keys', args.pane_id, 'esc')
	if ok:
		log(session_id, 'compacted via pane send-text + enter')
		jlog(session_id, 'fire_done', method='pane_send_text')
		return 0

	# Could not reach the pane (herdr down / pane gone). Nothing was submitted,
	# so drop the fired mark to allow a genuine retry next idle stretch.
	fired.unlink(missing_ok=True)
	log(session_id, f'could not submit /compact to pane {args.pane_id}: {detail[:200]}')
	jlog(session_id, 'fire_failed', detail=detail[:1000])
	return 1


def cmd_cancel(args: argparse.Namespace) -> int:
	pane = pane_id()
	session_id, _ = read_hook_input(args)
	if pane is None:
		jlog(session_id, 'cancel', acted=False, reason='no_herdr_pane')
		return 0
	if session_id:
		reset(session_id)
	jlog(session_id, 'cancel', acted=bool(session_id), pane=pane)
	return 0


def cmd_cleanup(args: argparse.Namespace) -> int:
	pane = pane_id()
	session_id, _ = read_hook_input(args)
	if pane is None:
		jlog(session_id, 'cleanup', acted=False, reason='no_herdr_pane')
		return 0
	if not session_id:
		jlog(session_id, 'cleanup', acted=False, reason='no_session_id', pane=pane)
		return 0
	reset(session_id)
	for suffix in ('gen', 'pid', 'fired', 'last'):
		(STATE_DIR / f'{session_id}.{suffix}').unlink(missing_ok=True)
	jlog(session_id, 'cleanup', acted=True, pane=pane)
	return 0


def cmd_compacted(args: argparse.Namespace) -> int:
	"""PostCompact hook: a compaction just landed, so stamp the cooldown. Fires
	for every compaction -- ours, an auto context-limit one, or a manual
	/compact -- which is exactly what the cooldown should track."""
	pane = pane_id()
	# PostCompact carries a `trigger` (auto|manual) we don't get elsewhere, so
	# parse the payload directly rather than via read_hook_input.
	session_id = getattr(args, 'session_id', None) or ''
	trigger = ''
	if not sys.stdin.isatty():
		try:
			payload = json.loads(sys.stdin.read() or '{}')
		except json.JSONDecodeError:
			payload = {}
		session_id = session_id or str(payload.get('session_id') or '')
		trigger = str(payload.get('trigger') or '')
	if pane is None:
		jlog(
			session_id,
			'compacted',
			acted=False,
			reason='no_herdr_pane',
			trigger=trigger or None,
		)
		return 0
	if not session_id:
		jlog(session_id, 'compacted', acted=False, reason='no_session_id', pane=pane)
		return 0
	STATE_DIR.mkdir(parents=True, exist_ok=True)
	(STATE_DIR / f'{session_id}.last').write_text(str(time.time()))
	jlog(session_id, 'compacted', acted=True, pane=pane, trigger=trigger or None)
	return 0


def build_parser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser(
		prog='idle_compact.py',
		description=__doc__,
		formatter_class=argparse.RawDescriptionHelpFormatter,
	)
	sub = parser.add_subparsers(dest='command', required=True)

	arm = sub.add_parser(
		'arm',
		help='Notification hook (matcher: idle_prompt). Schedule a compaction.',
	)
	arm.add_argument(
		'--idle-seconds',
		type=int,
		default=env_int('CLAUDE_IDLE_COMPACT_SECONDS', 1800),
		help='total idle time before /compact fires (default: %(default)s)',
	)
	arm.add_argument(
		'--min-transcript-bytes',
		type=int,
		default=env_int('CLAUDE_IDLE_COMPACT_MIN_TRANSCRIPT_BYTES', 500_000),
		help='skip compaction below this transcript size; 0 disables the check. '
		'A crude proxy -- transcript bytes are not tokens (default: %(default)s)',
	)
	arm.add_argument('--session-id', help='override the session id from stdin JSON')
	arm.add_argument('--transcript', help='override the transcript path from stdin JSON')
	arm.set_defaults(func=cmd_arm)

	fire = sub.add_parser('fire', help='Detached timer. Spawned by `arm`, not by a hook.')
	fire.add_argument('--session-id', required=True)
	fire.add_argument('--pane-id', required=True)
	fire.add_argument('--sleep-for', type=float, required=True)
	fire.add_argument('--token', required=True)
	fire.add_argument('--transcript', default='')
	fire.add_argument('--min-transcript-bytes', type=int, default=0)
	fire.set_defaults(func=cmd_fire)

	cancel = sub.add_parser(
		'cancel', help='UserPromptSubmit hook. Cancel a pending compaction.'
	)
	cancel.add_argument('--session-id', help='override the session id from stdin JSON')
	cancel.set_defaults(func=cmd_cancel)

	cleanup = sub.add_parser(
		'cleanup', help="SessionEnd hook. Drop this session's state."
	)
	cleanup.add_argument('--session-id', help='override the session id from stdin JSON')
	cleanup.set_defaults(func=cmd_cleanup)

	compacted = sub.add_parser(
		'compacted', help='PostCompact hook. Stamp the re-compaction cooldown.'
	)
	compacted.add_argument('--session-id', help='override the session id from stdin JSON')
	compacted.set_defaults(func=cmd_compacted)

	return parser


def main() -> int:
	args = build_parser().parse_args()
	if args.command == 'fire':
		return cmd_fire(args)
	# Hook subcommands must never break the session, and `cancel` must never
	# write to stdout: UserPromptSubmit stdout is injected as context.
	try:
		return args.func(args)
	except Exception as exc:  # noqa: BLE001 - deliberate catch-all on the hook path
		sid = getattr(args, 'session_id', None) or '?'
		log(sid, f'{args.command} failed: {exc!r}')
		jlog(sid, 'error', command=args.command, error=repr(exc))
		return 0


if __name__ == '__main__':
	sys.exit(main())
