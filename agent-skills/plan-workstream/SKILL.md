---
name: plan-workstream
description: |
  Plan work too large for one agent session as a shared map of decision
  tickets on the issue tracker, resolved one per session until the route to
  the destination is clear. TRIGGER when the user brings a loose idea spanning
  many sessions, or asks to chart, resume, or work through a planning map.
  SKIP when the plan fits one session (use grill-plan or draft-tickets) or
  when the work is already specified and only needs decomposing (use
  draft-tickets).
disable-model-invocation: true
---

# Plan a workstream

A loose idea has arrived, too big for one agent session, and the way from here to the **destination** is not visible yet.
This skill charts the way as a **shared map** on the project's issue tracker, then works its **decision tickets** (questions whose resolution is a decision, not slices of a build) one at a time until the route is clear.

Naming the destination is the first act of charting: a spec to hand off, a decision to lock, or a change made in place.
The destination fixes the scope.

**Plan, don't do.**
Each ticket resolves a decision; the map is done when nothing is left to decide before someone goes and does the thing.
The pull to just do the work is usually the signal you have reached the edge of the map and it is time to hand off to draft-tickets and implementation.

**Refer by name.**
In everything the human reads, refer to tickets by title, never by bare id; the id and URL ride inside the name as a link.

## The map

The map is a single issue on the tracker, the canonical artifact; its tickets are child issues.
The map is an index, not a store: a decision lives in exactly one place, its ticket, and the map only gists and links it.
Detect the tracker the way draft-tickets does; with no tracker, keep the map and tickets as local markdown files in a scratch directory.

Map body:

```markdown
## Destination

What reaching the end of this map looks like. One or two lines; every
session orients to it before choosing a ticket.

## Notes

Domain context, skills every session should consult, standing preferences.

## Decisions so far

- [Closed ticket title](link): one-line gist of the answer.

## Not yet specified

In-scope fog you cannot ticket yet; graduates as the frontier advances.

## Out of scope

Work consciously ruled beyond the destination; never graduates.
```

Each ticket's body is one question, sized to a single agent session.
Blocking uses the tracker's native dependency relationship where one exists.
A session **claims** a ticket by assigning it before any work; an open, unassigned ticket is unclaimed.
The **frontier** is the open, unblocked, unclaimed tickets.

Ticket types: **research** (agent alone: read documentation or external sources to surface a fact a decision waits on), **prototype** (build a cheap concrete artifact to react to, via build-prototype), **grilling** (a conversation, via grill-plan; the default), and **task** (manual work that must happen before a decision can be made, done by agent or handed to the human as a checklist).
A ticket that needs the human only resolves through that live exchange; never stand in for the human's side of it.

## Fog of war

The map is deliberately incomplete: do not chart what you cannot yet see.
The test for fog versus ticket is whether you can state the question precisely now, not whether you can answer it now.
Sharp question: ticket, even if blocked.
Not sharp yet: a line in Not yet specified, coarser than a ticket; one patch may graduate into several tickets, or none.

Fog only gathers toward the destination.
Work beyond it is out of scope: when an existing ticket turns out to sit past the destination, close it and leave one line in Out of scope saying why, linking the closed ticket.

## Invocation

Two modes.
Either way, never resolve more than one ticket per session, except research tickets.

**Chart the map** (user brings a loose idea):

1. Name the destination via grill-plan. If grilling surfaces no fog (the whole journey fits one session), stop: no map needed.
2. Grill again breadth-first across the whole space, surfacing open decisions and first steps.
3. Create the map, then the tickets you can specify now; wire blocking edges in a second pass (issues need ids before they can reference each other). Everything else stays in Not yet specified.
4. Stop: charting is one session's work.

**Work through the map** (user brings a map reference, optionally a ticket):

1. Load the map, not every ticket body.
2. Choose the ticket: the user's, or the first frontier ticket. Claim it.
3. Resolve it, fetching related ticket bodies on demand.
4. Record the answer as a resolution comment, close the ticket, append a one-line gist to Decisions so far.
5. Create newly surfaced tickets, graduate fog the answer sharpened, rule mis-scoped tickets out of scope, and update or delete tickets the decision invalidated.

Expect other sessions to edit the tracker concurrently: the user may run unblocked tickets in parallel.
