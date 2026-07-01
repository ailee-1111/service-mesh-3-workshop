# Service Mesh 3.0 Workshop 개발 및 작법 가이드라인 (ServiceMesh3/GEMINI.md)

본 문서는 `ServiceMesh3` 디렉토리 하위에서 실습 가이드북(마크다운) 및 Homeroom 배포 자산을 개발할 때 AI 에이전트와 엔지니어가 반드시 준수해야 하는 공통 설계 및 서식 표준입니다.

---

## 1. 가이드북 마크다운 서식 및 헤더 폰트 크기 강제 표준

### 🚨 헤더(#, ##, ###) 폰트 오버사이징 방지 규칙 (필수 반영)
오픈시프트 Homeroom/butterfly 대시보드 렌더러 상에서 기본 마크다운 제목(#, ##, ###) 폰트가 과하게 비대하게 출력되어 가독성을 심하게 해치는 현상이 존재합니다.
이 문제를 영구히 해결하기 위해, **본 서브디렉토리 하위의 모든 마크다운 파일(신규 작성 포함) 최상단에는 반드시 아래의 CSS `<style>` 블록을 고정 삽입**해야 합니다.

```html
<style>
  h1 { font-size: 24px !important; }
  h2 { font-size: 20px !important; }
  h3 { font-size: 16px !important; }
</style>
```

### 📝 실습 커맨드 및 실행 결과 서식 규칙
1. **명령어 수행 블록 (`execute`):** 가이드북에서 터미널을 통해 실질적으로 실행해야 하는 모든 명령어(예: `oc login`, `traffic_gen.py` 등)는 반드시 ` ```execute` 블록으로 작성해야 합니다.
2. **실행 결과 및 로그 블록 (`bash`):** 명령을 수행한 결과 출력 데이터, 로그는 훼손 및 추가 없이 ` ```bash` 블록을 활용하여 명시합니다.
3. **참고/주의 상자 (`Note/Important`):**
   * **Note:** `> [!NOTE]` 접두어 및 한글 `> **참고 (NOTE)**` 볼드체를 함께 사용해 박스화합니다.
   * **Important:** `> [!IMPORTANT]` 접두어 및 한글 `> **중요 (IMPORTANT)**` 볼드체를 함께 사용해 박스화합니다.

---

## 2. Homeroom 활성화 및 카탈로그 메뉴 명명 표준

* **`workshop/workshop.yaml` (활성화 제어):** 실습 모듈 활성화 목록인 `modules: activate` 리스트에 실제 제작한 마크다운 식별자명을 기입합니다.
* **`workshop/modules.yaml` (메뉴 제목 정의):** 가이드북 좌측 카탈로그에 표시될 다채롭고 한글화된 제목 사양을 작성합니다.
  * 예:
    ```yaml
    lab1.1_architecture:
      name: lab1.1-아키텍쳐
    lab1.2_application_intro:
      name: lab1.2-애플리케이션 소개
    ```

---

## 3. 깃허브(GitHub) 저장소 동기화 준수

* 배포 자동화 및 이미지 BuildConfig 조립은 항상 현재 프로젝트의 공식 깃허브 원격 저장소(`https://github.com/ailee-1111/service-mesh-3-workshop.git`)의 `main` 브랜치를 기준으로 진행되어야 합니다.
