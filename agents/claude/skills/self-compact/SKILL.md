---
name: self-compact
description: Compact your own Claude Code conversation and resume automatically afterwards. Use when asked to self-compact, or when context is running out at a natural checkpoint of long autonomous work and the task must keep going without the user. Requires a Herdr pane (HERDR_ENV=1).
---

# Self-Compact

Runs `/compact` on this conversation once the current turn ends, then submits a follow-up message so work resumes without the user.

1. Pick a checkpoint: no background work or subagents you are waiting on
2. Write anything the summary must not lose (plan, next steps, exact commands) to a file under `.local`
3. Run the script as the **last tool call** of the turn:

	```bash
	~/.claude/bin/claude-self-compact.sh --continue "Continue with <next step>; plan is in .local/<file>" "Keep <what matters> in the summary"
	```

4. End the turn immediately, in 1 short line. The script waits for the turn to end; it gives up after 5 minutes

Arguments, both optional and limited to about 500 characters, newlines become spaces:

- `--continue MESSAGE`: the message that resumes you. Must be plain text, not starting with `/` or `!`
- Remaining arguments: instructions for `/compact`

If the script exits non-zero, it scheduled nothing new. When it reports one already pending, end the turn as in step 4. Otherwise tell the user and carry on without compacting.

The script does not type over the user. It sends a Herdr notification and stops if the input box holds a draft or a dialog is open, the agent is busy after compaction, or compaction did not finish within 15 minutes. Log: `~/.cache/claude-self-compact.log`.
