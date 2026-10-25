---
name: dsh
description: Use when delegating a task, review or research to DeepSeek Harness (`dsh`, DeepSeek models) — one-shot headless runs, resuming a dsh session, or sending a message into a running dsh-tui session and reading its reply. Also use when the user says /dsh or asks to "ask dsh / deepseek".
---

# dsh — DeepSeek Harness

2 ways in:

- **Headless** (`dsh headless`): you own the run. A plain subprocess, no TUI, no tmux. Default for delegation
- **Inject** into a live `dsh-tui`: a session the user (or you) already runs. Only when asked

## Non-negotiables

- **Close stdin.** Without a task argument, a non-TTY stdin *is* the task. Always `</dev/null` or pipe the task in
- **Never start interactive commands bare.** `dsh-tui` and `dsh tui` take over the terminal and hang the Bash tool.
	If you need a TUI, run it in tmux or herdr
- **Permission mode is pinned at session creation.** `DSH_PERMISSION_MODE` only affects fresh sessions; a resumed
	session keeps its original mode. Need a different mode? Start a new session
- **Headless has no approval channel.** Anything needing approval is denied, never auto-approved
- **Keep logs.** Write `--json` events to a file in your scratchpad; stderr also gets a file, not `/dev/null`

## Headless Runs

```bash
L=<scratchpad>/dsh-<topic>  # unique per run
cd <workdir> && DSH_PERMISSION_MODE=read-only dsh headless --json "<task>" </dev/null 2>"$L.err" >"$L.jsonl"
echo "exit=$?"; jq -r 'select(.type=="final").text' "$L.jsonl"
```

1. **Workdir:** the invocation cwd; it becomes the sandbox workspace root. There is no `--cd` flag
2. **Permission modes:**
	- `read-only` — queries, reviews, research. Writes fail, escalation is denied
	- `workspace-write` — the default; writes inside the workdir only. Network and processes are not sandboxed
	- `danger-full-access` — implementation per user preference; no sandbox, approval `never`
3. **Model:** default `deepinfra` / `deepseek-ai/DeepSeek-V4-Pro`, effort `high` (`dsh-headless-bundle` in
	`nix/personal/agent/dsh.nix`). Override for a cheap or quick task:

	```bash
	dsh headless --patch <(printf -- '- id: agent-default-model\n  config: {provider: deepinfra, model: deepseek-ai/DeepSeek-V4.1-Flash, reasoningEffort: "off"}\n') ...
	```

	Efforts: `off`, `high`, `max`. The ChatGPT (`openai-codex`) route only exists inside dsh-tui
4. **Long tasks:** run with `run_in_background`; there is no heartbeat before the first step commits.
	Progress is visible as `status` lines in the `.jsonl`. dsh's own bash calls default to a 60 s timeout; overruns
	move to background jobs
5. **Without `--json`:** stdout is the final answer only; stderr carries the full reasoning (`dsh: reasoning:`)

### `--json` Events

1 JSON object per line, committed per step, not streamed per token:

|Type|Fields|
|---|---|
|`session`|`sessionId` (`session-<uuid>`), `cwd` — first, unless a usage error emits a lone `error`|
|`status`|`phase`: `turn_start`, `step_start`, `step_end` (+`usage`), `turn_end` (+`reason.kind`)|
|`thinking`, `text`|`text`|
|`tool_call`|`callId`, `tool`, `input`|
|`tool_result`|`callId`, `status` (`completed` / `error`), `result`|
|`final`|`text`, never truncated — the answer|
|`error`|`message`; runner failure, no `final` follows|

Other strings are capped at 8 KiB. Exit `0` iff `turn_end.reason.kind == "completed"`; an in-turn failure still
emits `final`, so check the exit code.

Useful filters:

```bash
jq -r 'select(.type=="session").sessionId' "$L.jsonl"
jq -c 'select(.type=="tool_call") | {tool, input}' "$L.jsonl"
jq -c 'select(.type=="tool_result" and .status=="error")' "$L.jsonl"
```

### Follow-ups

```bash
cd <same workdir> && dsh headless --json --session-id session-<uuid> "<follow-up>" </dev/null ...
```

- Must run from the session's original cwd, else it is refused
- Only 1 process may hold a session (`flock` on `session.lock`); don't resume a session a TUI has open
- TUI sessions (bare UUID ids) are refused headless: their agent preset doesn't exist there

## Live dsh-tui Sessions

Each open chat listens on a Unix socket. One-way: you send, then read the reply from the session log.

1. **Find it:** `~/.dsh-tui/inject/servers.json` lists `pid`, `sessionId`, `cwd`, `socketPath`. Check the `pid`
	is alive (`kill -0`); stale entries and `.sock` files linger. An entry may exist even when listening failed
2. **Send:**

	```bash
	jq -nc --arg t "<message>" '{type:"prompt.append",text:$t}, {type:"command.execute",command:"prompt.submit"}' \
		| socat - UNIX-CONNECT:<socketPath>
	```

	- Submits the **whole input box**, including anything the user half-typed — never inject into the user's session
		without their consent
	- Queued after the current turn if one is running. Slash commands are not interpreted
	- Needs the chat screen: a fresh dsh-tui on its home screen accepts the connection but drops the prompt.
		Start the chat with a first message typed via tmux / herdr
	- Socket paths over 108 bytes cannot bind (`AF_UNIX` limit), e.g. under a long `HOME`
3. **Read the reply:** the session log is zstd JSONL, readable while live:

	```bash
	F=$(echo ~/.dsh/sessions/*/<sessionId>/session.v4.jsonl.zstd)
	zstdcat "$F" | jq -r 'select(.type=="assistant/message") | .data.message.content[] | select(.type=="text") | .text' | tail
	zstdcat "$F" | jq -c 'select(.type=="turn/end") | .data' | tail -1   # done when the turn count matches
	```

## Sessions

- Logs: `~/.dsh/sessions/<mangled cwd>/<id>/session.v4.jsonl.zstd`, e.g. `--home-kp2pml30-dotfiles--`
- Ids: headless `session-<uuid>`, dsh-tui bare UUID; titles for TUI sessions in `~/.dsh-tui/session-index.json`
- No list command; `ls ~/.dsh/sessions/*/`
- Reopen in the TUI: `dsh-tui --resume <id>` (interactive — tmux / herdr only)

## Cost

~11k input tokens of base prompt per run, even for a 1-word answer. Batch related questions into 1 run
