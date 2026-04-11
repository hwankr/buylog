# AGENTS.md

## Severity levels

- **P1 (blocker)** – 머지 전에 반드시 수정해야 한다. PR을 블로킹한다.
- **P2 (should fix)** – 이번 PR에서 고치는 것을 권장한다. 블로킹하지는 않는다.
- **nit** – 사소한 스타일 제안. 고치지 않아도 머지 가능하다.

리뷰 코멘트 앞에 `[P1]`, `[P2]`, `[nit]` 접두사를 붙여서 심각도를 표시한다.

## Review guidelines

This file defines high-level rules that instruct Codex on how to review pull requests in this repository. Codex reads the closest `AGENTS.md` relative to each changed file and uses the rules defined here to determine which issues to prioritize. Adjust these guidelines to reflect your project's conventions.

- **Missing tests for new business logic** – [P1] 새로운 비즈니스 로직에 대응하는 테스트가 없으면 블로킹한다.
- **Null-safety regressions** – [P1] null-safe 프로젝트에서 null-safety를 깨뜨리는 코드는 블로킹한다.
- **Business logic inside widgets** – [P1] Flutter 위젯 클래스에 비즈니스 로직을 직접 넣으면 블로킹한다. 서비스나 프로바이더로 분리해야 한다.
- **Risky dependency additions** – [P2] 검증되지 않았거나 불필요한 패키지 추가는 지적한다.
- **Changes under `.github/**`** – [P1] CI/CD 설정 변경은 프로젝트 전체에 영향을 주므로 꼼꼼히 리뷰한다.
- **PR communication language** – write pull request titles, descriptions, and review comments in Korean by default. Keep code, file paths, workflow names, and shell commands in English when needed. Prefer concise labels such as `변경 사항`, `변경 이유`, `테스트`, `참고 사항`, and `리뷰 포인트` over question-style headings.
