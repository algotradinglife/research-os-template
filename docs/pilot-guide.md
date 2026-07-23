# Pilot guide

Run the first project manually before automating the controller.

## Recommended pilot size

- One research goal
- One initial hypothesis
- Three to five executable task nodes
- One or two isolated sessions
- One human decision gate
- One memory record

The `examples/pa-research` project is the reference pilot.

## Cycle

1. **Define intent** — freeze the question, hypothesis, exclusions, and decision criteria.
2. **Create graph** — link the goal to one bounded task and planned evidence.
3. **Route** — apply policy to choose an isolated session, controller worker, or human gate.
4. **Execute** — provide a versioned context package, not the entire chat history.
5. **Register artifacts** — include immutable revision, path, hash, inputs, and producer.
6. **Validate** — run checks proportional to risk.
7. **Decide** — record supported, partially supported, refuted, inconclusive, or more evidence required.
8. **Promote memory** — preserve scope, provenance, limitations, and review date.
9. **Create the next node** — continue only when the decision justifies it.

## Success criteria

The pilot succeeds if:

- A new operator can reconstruct why the decision was made.
- The analysis can be rerun from recorded inputs and revisions.
- Negative or inconclusive output remains useful and discoverable.
- The controller can recover current state without hidden chat history.
- The same kernel can represent a second domain without schema changes.

## Automation sequence

| Phase | Form | Automate |
|---|---|---|
| 1 | Manual template | Routing decisions and state updates are human-supervised |
| 2 | Controller skill | Parse config, propose transitions, prepare context packages |
| 3 | Persistent controller | Observe repositories, launch runtimes, reconcile state |

Do not build phase 3 until at least two domain pilots complete without changing the kernel's core abstractions.
