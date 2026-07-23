# Architecture

## Three graphs

Research OS uses three related but independent graphs.

| Graph | Purpose | Owner | Typical nodes |
|---|---|---|---|
| Research graph | Explain why work exists and what evidence changes | Human owner + controller | goal, hypothesis, evidence, decision |
| Execution graph | Track active work, dependencies, validation, and routing | Controller | task, executor, artifact, gate |
| Version graph | Track file and code evolution | Git or jj | commit, change, branch |

An artifact links the execution graph to an immutable version reference. A research decision links validated evidence into memory.

## Control loop

The controller performs reconciliation:

```text
observe graph
  → find actionable or blocked nodes
  → evaluate authority, risk, and routing policy
  → bind an executor or request a human gate
  → collect artifacts
  → run validation
  → transition state
  → create memory candidates
```

The controller should be reconstructible from persisted project, graph, task, artifact, and audit records. Hidden chat context must not be required for recovery.

## Executor modes

| Mode | Use when | Example |
|---|---|---|
| `isolated_session` | Uncertainty, complexity, or risk is material | Hypothesis exploration, model development, architecture change |
| `controller_worker` | Scope is known, bounded, and low uncertainty | Small bug fix, documentation correction, deterministic update |
| `human_gate` | Authority cannot be delegated | Scientific decision, policy change, go/no-go |

Profiles describe behavior and capability. Runtimes such as Codex, Claude, Hermes, or local tools implement profiles.

## Validation

Review is modeled as a transition gate. It may be implemented by tests, CI, a review CLI, an independent agent, or a human. Medium- and high-risk work cannot rely only on executor self-review.

## Memory

Artifacts are not automatically knowledge. Promotion follows:

```text
raw → preliminary → reviewed → validated → adopted
                                           ↓
                                      deprecated
```

Maintenance normally enters an operational log. Research evidence and reusable capabilities may become memory after their required gates.
