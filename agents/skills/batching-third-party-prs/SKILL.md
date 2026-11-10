---
name: batching-third-party-prs
description: Absorb other people's PRs — typically red-by-design reproductions with failing tests — into 1 batch branch, fix each one TDD-style on its own head, and leave every absorbed PR shown as merged. Use when asked to "absorb", "batch" or "merge into the batch" someone else's PRs, or to fix a set of repro PRs together under 1 PR.
---

# Batching Third-Party PRs

## Why This Shape

1. **The PR ends merged, not closed:** a closed PR whose work landed elsewhere reads as rejected and frustrates the contributor
2. **Their commits stay theirs:** keeping the original commits and author respects the work and lets the contributor see it landed as written
3. **Fixes go onto the PR's own branch:** history stays traceable from reproduction to fix, the submitter sees how their report was resolved, and the fix survives on that branch even if the batch PR is lost
4. **The batch only fast-forwards:** nobody who already fetched it gets rewritten history, and every absorbed head stays reachable from it

Forges (GitHub, GitLab, Forgejo, ...) mark a PR merged when its current head becomes reachable from its current base. Everything below makes that true in the right order

## Scope

1. Absorb only the PRs the user named
2. A reproduction whose fix is still a design question stays out: mention it in the batch PR as related, with the reason, and do not fix it unasked

## Rules

1. Keep the original commits and authors; never squash or re-author them
2. Never force-push the batch; force-push a PR head only with a lease on the head you last saw
3. Repositories that require signed commits reject plumbing-built commits (`git replay`, `git commit-tree`): use `git cherry-pick -S`, which keeps the author and signs as committer
4. Do not disturb other people's uncommitted work in whatever checkout you use

## Per PR

1. **Check it is pushable:** the PR is open, and you can push to its head (a fork may forbid maintainer edits, see *Fallback*). Record its current head
2. **Retarget** it to the batch before the batch contains its head; otherwise the forge never sees it merged into its base
3. **Take only its own commits** onto the current batch tip. Commits already on the batch through shared ancestry are not duplicated. Conflict: stop and ask
4. **Fix it TDD-style**, see the next section
5. **Push the result to the PR head**, with a lease on the recorded head
6. **Wait until the forge shows the new head**, then a little longer so it recomputes the PR against its new base
7. **Fast-forward the batch** to that same commit. Rejected because the batch moved: rebuild from step 3 on the new tip
8. **Verify** the PR shows merged

## TDD on a Red-by-Design PR

The reproduction's failing test is the *Red* step someone already wrote; follow `skill://tdd` from there

1. **Confirm Red:** the reproduction's tests fail on the batch *for the reason the PR describes*, not because of a build break or a broken fixture. A test failing for the wrong reason is reported, not "fixed"
2. **Green:** minimal fix, 1 commit per behavior, on top of the contributor's commits; run their tests, then the surrounding suite
3. **Refactor** while green
4. **Self-review via a subagent** that has not seen your reasoning: the fix, corner cases, and sibling paths the reproduction missed, such as another encoding, another caller or the error path
5. **Every confirmed finding is a new Red:** a failing test first, then the fix, on this PR's head if it is the same issue, else on the batch alone
6. **Hooks:** if commit hooks run the whole suite, an intermediate commit may fail only because a later fix of the same PR is unwritten. Skip the test hooks on that commit alone and say so; the PR's last commit passes every hook
7. Never edit or delete the reproduction's test to get green; if it asserts the wrong thing, raise it with its author

## Parallelism

Fixing is independent per PR, integrating is not: each PR head must descend from the previous batch tip

1. Fan out: 1 subagent per PR runs *Per PR* steps 3–4 against the same batch tip, in isolation, and returns its fix commits
2. Sync point: integrate serially, in the user's order if they gave one — cherry-pick each PR's commits plus its fixes onto the current tip, rerun its tests, then steps 5–8
3. A fix that no longer applies or goes red after an earlier PR landed returns to TDD on the new tip

## Fallback

The head is not pushable: land the contributor's commits plus the fixes on the batch directly, close the PR with a comment linking the landed commits and thanking the author

## Batch PR

Update its description after every absorbed PR, so readers never see a stale list; when the next absorption is expected within about 5 minutes, 1 update after the last of them is enough:

1. Every issue resolved, including ones fixed along the way, not only the reproductions, using the tracker's closing syntax
2. Excluded reproductions and follow-ups as related, with the reason
3. The absorbed PRs and what each one showed
4. A title naming all outcomes, not just the first PR

Keep it a draft until the user says otherwise; never merge it

## Report

Per PR: merged state, contributor commits, fix commits, skipped hooks. Then the batch head and what is still red
