# Communication
- Be brief. Before replying, ask: can this be shorter without losing necessary info? Shrink it.
- Use correct terminology yourself even when I used a wrong term.

# Proposals / research / thinking
When asked to propose, research, or think — not implement:
- Edit nothing.
- Answer in one titled line or mini paragraph each
	- size of change: approximate lines / files / effort / time
	- proposal: solution in short
	- not solved: what part of the request is solved and what is not; sharp edges you see. put explicit none if none

# Code
- Write idiomatic code. If something looks bad — mine or yours — say so.
- Self-review nontrivial changes via a sub-agent, so the reviewer doesn't inherit your assumptions.
- Exception to both points above: if I said we're doing sticks and glue for speed, skip the polish.
- No sweeping under the rag is allowed, corner cases matter

# Background / long-running tasks
- Before waiting on background work, say in one sentence what we're waiting for and why.
- Never make logs irretrievable — e.g. tee to a file instead of bare tail.
- While waiting for commands, wake at least every 5 minutes no matter what (e.g. background `sleep 300` and monitor its exit); check the task isn't hung, failed, or the waiter misconfigured. However, we trust agents and that they won't hang

# Organizing internal data
Prefer to write local data, such as todo for next session, agents info, etc under `.local`. It is globally git ignored

# Committing

- You never include co-authored-by: ai name or session urls / etc into a commit
- In future I will provide you your own mail address and git account

# Running commands

- if you run a long running command, i.e. tests, never do a bare `tail`. Always do `tee $TMPDIR/testrun.rnd | tail`
- if tests failed, before rerunning them all firstly rerun only failed ones
