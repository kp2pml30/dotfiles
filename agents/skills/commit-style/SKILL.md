---
name: commit-style
description: Conventional commit message style. Use when writing a commit message, squashing/merging a PR, or amending history. Covers the `type(scope): summary <emoji>` format, the five types, scope guidance, the gitmoji suffix, and mistakes to avoid.
---

# Writing commit messages

Format:

```text
type(scope): short imperative summary <emoji…>
```

- **type** — one of five, lowercase (required).
- **(scope)** — the subsystem the change touches. Optional, but **aim for ~80%**
  of commits to carry one; omit only for genuinely repo-wide changes.
- **summary** — lowercase, imperative or noun-phrase, no trailing period, ≲70 chars.
- **\<emoji…>** — **one to three** trailing [gitmoji](https://gitmoji.dev) glyphs
  marking the precise intent. Use the actual Unicode emoji, not the `:shortcode:`.
  Most commits want exactly one; reach for a second or third only when the change
  genuinely carries more than one intent (e.g. a security fix that is also a
  refactor → `🔒️♻️`). Order them most-important first. Never more than three.

Examples:

```text
feat(auth): add refresh-token rotation ✨
fix(api): reject negative page sizes 🐛
perf(parser): avoid recompiling regex per call ⚡
chore(ci): fix cache key 💚
chore(deps): bump tokio ⬆️
docs(readme): document env vars 📝
```

## Types

The **type** is the coarse group; the **emoji** carries the fine intent.

| Type    | Use for                                        | Default emoji |
|---------|------------------------------------------------|---------------|
| `feat`  | new caller-visible capability or API surface   | ✨            |
| `fix`   | broken behavior corrected                      | 🐛            |
| `perf`  | same behavior, faster or smaller               | ⚡            |
| `docs`  | documentation only                             | 📝            |
| `chore` | everything internal (incl. refactors)          | see below     |

Picking between the blurry ones:
- New behavior a caller can observe → `feat`. Correcting wrong behavior → `fix`.
  Same behavior but cheaper → `perf`. Pure restructure → `chore` + ♻️.

## Emoji by intent

Pick the glyph that best names *what kind* of change it is — it can be finer than
the type. Common ones:

| Emoji | Meaning                  | Emoji | Meaning                |
|-------|--------------------------|-------|------------------------|
| ✨    | new feature              | ♻️    | refactor               |
| 🐛    | bug fix                  | 🔥    | remove code / files    |
| 🚑    | critical hotfix          | 🎨    | structure / format     |
| ⚡    | performance              | ✅    | tests                  |
| 📝    | docs                     | 💚    | fix CI                 |
| 🔧    | config                   | 🚀    | release / deploy       |
| ⬆️/⬇️ | bump / drop deps         | 🔒️    | security / privacy     |
| 🚚    | move / rename            | 🔇    | remove logs            |
| 🏗️    | architectural change     | 🔨    | dev / build scripts    |
| 🚧    | work in progress         |       |                        |

Full reference: https://gitmoji.dev

When a fix hardens behavior against malicious or malformed input, mark it 🔒️
(alone, or paired with 🐛/⚡ when it is also a bugfix or optimization).

## Scopes

The scope names the subsystem the change touches — a directory, module, or
component (`auth`, `api`, `parser`, `ci`, `deps`, `build`). Keep them lowercase and
reuse the same word for the same area across commits, so the set stays small and
predictable. Prefer an existing scope when it fits; invent a new one only for a
genuinely new area.

## Body — keep it rare

Prefer a single line. The summary should carry the change on its own; if you're
reaching for a body to explain *what* changed, tighten the subject instead.

Add a body **only** when a reader genuinely cannot reconstruct the *why* from the
diff — a non-obvious tradeoff, a workaround for an external bug, or a subtle
invariant. When you do, write one or two sentences of motivation, not a recap of
the diff and not a bullet list of squashed sub-commits.

## Mistakes to avoid

1. **Numbered firefighting** — `fix CI`, `fix CI 2` … `fix CI 5`. Say *what*
   broke: `chore(ci): fix cache key 💚`. A numbered run means the messages
   describe nothing.
2. **`batch update (#NNN)`** with no theme. A merged PR still deserves a one-line
   summary of what it does.
3. **Typos** — spell-check the subject; it is permanent.
4. **`fix tests`** with no cause. Add it: `chore(api): fix tests after rebase ✅`.

## Checklist

- [ ] Right type (feat / fix / perf / docs / chore)?
- [ ] Scope present (target ~80%) and reused consistently?
- [ ] Lowercase, no period, ≲70 chars?
- [ ] One to three trailing gitmoji glyphs (most-important first) matching the intent?
- [ ] Single line — body only if the *why* is truly unrecoverable from the diff?
- [ ] Spell-checked?
