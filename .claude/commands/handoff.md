---
description: Update docs/SESSION_HANDOFF.md with this session's work
---

Update `docs/SESSION_HANDOFF.md` so the next person (or the next session) can pick up cold.

## Keep the existing shape

The file already has a working structure. Preserve it:

- **TL;DR — where we are** (3–5 lines, no more)
- **Done & verified** — only things actually verified, with how they were verified
- **Known flags / gotchas** — live traps, each with `file:line`
- **Blocked on data / Cody (critical path)** — numbered
- **Resume here (prioritized)** — numbered, most important first

## Rules

1. **"Verified" means verified.** If it was run and the output checked, say what the output was
   (a number, a row count, a diff). If it was only written and parsed, say that instead. Never
   promote "wrote the code" to "verified it works".
2. **Move resolved items out of Blocked**, and mark them `RESOLVED (<date>)` in Done — the file's
   existing convention. Don't delete the history; a resolved blocker explains why something
   changed.
3. **Absolute dates, not relative.** "2026-08-21", never "last week".
4. **Prune.** This is a pickup doc, not a log. If a Done item is now permanently true and
   documented in `README.md` or `CLAUDE.md`, cut it and point there.
5. Cleanup debt discovered but not fixed goes to `docs/CLEANUP_BACKLOG.md`, not here.

## Then

Show the diff and summarize what changed in two or three lines. Don't commit unless asked.
