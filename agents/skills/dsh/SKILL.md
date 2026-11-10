---
name: dsh
description: Use when delegating a task, review or research to DeepSeek Harness (`dsh`, ChatGPT Codex models) — one-shot headless runs, long-lived multi-turn ACP sessions you can steer, cancel and approve, or sending a message into a user's running dsh-tui session. Also use when the user says /dsh or asks to "ask dsh / deepseek".
---

# dsh — DeepSeek Harness

3 ways in:

|Way|Use for|Models|
|---|---|---|
|**Headless** (`dsh headless`)|1 task, 1 answer. Default for delegation|Codex|
|**ACP** (`dsh --profile acp`)|Multi-turn work you own: steer, cancel, approve, run several sessions|Codex|
|**Inject** into a live `dsh-tui`|A session the user already runs. Only when asked|Whatever it uses|

**Always use Codex** (`openai-codex`, covered by the ChatGPT subscription).

**Subagent models:** in `dsh tui`, `subagent` takes `provider`, `model` and `reasoning_effort`, and `list_subagent_models`
shows the routes (`standard`, `ptc`, `cordis` presets). In headless and ACP it inherits the parent's model, so use
`workflow`'s `agent(prompt, {provider, model})` there.

## Non-negotiables

- **Close stdin on headless.** Without a task argument, a non-TTY stdin *is* the task. Always `</dev/null` or pipe the
	task in
- **Never start interactive commands bare.** `dsh-tui` and `dsh tui` take over the terminal and hang the Bash tool.
	If you need a TUI, run it in tmux or herdr
- **Keep logs.** Events go to a file in your scratchpad; stderr also gets a file, not `/dev/null`
- **`read-only` is not a hard limit on ACP.** The AI agent can ask to escalate, so reject every permission request

## Headless Runs

```bash
L=<scratchpad>/dsh-<topic>  # unique per run
cd <workdir> && DSH_PERMISSION_MODE=read-only dsh headless --json "<task>" </dev/null 2>"$L.err" >"$L.jsonl"
echo "exit=$?"; jq -r 'select(.type=="final").text' "$L.jsonl"
```

1. **Workdir:** the invocation cwd; it becomes the sandbox workspace root. There is no `--cd` flag
2. **Permission modes:** pinned at session creation, so `DSH_PERMISSION_MODE` only affects fresh sessions
	- `read-only` — queries, reviews, research. Writes fail, escalation is denied
	- `workspace-write` — the default; writes inside the workdir only. Network and processes are not sandboxed
	- `danger-full-access` — implementation per user preference; no sandbox, approval `never`
3. **Approvals:** there is no channel; anything needing approval is denied, never auto-approved
4. **Model:** default `openai-codex` / `gpt-6-astra`, effort `high` (`codexPatch` in `nix/personal/agent/dsh.nix`).
	Override for a quick task, with `--patch` before any other option:

	```bash
	dsh headless --patch <(printf -- '- id: agent-default-model\n  config: {provider: openai-codex, model: gpt-6-luna, reasoningEffort: low}\n') --json ...
	```

	- Codex efforts: `minimal`, `low`, `medium`, `high`, `xhigh`, `max`
	- Signed out of Codex: exit `1` with `Provider is not configured: openai-codex` on stderr and an empty `final`
5. **Long tasks:** run with `run_in_background`; its exit notifies you. There is no heartbeat before the first step
	commits. dsh's own bash calls default to a 60 s timeout; overruns move to background jobs
6. **Without `--json`:** stdout is the final answer only; stderr carries the full reasoning (`dsh: reasoning:`)
7. **Stopping:** it exits by itself at turn end. To abort, stop the background task

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
- A resumed session keeps its original permission mode
- TUI and ACP sessions (bare UUID ids) are refused headless: their agent preset doesn't exist there

## ACP Sessions

