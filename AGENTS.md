# AGENTS.md

## Severity levels

- **P1 (blocker)** - 머지 전에 반드시 수정해야 한다. PR을 블로킹한다.
- **P2 (should fix)** - 이번 PR에서 고치는 것을 권장한다. 블로킹하지는 않는다.
- **nit** - 사소한 스타일 제안. 고치지 않아도 머지 가능하다.

리뷰 코멘트 앞에 `[P1]`, `[P2]`, `[nit]` 접두사를 붙여서 심각도를 표시한다.

## Review guidelines

This file defines high-level rules that instruct Codex on how to review pull requests in this repository. Codex reads the closest `AGENTS.md` relative to each changed file and uses the rules defined here to determine which issues to prioritize. Adjust these guidelines to reflect your project's conventions.

- **Missing tests for new business logic** - [P1] 새로운 비즈니스 로직에 대응하는 테스트가 없으면 블로킹한다.
- **Null-safety regressions** - [P1] null-safe 프로젝트에서 null-safety를 깨뜨리는 코드는 블로킹한다.
- **Business logic inside widgets** - [P1] Flutter 위젯 클래스에 비즈니스 로직을 직접 넣으면 블로킹한다. 서비스나 프로바이더로 분리해야 한다.
- **Risky dependency additions** - [P2] 검증되지 않았거나 불필요한 패키지 추가는 지적한다.
- **Changes under `.github/**`** - [P1] CI/CD 설정 변경은 프로젝트 전체에 영향을 주므로 꼼꼼히 리뷰한다.
- **PR communication language** - write pull request titles, descriptions, and review comments in Korean by default. Keep code, file paths, workflow names, and shell commands in English when needed. Prefer concise labels such as `변경 사항`, `변경 이유`, `테스트`, `참고 사항`, and `리뷰 포인트` over question-style headings.
- **Review comment detail** - [P1/P2] 블로킹 또는 중요한 코멘트에는 무엇이 문제인지, 왜 중요한지, 어떤 방식으로 고칠 수 있는지를 함께 적는다. 근거 없는 한 줄 결론으로 끝내지 않는다.
- **Findings first** - findings를 전체 요약보다 먼저 적고, 파일/라인에 anchored된 코멘트를 우선한다. blocker와 suggestion의 성격이 다르면 톤과 심각도를 구분한다.
- **CI failure guidance** - `format`, `analyze`, `test` 등 실패한 체크와 연결된 코멘트에는 실패한 체크 이름과 로컬 재현 명령 또는 실패 형태를 함께 적는다.
- **Test guidance** - 테스트 보강을 요청할 때는 무엇이 아직 보호되지 않는지, 어떤 시나리오와 assertion이 빠졌는지 구체적으로 적는다.
- **Actionable scope** - 가능한 한 가장 작은 파일/라인 범위에 코멘트를 달고, 꼭 필요한 경우가 아니라면 큰 리라이트보다 실용적인 최소 수정 방향을 우선 제안한다.
