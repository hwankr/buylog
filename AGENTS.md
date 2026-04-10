# AGENTS.md

## Review guidelines

This file defines high-level rules that instruct Codex on how to review pull requests in this repository.  Codex reads the closest `AGENTS.md` relative to each changed file and uses the rules defined here to determine which issues to prioritize.  Adjust these guidelines to reflect your project's conventions.

- **Missing tests for new business logic** – mark as P1 and block the PR if new logic is introduced without corresponding tests.  Tests ensure changes are verifiable and lower the risk of regressions.
- **Null‑safety regressions** – flag and block any code that reintroduces null‑safety risks in a null‑safe Flutter project.  All Dart code should remain fully null‑safe.
- **Business logic inside widgets** – flag and block PRs that embed business logic directly in Flutter widget classes.  Prefer separating state management and logic into services or providers.
- **Risky dependency additions** – flag new packages that are not vetted or necessary.  Avoid adding large dependencies without discussion.
- **Changes under `.github/**`** – treat modifications to GitHub Actions workflows and configuration as high priority (P1).  Changing CI/CD configuration can impact the whole project and should be reviewed carefully.