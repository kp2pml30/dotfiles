# Proposals / Research / Thinking

When asked to propose, research, or think — not implement:

1. Edit nothing
2. Answer in one titled line or mini paragraph each (include only needed ones)
	- size of change: approximate lines / files / effort / time
	- proposal: solution in short
	- not solved: what part of the request is solved and what is not; sharp edges you see. Put explicit *none* if none

# Code

1. Write idiomatic code. If something looks bad — mine or yours — say so
2. Self-review nontrivial changes via a subagent, so they do not inherit your assumptions
3. Exception to both points above: if I said we're doing sticks and glue for speed, skip the polish
4. No sweeping under the rag is allowed: corner cases matter
5. NEVER use crazy python scripts where regular edit or apply patch tool would have worked

# Comments

1. Be in style with file, do not add a first doc comment
2. Minimize comments, most of them do not deserve more than one line
3. They must reflect current state. Change reason goes to PR / commit / changelog / whatever

# Background / Long-Running Tasks

1. Before waiting on background work, say in one sentence what we're waiting for and why
2. Never make logs irretrievable — e.g. tee to a file instead of bare tail
3. While waiting for commands, wake at least every 15 minutes no matter what (e.g. background `sleep 900` and monitor
	its exit); check the task isn't hung, failed, or the waiter misconfigured. However, we trust Claude agents and that
	they won't hang

# Organizing Internal Data

Prefer to write local data, such as todo for next session, agents info, etc under `.local`. It is globally git ignored

# Environment

1. Assume you are working not alone: never run `git checkout`, `git switch`, `git stash`, `git reset`, or anything else that discards or
	others work tree unless I asked for it
2. Same for creating/deleting branches and rewriting history: ask first
3. Some build may be `oom` killed, especially `rustc`, just retry if that is the case

# Committing

1. You never include co-authored-by: AI name or session URLs / etc into a commit
2. In future I will provide you your own mail address and git account

# Running Commands

1. If you run a long running command, i.e. tests, never do a bare `tail`. Always do `tee $TMPDIR/testrun.rnd | tail`
2. If tests failed, before rerunning them all firstly rerun only failed ones
