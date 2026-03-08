# CRAN Compliance Guardrails

See the shared CRAN-COMPLIANCE-GUARDRAILS.md at the repository root.

Key rules for aboveR:
- `R CMD check --as-cran` must pass with 0 errors, 0 warnings
- All exported functions need `@returns` and `@examples`
- Network examples use `@examplesIf has_internet()`
- File writes in examples use `tempdir()`
- Suggested packages checked with `requireNamespace()`
