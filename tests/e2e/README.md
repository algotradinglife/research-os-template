# Minimal controller E2E

This scenario verifies the Research OS control contract through its public CLI:

```bash
ruby scripts/e2e.rb tests/e2e/minimal-research
```

The automated test copies the fixture to a temporary directory before invoking the runner, so repository fixtures remain unchanged.

## Scenario

```text
CREATED
→ PLANNING
→ READY
→ EXECUTING
→ VALIDATING
→ AWAITING_DECISION
→ COMPLETED
→ reviewed Memory Candidate
```

The executor, independent validator, and research-owner decision are deterministic local fixtures. No real agent, network, or Git worktree is used.

## Behaviors under test

- Research with high uncertainty routes to `isolated_session + researcher`.
- Required artifacts must exist before validation.
- Medium-risk work requires independent validation.
- Missing human decisions stop at `AWAITING_DECISION` with exit status `2`.
- Every state transition is written to the audit log.
- Task and graph state remain consistent.
- An `inconclusive` decision still generates a reviewed memory candidate.

## Scope

This is a reference implementation of one controller loop. It is intentionally not:

- a persistent Hermes controller;
- a real Codex or Claude launcher;
- a Git branch/worktree manager;
- a general workflow engine.
