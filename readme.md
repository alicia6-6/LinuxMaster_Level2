# 리눅스마스터 2급 필기 기출문제 학습 사이트

정적 HTML/CSS/JS로 만든 기출문제 학습 사이트입니다. 빌드 과정 없이 GitHub Pages에 그대로 올려서 사용할 수 있습니다.

🔗 **사이트 바로가기**: https://alicia6-6.github.io/LinuxMaster_Level2/index.html

## 기능

- **회차별 모의시험** (`quiz.html?mode=round`) — 회차를 골라 100분 타이머 + 문제 이동 맵으로 실전처럼 응시, 제출 후 점수·정답률·오답 리뷰 제공
- **랜덤 문제** (`quiz.html?mode=random`) — 전체 문제 중 한 문제씩 무작위로 가볍게 학습
- **빈출문제** (`quiz.html?mode=frequent`) — 여러 회차에서 동일하게 반복 출제된 문제를 자동으로 모아서 학습 (`data/questions.json`의 문제 텍스트를 비교해 자동 계산)
- **오답노트** (`quiz.html?mode=wrong`) — 틀린 문제를 브라우저(localStorage)에 자동 저장, 맞히면 자동 제거
- **요약노트** (`summary.html`) — 리눅스 운영·관리부터 네트워크 서비스까지 시험 범위 핵심 개념 정리

## 폴더 구조

```
index.html          홈 (메뉴, 통계)
quiz.html            문제 풀이 화면 (mode 파라미터로 4가지 모드 분기)
summary.html         요약노트
css/style.css        공통 스타일 (라이트/다크 모드 자동 대응)
js/data.js           문제 데이터 로딩, 빈출문제 계산, 오답노트 저장 유틸
js/quiz.js           문제 풀이 화면 로직
js/summary-footnotes.js  요약노트 표 가로 스크롤 처리
data/questions.json  기출문제 데이터 (아래 스키마 참고)
data/images/         문제에 딸린 원본 캡처 이미지
```

## 문제 데이터 스키마 (`data/questions.json`)

```json
{
  "meta": { "examName": "리눅스마스터 2급 필기", "totalRounds": 12, "totalQuestions": 960 },
  "questions": [
    {
      "id": "2020-06-13-01",
      "round": "2020년 06월 13일",
      "number": 1,
      "subject": "리눅스 운영 및 관리",
      "question": "문제 지문",
      "choices": ["보기1", "보기2", "보기3", "보기4"],
      "answer": 2,
      "explanation": "정답 해설",
      "image": "data/images/2020-06-13/q01.gif",
      "tags": []
    }
  ]
}
```

- `answer`는 1~4의 정답 보기 번호(①②③④ 기준)입니다.
- `round`는 실제 시행일(예: "2020년 06월 13일")을 그대로 표기하며, 회차별 모의시험 화면의 드롭다운/필터에 그대로 사용됩니다.
- 빈출문제는 문제 및 지문(imageText) 유사도와 정답 일치 여부를 종합 분석해 서로 다른 회차에서 2회 이상 출제된 핵심 문제를 자동으로 추출합니다.
- `image`는 문제에 캡처 화면(터미널 출력, 다이어그램 등)이 딸려 있을 때 상대 경로를 넣습니다. 없으면 `null`.
- `subject`는 원본 문서의 과목 구분을 그대로 따른 것으로, 1과목 "리눅스 운영 및 관리"(1~48번) · 2과목 "리눅스 활용"(49~80번) 2과목 체계입니다.

## 로컬에서 확인하기

정적 파일이라 아무 서버로나 띄우면 됩니다. 예:

```bash
python -m http.server 8000
# http://localhost:8000 접속
```

`fetch`로 JSON을 불러오기 때문에 `index.html`을 파일로 직접 더블클릭해서 열면 동작하지 않습니다(반드시 로컬 서버 경유).

## GitHub Pages 배포

1. GitHub에 새 저장소를 만들고 이 폴더 내용을 push
2. 저장소 Settings → Pages → Source를 `main` 브랜치 `/ (root)`로 설정
3. 잠시 후 `https://<사용자명>.github.io/<저장소명>/` 에서 접속 가능

별도 빌드 스텝이 없으므로 push만 하면 바로 반영됩니다.

현재 배포 주소: https://alicia6-6.github.io/LinuxMaster_Level2/index.html
