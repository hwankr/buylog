# buylog 📝

소비 기록 및 로그 관리 서비스 'buylog'입니다.

## 시작하기 (Setup)
1. Flutter SDK 설치 (Stable channel)
2. 레포지토리 클론: `git clone [url]`
3. `.env.example`을 `.env`로 복사하고 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 입력 (PowerShell: `Copy-Item .env.example .env`). 기존 `.env`가 있다면 덮어쓰지 말고 누락된 항목만 추가합니다.
4. 패키지 설치: `flutter pub get`
5. 실행 (Web): `flutter run -d chrome`

나머지 환경변수는 OCR 및 가격 비교 기능에 필요한 선택 설정입니다. 각 용도는 `.env.example`에 설명되어 있습니다. `.env`는 앱의 asset으로 포함되므로 배포용 비밀 키는 서버에서 관리해야 합니다.

## 프로젝트 구조
- `lib/main.dart`: 앱 진입점 및 메인 레이아웃
- `lib/widgets/`: 재사용 가능한 위젯 (예: GuessInput 등)
