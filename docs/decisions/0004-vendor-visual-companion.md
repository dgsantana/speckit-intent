# 0004. Vendor the Superpowers visual companion

Status: active
Date: 2026-10-06

## Intent

A question that is clearer shown than described (layout, diagram, visual options) can be answered in a
browser tab during `specify`, `clarify` or `plan`, and the choice leaves the same trail in the spec or
plan as any other decision.

## Decision

The `companion` extension carries Superpowers 6.4.1's `server.cjs`, `helper.js` and
`frame-template.html` (MIT, attributed in `extensions/companion/NOTICE`) with one change: the page shows
a text attribution instead of loading a logo from primeradiant.com. The bash launchers are replaced by
`start-companion.ps1` and `stop-companion.ps1`. The command tells the agent to record a settled choice in
the spec or the plan's Choices, with the options not taken as rejected alternatives, and to copy the
deciding screen into `<feature>/design/`. Session files stay out of git.

## Rejected

- Depend on an installed Superpowers plugin: no code to own, but tied to its layout and version, absent
  for users without it, and it brings the remote logo request.
- Write a smaller server: less code to own, but new and untested where upstream's handles session keys,
  reconnects and process cleanup already.
- Adopt Superpowers' brainstorming workflow as well: its approval gates and design documents carry no
  decision trail and add the process weight the preset removes.

## Evidence

- **documented**: upstream `server.cjs` uses only Node built-ins (`http`, `fs`, `crypto`, `path`).
- **measured**: upstream `server.cjs:106,247` loads `primeradiant.com/brand/...png?v=<version>` unless a
  telemetry opt-out variable is set.
- **measured**: on Windows, starting the server with redirected output let it inherit the caller's
  stdout pipe, so a caller capturing the launcher's output never returned. `tests/companion.Tests.ps1`
  fails on that launcher and passes on the current one (2026-10-06).

## Revisit when

Superpowers ships a fix that matters for security or reconnection (diff the three files and reapply the
NOTICE change), or Node.js stops being an acceptable runtime dependency for users of this preset.
