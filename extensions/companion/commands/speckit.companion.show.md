---
description: Show a visual question in the browser companion and record the choice it settles.
---

## User Input

```text
$ARGUMENTS
```

## When

Use the browser only when the user would understand the question better by seeing it than by reading
it: a layout, a mockup, an architecture or flow diagram, two visual directions side by side. A question
about a visual topic is not a visual question; requirements, trade-offs, scope and approach choices stay
in the terminal.

The first time such a question comes up in a session, offer the companion as a question of its own and
wait: it opens a browser tab and costs more tokens than text. If the user declines, stay in the terminal
and do not offer it again unless they ask.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Start

From the project root, with the platform's background mechanism if it reaps detached processes:

```text
pwsh -NoProfile -File .specify/extensions/companion/scripts/powershell/start-companion.ps1 -Open
```

It prints JSON with `url`, `screen_dir` and `state_dir`. Give the user the whole `url`, key included; the
server rejects requests without it. Before each later screen, check that `<state_dir>/server-info` exists
and `<state_dir>/server-stopped` does not. If it stopped, run the command again without `-Open`: the open
tab reconnects on the same port, and every later step uses the new `screen_dir` and `state_dir` it prints.

## Each screen

1. Write a new HTML file to `screen_dir` with your file tool, with a name that says what it asks
   (`layout.html`, `layout-v2.html`); never reuse a name. Write a fragment, not a full document: the server
   wraps it in a frame whose classes (`options`/`option`, `cards`/`card`, `mockup`, `split`, `pros-cons`,
   `mock-*`) are defined in
   `.specify/extensions/companion/scripts/companion/frame-template.html`. Clickable options carry
   `data-choice="<id>"` and `onclick="toggleSelect(this)"`; add `data-multiselect` to the container to allow
   several. State the question on the screen, two to four options, real content where it matters.
2. Tell the user, in the terminal, what the screen shows and that they can click and then reply there.
   End the turn.
3. On the next turn, read `<state_dir>/events` if it exists: one JSON line per click, last choice usually
   final. The user's terminal reply wins over the clicks where they differ.
4. Iterate with a new file, or move on. When the conversation returns to text, write a short
   `waiting.html` ("Continuing in the terminal") so the tab does not show a settled question.

## Record what it settled

A choice the user made in the browser is the user's decision, so it applies directly, a loosened outcome
included; say what it changed. It leaves the same trail as any other decision. The feature directory is
the one `.specify/feature.json` names.

- If it changes what the feature must do, write it into the spec as an outcome, constraint or edge case.
- If it is a design choice that is hard to reverse or likely to be re-litigated, add it to the plan's
  Choices with the options not taken as the rejected alternatives and why the user preferred this one.
  Before a plan exists, write it as a spec Constraint naming the options not taken; planning carries it
  into Choices.
- Copy the screen that settled it to `<feature directory>/design/<name>.html` and link it from where the
  choice is written. Session directories are not committed; this copy is the evidence.

Screens that settled nothing are not copied.

## Stop

When the visual questions are done:

```text
pwsh -NoProfile -File .specify/extensions/companion/scripts/powershell/stop-companion.ps1 -SessionDir <parent of state_dir>
```

The server also stops after four hours idle.
