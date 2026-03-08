# Coding Standards — aboveR

- R >= 4.1.0 (native pipe `|>` is OK)
- roxygen2 with markdown for all documentation
- Google-style function docs: Title, Description, @param, @returns, @examples
- testthat edition 3, `test_that()` with descriptive strings
- `cli::cli_abort()` for user-facing errors (if cli is imported)
- `rlang::abort()` or `stop()` for internal errors
- No `library()` or `require()` inside package code — use `::` or `requireNamespace()`
- `withr::local_tempdir()` for temp files in tests