`dsh --profile acp` serves [ACP](https://agentclientprotocol.com) v1 over stdio through
`@openma/deepseek-harness-acp`: newline-delimited JSON-RPC, stdin in, stdout out. 1 server holds several sessions.

### Start

Bash calls can't hold stdin open, so use a FIFO opened read-write: it never reaches EOF, and needs no helper process.
Run this with `run_in_background`:

```bash
L=<scratchpad>/acp-<topic>; rm -f "$L.in"; mkfifo "$L.in"
DSH_PERMISSION_MODE=read-only dsh --profile acp <>"$L.in" >"$L.jsonl" 2>"$L.err"
```

Then, in later calls, define the helpers and open a session:

```bash
L=<same path>
# bounded: opening a FIFO with no reader blocks forever, e.g. after a server crash
send() { [ -p "$L.in" ] && timeout 5 tee "$L.in" >/dev/null; }
call() { jq -c --argjson id "$1" --arg m "$2" '{jsonrpc:"2.0",id:$id,method:$m,params:.}' | send; } # params on stdin
res() { # <id> [seconds]; prints the response to request <id>, fails on timeout
	local i r
	for ((i = 0; i < 2 * ${2:-60}; i++)); do
		r=$(jq -c "select(.id==$1 and (has(\"method\")|not))" "$L.jsonl" 2>/dev/null)
		[ -n "$r" ] && { printf '%s\n' "$r"; return; }
		sleep 0.5
	done
	return 1
}

until [ -p "$L.in" ]; do sleep 0.2; done
jq -n '{protocolVersion:1,clientCapabilities:{}}' | call 1 initialize; res 1
jq -n --arg c <absolute workdir> '{cwd:$c,mcpServers:[]}' | call 2 session/new
SID=$(res 2 | jq -er .result.sessionId)
```

- Wait with `res` after every request except `session/prompt`: handlers run concurrently, so a request sent during a
	model switch can hit an agent that is being replaced
- Use your own increasing ids. Server requests have their own id sequence, so always tell them apart by `method`

### Choose Model And Mode

Set both on every new session, before the first prompt. Switching saves them as defaults in the unmanaged
`~/.dsh/profiles/acp/cordis.patch.yml`, so a fresh session otherwise inherits whatever the last one picked. That saved
row also outranks the Nix default permanently.

```bash
jq -n --arg s "$SID" '{sessionId:$s,configId:"model",value:"openai-codex::gpt-6-astra"}' | call 3 session/set_config_option; res 3
jq -n --arg s "$SID" '{sessionId:$s,modeId:"read-only"}' | call 4 session/set_mode; res 4
```

- **Models:** default `openai-codex::gpt-6-astra`; also `gpt-6-luna`, `gpt-6-sol`, `gpt-6.1-sol`, `gpt-5.6-luna`,
	`gpt-5.6-terra`, `gpt-5.6-sol`. The live list is the `model` entry of `configOptions` in the `session/new` result
- **Effort:** default `high`; `configId:"effort"`, listed the same way
- **Modes:** `read-only`, `workspace-write`, `danger-full-access`; `DSH_PERMISSION_MODE` only sets the server's start
	value for new sessions
- **Codex:** reuses the sign-in from `/auth login openai-codex` in dsh-tui. When signed out, `session/new` still
	succeeds on the default model, then the prompt fails with `Provider is not configured: openai-codex`. Restart the
	server after signing in
- **Never use `DSH_MODEL`:** it pairs with the saved default provider, and a mismatch silently falls back to another
	model (only a stderr warning)

### Send A Message

Write the task to a file, which avoids shell quoting and argument size limits. `N` marks where this turn starts in the
log:

```bash
N=$(wc -l <"$L.jsonl")
jq -n --arg s "$SID" --rawfile t "$L.task" '{sessionId:$s,prompt:[{type:"text",text:$t}]}' | call 5 session/prompt
```

- **Wait for the previous `session/prompt` response first.** During a turn a second prompt is steered in and answers
	`end_turn` at once, which looks like completion
- **Leading `/`:** text such as `/status` or `/compact` runs as a command with no model turn
- **Web search:** native `web_search` fails here without a DeepSeek key, so tell the task to use
	`mcp__brave__brave_web_search`

To add to a turn that is already running, steer it. The message lands in that turn, and the original `session/prompt`
stays in charge of output and completion:

```bash
jq -n --arg s "$SID" --rawfile t "$L.steer" '{sessionId:$s,prompt:[{type:"text",text:$t}],_meta:{steering:{idleBehavior:"promptRequired"}}}' | call 6 _session/steering; res 6
```

Expect `{"outcome":"injected"}`. Anything else means nothing was injected: wait for the running prompt's response,
then send a normal `session/prompt`.

### Get Notified

Nothing pings you by itself, so run `Monitor` on the log, with `N` and the id from *Send A Message*. Starting at `N`
means it can't miss events that land before it is armed. It must cover 3 things:

1. **Completion:** the response to that `session/prompt`, carrying `stopReason` or `error`
2. **Approval:** a `session/request_permission` request. The turn stalls until you answer it
3. **Crash:** the background server task exiting, which the harness reports. No response will follow

```bash
tail -n +$((N+1)) -F "$L.jsonl" | jq --unbuffered -c 'select(.method=="session/request_permission" or (.id==5 and (has("method")|not))) | {id, method, stop:.result.stopReason, error:.error.message}'
```

Match the response shape, never a bare `grep stopReason`: a finished subagent's `session_info_update` also carries a
`stopReason`, mid-turn. `stopReason` values include `end_turn` and `cancelled`; a failed prompt has `error` instead.

### Read The Reply

The reply arrives as `agent_message_chunk` updates, and the log holds every turn, so start at `N`. With several
sessions on 1 server, also filter on `.params.sessionId`.

```bash
tail -n +$((N+1)) "$L.jsonl" | jq -j 'select(.method=="session/update" and .params.update.sessionUpdate=="agent_message_chunk") | .params.update.content.text'
```

### Read Progress

Every `session/update` is in `$L.jsonl` as it happens. Main `.params.update.sessionUpdate` values:

|Value|Meaning|
|---|---|
|`agent_message_chunk`, `agent_thought_chunk`|Reply and reasoning text|
|`tool_call`, `tool_call_update`|`title`, `kind`, `status`: `pending`, `in_progress`, `completed`, `failed`|
|`plan`|The AI agent's todo list|
|`usage_update`|Token accounting|
|`session_info_update`|Session metadata and subagent lifecycle|

```bash
jq -c 'select(.params.update.sessionUpdate=="tool_call") | .params.update | {title, kind}' "$L.jsonl"
```

### Answer Approvals

Reply with the request's own id. Options: `allow-once`, `allow-always` (for this session), `reject-once`.

```bash
echo '{"jsonrpc":"2.0","id":<request id>,"result":{"outcome":{"outcome":"selected","optionId":"reject-once"}}}' | send
```

`read-only` asks when the sandbox blocks a write, and allowing it performs the write. `danger-full-access` never asks.

### Cancel A Turn

A notification, so no id. The pending `session/prompt` then answers with `stopReason: "cancelled"`, and the session
stays usable:

```bash
jq -nc --arg s "$SID" '{jsonrpc:"2.0",method:"session/cancel",params:{sessionId:$s}}' | send
```

### Shut Down

The server runs until told otherwise, so you own it. Always stop it when finished:

1. **1 session:** `session/close` with `{sessionId}`; it stays on disk and the server keeps running
2. **The server:** stop the background task, or send SIGTERM to the process. It drains and exits `0`

### Resume

`session/list` shows saved sessions. Resume with `session/resume` and `{sessionId, cwd, mcpServers:[]}`, from any
server process.

- History is restored for the AI agent, but old updates aren't replayed
- The session keeps its own mode, which can differ from `DSH_PERMISSION_MODE`: check `modes.currentModeId`
- Its model may be reported wrongly, so set the model again before prompting
- Only 1 process may hold a session

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

4. **Completion:** nothing notifies you. Poll for `turn/end` in `Monitor`, and also `kill -0` the `pid`: a crashed TUI
	never writes it
5. **Shutdown:** the socket has no quit command, so a TUI you started needs `tmux kill-session`. Leave the user's alone

## Sessions

- Logs: `~/.dsh/sessions/<mangled cwd>/<id>/session.v4.jsonl.zstd`, e.g. `--home-kp2pml30-dotfiles--`
- Ids: headless `session-<uuid>`, dsh-tui and ACP bare UUID; titles for TUI sessions in
	`~/.dsh-tui/session-index.json`
- `ls ~/.dsh/sessions/*/`, or `session/list` on ACP
- Reopen in the TUI: `dsh-tui --resume <id>` (interactive — tmux / herdr only)

## Cost

About 9-11k input tokens of base prompt per session, even for a 1-word answer. Batch related questions into 1 run, or
keep 1 ACP session so later turns hit the cache.
