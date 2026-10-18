---
name: tdd
description: Test-driven development loop — red, green, refactor. Use by default when implementing a new feature, fixing a bug, or handling an edge case in code. Not for config, docs, build/CI files, or other changes without testable behavior.
---

# Test-Driven Development

Repeat in small steps:

1. **Red** — write 1 failing test for the next smallest behavior. Run it; confirm it fails *for the expected reason*
2. **Green** — write the minimal code to pass. Run the test, then the surrounding suite
3. **Refactor** — clean up code and tests while everything stays green

Rules:

- Never write production code without a failing test demanding it
- Bug fix — first a test reproducing the bug, then the fix
- Do not weaken, skip or delete a test to get green; if the test is wrong, say so
- Cover corner cases: empty, boundary, error paths
- Follow the project's existing test layout and runner
