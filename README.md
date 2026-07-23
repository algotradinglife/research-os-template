# Research OS Template

A domain-neutral operating template for AI-assisted research teams.

Research OS separates four concerns:

1. **Intent** — a human research owner defines goals, hypotheses, and decision criteria.
2. **Control** — a controller observes the task graph, evaluates policy, and selects the next action.
3. **Execution** — isolated sessions or bounded controller workers produce artifacts.
4. **Memory** — validated evidence, decisions, methods, and failures become reusable knowledge.

The template is designed for biomedical research, quantitative trading, sports probability research, and other evidence-driven domains.

## Operating model

```mermaid
flowchart TD
    PI["Human Research Owner<br/>goal · hypothesis · decision"] --> G["Research Graph<br/>question · task · evidence · decision"]
    G --> H["Controller<br/>observe · route · reconcile"]
    H --> R["Isolated Session<br/>research / engineering"]
    H --> W["Controller Worker<br/>bounded routine work"]
    R --> V["Validation Gate<br/>tests · CI · review · human gate"]
    W --> V
    V --> G
    V --> M["Research Memory<br/>evidence · decision · method · failure"]
    R -. artifact reference .-> VC["Version Graph<br/>Git default · jj optional"]
    W -. artifact reference .-> VC
```

The research graph is the source of truth for **why and what happens next**. Git or jj records **how files changed**. They are linked through artifact references but are not interchangeable.

## Repository map

```text
kernel/
  system.yaml                    Governance and authority boundaries
  schemas/                       Project, graph, task, and memory contracts
  workflows/state-machine.yaml   Shared lifecycle and transitions
  policies/                      Routing, validation, and memory promotion
  profiles/agent-profiles.yaml   Runtime-neutral execution profiles
  adapters/version-control.yaml  Git default and optional jj mapping
template/                        Copyable project starter
examples/
  pa-research/                   Complete pilot loop
  fmt-research/                  Biomedical domain instance
  beijing-lot-research/          Sports probability domain instance
docs/                            Architecture and pilot guidance
scripts/validate.rb              Dependency-free structural validation
```

## Quick start

```bash
git clone https://github.com/algotradinglife/research-os-template.git
cd research-os-template
make validate
```

To start a project, copy `template/`, then:

1. Complete `project.yaml`.
2. Define the initial nodes and edges in `graph.yaml`.
3. Create one task file per executable node.
4. Let the controller choose an executor mode from policy.
5. Require artifacts and validation before state transitions.
6. Promote only accepted outputs into memory.

See [Pilot guide](docs/pilot-guide.md) for a complete manual-first rollout.

## Core invariants

- Human owners retain final authority over hypotheses and consequential conclusions.
- The controller may route and reconcile work but may not silently change intent or acceptance criteria.
- Executor output is unverified until a validation gate passes.
- Research completion and engineering completion are separate.
- Negative and inconclusive results are valid research outcomes.
- Chat history is an interface, not the system of record.
- Sensitive data is referenced by controlled pointers and hashes, not committed by default.

## Validation

`make validate` checks YAML parsing, state transitions, routing references, graph integrity, and required fields in example instances. CI runs the same command.

## Status

`v0.1` is intentionally a manual-first template. Validate it with real projects before building a persistent controller or packaging it as a skill.

## License

MIT
