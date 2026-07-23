# Contributing

Research OS changes should preserve domain neutrality and explicit control boundaries.

## Change checklist

- Keep scientific or strategic authority separate from execution authority.
- Model reviewer behavior as a validation gate, not necessarily a permanent agent.
- Keep the research graph independent from Git, jj, or any specific runtime.
- Add or update an example when changing a schema or policy.
- Run `make validate` before committing.

## Versioning

Breaking schema changes require a new `api_version`. Backward-compatible fields may be added within the current version.
