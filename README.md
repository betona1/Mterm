# 메디텀 (Mterm) — 리링과 함께하는 간호 의학용어 게임

VAVELING 의 리링 캐릭터가 간호사 옷을 입고 **약어 · 영어 철자 · 한국어 뜻**을 게임처럼 외우게 도와주는 앱.
Flutter 하나로 **PWA(웹)** 와 **안드로이드/iOS 네이티브** 를 모두 만든다.

## 게임 모드

| 모드 | 내용 | 비고 |
|---|---|---|
| 🧩 뜻 맞추기 | 용어 ↔ 뜻 4지선다 | 입문 |
| ✏️ 스펠링 | 뜻을 보고 글자 타일(또는 키보드)로 영어 철자 완성 | 힌트 한 글자 |
| 🔤 약어 정복 | 약어 → 풀네임 철자(1/2) + 뜻(2/2) 둘 다 맞혀야 정답. 가끔 용어 → 약어 쓰기 | 하드 모드면 뜻도 직접 입력 |
| 👑 완전 정복 | 위 유형 섞어서 15문제, 하트 3개 | 보스 |
| 🎯 만점 도전 | 틀린 문제가 뒤에 다시 붙어 **전부 맞힐 때까지** 계속 | 리스트업에서 「이 묶음 만점 도전」 |
| 📋 리스트업 · 자동 암기 | 10개씩(5~20) 쭉 보여 주고 2분(30초~5분)마다 자동으로 다음 묶음. 뜻/용어 가리기, 섞기, 화면 꺼짐 방지 | 태블릿은 자동 넘김이 기본 ON |
| 🔁 복습 / 🩹 틀린 문제 | 라이트너 간격 반복(0·1·2·4·7·15일)으로 때가 된 용어 | 홈에 개수 표시 |
| 🃏 플래시카드 | 카드 뒤집기, 알아요/모르겠어요 | 기록은 가볍게 |

**태블릿**(짧은 변 600dp 이상)은 왼쪽 레일 + 2단 홈(마스코트·목표 / 학습), 리스트업은 2~3열.

경험치 → 레벨(간호학과 새내기 → … → 간호 마스터), 콤보, 하루 목표·연속일, 배지 12종.
학습 기록은 기기 안(SharedPreferences)에만 저장된다.

## 폴더

```
assets/data/terms.json        용어 사전 (생성물 — 직접 고치지 말 것)
assets/images/mascot/         리링 간호사 (tools/make_icon.py 생성물)
assets/images/characters/     VAVELING 친구 8명 (분류별 안내 캐릭터)
assets/sounds/                효과음 (VAVELING)
tools/seed_terms.py           기본 용어 563개 (여기를 고친다)
tools/pdf_to_terms.py         PDF 용어집 → terms.json 합치기
tools/make_icon.py            리링 + 간호사 모자·청진기 합성 → 아이콘/마스코트
tools/make_sfx.py             부드러운 효과음 합성 (벨+패드, 저역 통과, 잔향) → assets/sounds
data/pdf/                     PDF 용어집을 여기에 넣는다
lib/
  core/      테마 · 효과음 · 캐릭터 · AppScope
  data/      Term 모델 · TermRepo · Progress(진행도·SRS·배지)
  game/      QuizEngine(문제 생성) · QuizScreen · LetterTiles · ResultScreen
  screens/   홈(폰/태블릿) · 사전 · 통계 · 설정 · 플래시카드 · 리스트업(list_study_screen)
```

## PDF 용어집 넣기

```bash
# 1) PDF 를 data/pdf/ 에 넣고 미리보기 (검토용 CSV 가 data/pdf/review_<이름>.csv 로 생긴다)
python tools/pdf_to_terms.py data/pdf/용어집.pdf

# 2) CSV 를 열어 틀린 줄을 고친 뒤 반영
python tools/pdf_to_terms.py data/pdf/review_용어집.csv --apply

# (PDF 가 깔끔하면 바로)  python tools/pdf_to_terms.py data/pdf/용어집.pdf --apply
# 분류를 못 맞추면       --cat rx   처럼 강제
```

기본 용어(`seed_terms.py`)와 같은 용어는 PDF 쪽이 덮어쓴다. 반영 뒤 `flutter test` 로 약어 중복을 확인한다.

## 빌드

```bash
flutter pub get
flutter test                          # 판정 규칙 + terms.json 무결성
flutter build web --release           # PWA → build/web  (아무 정적 호스팅에 올리면 설치형 앱)
flutter build apk --release           # 안드로이드
flutter install -d <기기ID>           # 연결된 폰에 설치
dart run flutter_launcher_icons       # 아이콘을 바꿨을 때
```

## 정답 판정 규칙

- 영어(철자·약어): 대소문자·공백·하이픈·아포스트로피 무시. `termAlts`/`abbrAlts` 에 적은 대체 표기도 정답.
- 한국어 뜻(하드 모드): 쉼표·슬래시로 나뉜 후보 중 하나와 같거나, 두 글자 이상이면서 서로 포함하면 정답.
- 약어가 같은 용어가 둘이면 「약어 → 용어」 문제가 애매해지므로 테스트가 막는다. 한쪽 약어를 비우거나 다른 표기로 바꾼다.
