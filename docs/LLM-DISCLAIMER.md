# LLM disclaimer

Coding agents built this repository: the spec, the package, the scripts,
the tests and this text. They are [Claude Code](https://claude.com/claude-code)
sessions running Anthropic's Claude Opus 5.5, working under the
[paradigm](https://github.com/pr0d1r2/paradigm) process and its gate. A
human owns the intent, answers the open questions, reviews the work and
approves every outward act, such as creating the GitHub repository, the
first push, a cache token or a release. Everything else has to get past a
gate that refuses: the steps in [`hk.pkl`](../hk.pkl), generated from
[`.pklith`](../.pklith).

Every commit the agents wrote carries a `Co-Authored-By: Claude Opus 5.5`
trailer, so `git log` shows which ones they are.

## Before trusting anything here

- Read the spec, [`SPEC.md`](../SPEC.md), as the law. The pages, this one
  included, explain it and can lag behind it.
- Treat a number as true on the date written beside it, and no later.
  Versions, sizes and hashes in the spec were measured on the date given,
  with the command named.
- Decisions the agents made on their own are marked in the spec as agent
  decisions, with a date, and wait for the owner's review. As of
  2026-10-24 those are: the non-AVX2 build as a second package, the
  package licence, and keeping upstream's log shipping on by default.
- Check what the spec says is not measured yet before relying on it. As
  of 2026-10-24 that includes the Linux and Intel Mac builds.

If something here does not match what you see, believe what you see and
open an issue.

## Defect record

This is the public record of defects found after the gate was green:
each one is a bug the gate did not catch at the time, with the rule added
so it cannot recur. The record is the bug log, section §B of
[`SPEC.md`](../SPEC.md) and of each node's `SPEC.md`; this page does not
copy it, so it cannot fall out of date.

As of 2026-10-24 no bug log, root or node, has an entry yet. For the current state,
and for any count, see [`SPEC.md`](../SPEC.md) §B.
