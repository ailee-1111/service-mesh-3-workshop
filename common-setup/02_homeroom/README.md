# 📚 Service Mesh 3.0 Workshop - Homeroom 가이드북 대시보드 배포 패키지

이 폴더는 참가자들이 웹 브라우저에서 실습 교재 가이드라인과 오픈시프트 웹 터미널/콘솔을 한눈에 보며 실습을 따라 할 수 있도록 지원하는 **Homeroom(Spawner 및 분배기)** 인프라를 자동으로 배포하고 관리하기 위한 자원 꾸러미입니다.

---

## 📂 파일 구성 안내

1. **`homeroom_all_resources.yaml`**:
   * 가이드북 스포너 및 분배기 기동을 위한 전체 쿠버네티스 오브젝트 명세서(Template)입니다.
   * 사용자 수(`LAB_USER_COUNT`) 및 클러스터 서브도메인이 셸 배포 스크립트에 의해 동적으로 자동 조립되도록 설계되었습니다.
2. **`deploy-homeroom.sh`**:
   * '클러스터 2' 상에서 가동 중인 격리된 유저 네임스페이스(`user1`~`userN`)의 정원을 **자동으로 실시간 감지**하여 유저 수에 최적화된 Spawner 환경을 생성합니다.
   * 현재 프로젝트의 공식 Git 리포지토리(`https://github.com/ailee-1111/service-mesh-3-workshop.git`)의 `main` 브랜치를 기준으로 BuildConfig를 생성하여 무인 빌드·배포합니다.
3. **`cleanup-homeroom.sh`**:
   * 배포되었던 `homeroom` 네임스페이스 및 클러스터 전역 OAuth 권한 설정을 원클릭으로 일괄 완전 제거하는 자원 반납 스크립트입니다.

---

## 🚀 배포 및 실행 방법

### 1단계. 대상 클러스터(클러스터 2) 로그인 확인
터미널에서 `oc login` 명령을 통해 관리자(`admin` 등) 자격으로 클러스터에 접속합니다.

### 2단계. 스크립트 실행 (Homeroom 구축 및 Spawner 구동)
`02_homeroom` 디렉토리로 이동하여 배포 스크립트를 가볍게 구동해 줍니다:

```bash
cd common-setup/02_homeroom/
./deploy-homeroom.sh
```

**동적 감지 및 자동 빌드 흐름:**
1. 클러스터 API로부터 앱 통신용 라우팅 서브도메인을 자동 파싱합니다.
2. 클러스터 상의 사용자 네임스페이스 목록을 긁어와 고유 사용자 수(예: `5명`)를 동적으로 검출합니다.
3. 현재 개발 중인 이 리포지토리를 원천 소스(Source)로 지정하여 `BuildConfig` 및 빌드를 기동합니다.
4. 빌드가 완료되면 스포너 및 계정 분배기 포드를 무중단 롤아웃합니다.

### 3단계. 대시보드 및 분배기 접속 URL 확인
설치가 완료되면 화면에 출력되는 접속 링크를 통해 웹 브라우저에서 가이드 대시보드를 정상 조회할 수 있습니다:
* **참석자 가이드북 대시보드:** `http://workshop-dashboard-homeroom.apps.[CLUSTER_SUBDOMAIN]`
* **참석자 계정 분배기 (Username Distribution):** `https://username-distribution-homeroom.apps.[CLUSTER_SUBDOMAIN]` (액세스 토큰: `redhatlabs`)

---

## 🗑️ 제거 및 자원 반납 방법

워크숍이 종료되거나 인프라를 깔끔하게 리셋하려면 다음 제거 스크립트를 한 번 구동해 줍니다:

```bash
./cleanup-homeroom.sh
```
