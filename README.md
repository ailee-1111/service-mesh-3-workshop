# Red Hat OpenShift Service Mesh 3.0 Workshop 프로젝트

본 프로젝트는 기존 OpenShift Service Mesh 2.x (OSSM v2) 실습 환경을 분석하여, **새로운 OpenShift Service Mesh 3.0 (OSSM v3 / Sail Operator)** 아키텍처에 부합하는 차세대 서비스 메시 실습 환경을 신규 클러스터에 구축하고 가이드북 대시보드를 배포하는 프로젝트입니다.

이 문서는 프로젝트의 전체 목표, 이관 작업 현황, 클러스터 접속 정보 등을 일괄 관리하기 위한 기준 문서입니다.

---

## 🎯 프로젝트 주요 목표

1. **실습 환경 최적화 및 이관:**
   - 기존 **클러스터 1 (OSSM v2)**의 실습 구조와 핵심 사용자 대시보드 환경 파악
   - **클러스터 2 (OSSM v3)** 환경으로의 마이그레이션 수행 및 실습 환경 최적화 구성

2. **OSSM v3 실습 모듈 작성 및 검증:**
   - Sail Operator 및 Gateway API 등 OSSM v3 고유 아키텍처 실습 작성
   - 한국어 번역 및 로컬라이징(Localized) 실습 가이드북 완비

3. **자동 배포 및 인프라 자동화:**
   - `homeroom` 네임스페이스 기반의 가이드북 스포너(Spawner) 및 분배기 설정
   - Dockerfile 빌드 안정화 및 배포 자동화 파이프라인 수립

---

## 🖥️ 클러스터 정보 (사용자 업데이트 영역)

사용자 환경에 맞춰 아래 클러스터 접속 정보 및 네임스페이스 정보를 자유롭게 수정 및 업데이트해 주세요.

### 1. 기존 클러스터 1 (OSSM v2 환경)
* **API 서버 주소 (URL):** *(예: https://api.cluster-9kbpf.9kbpf.sandbox3270.opentlc.com:6443)*
* **접속 로그인 토큰:** `oc login --token=... --server=...`
* **주요 오퍼레이터 버전:** Red Hat OpenShift Service Mesh 2.x, Kiali, Jaeger/Elasticsearch
* **네임스페이스 구성:** `user1`, `user2`, `user3` 등 사용자별 격리 네임스페이스 및 `homeroom` 대시보드 공간

### 2. 신규 클러스터 2 (OSSM v3 환경 - 목표 대상)
* **API 서버 주소 (URL):** *(예: https://api.cluster-xxxx.xxxx.sandbox.opentlc.com:6443)*
* **접속 로그인 토큰:** `oc login --token=... --server=...`
* **주요 오퍼레이터 버전:** OSSM v3 (Sail Operator), Kiali Operator, OpenTelemetry, Tempo, Cert Manager
* **네임스페이스 구성:** `homeroom` 및 사용자별 `userX-meshintro-bookinfo` 등 가동 프로젝트 영역

---

## 📚 서비스 메시 3.0 실습 모듈 구성 현황

OSSM v3 랩은 아래 실습 시나리오 목록을 목표로 순차 기획 및 번역이 진행 중입니다.

| 모듈 ID | 실습 제목 | 한글화 상태 | 진행 상황 및 설명 |
| :--- | :--- | :---: | :--- |
| **Index** | [Index (워크숍 대시보드 홈)](./workshop/content/index.md) | ✅ 완료 | 서비스 메시 3.0 전체 아키텍처 및 코스 목차 설명 |
| **Module 1.1** | [오픈시프트 서비스 메시 아키텍처 탐구](./workshop/content/lab1.1_architecture.md) | ✅ 완료 | OSSM v3 Sail Operator 및 CNI, 제어/데이터 평면 아키텍처 이론 |
| **Module 1.2** | [서비스 메시 쇼룸 애플리케이션 (Bookinfo 배포)](./workshop/content/lab1.2_application_deployment.md) | ✅ 완료 | Bookinfo 애플리케이션 설치 및 기본 인그레스 트래픽, Kiali 트래픽 시프팅 |
| **Module 1.3** | **Istio 버전 마이그레이션** | ⬜ 대기 | 이스티오 버전 마이그레이션 수립 및 점진적 업그레이드 |
| **Module 2.1** | **Bookinfo 트래픽 제어** | ⬜ 대기 | Gateway API 및 HTTPRoute 기반 고급 트래픽 분배 |
| **Module 2.2** | **Istio 장애 허용 (Fault Tolerance)** | ⬜ 대기 | 서킷 브레이커, 재시도, 타임아웃, 폴트 인젝션 실습 |
| **Module 3.1** | **OSSM v3 상호 TLS (mTLS) 보안** | ⬜ 대기 | PeerAuthentication 활용 종단간 mTLS 강제 및 확인 |
| **Module 3.2** | **OSSM v3 권한 부여 (Authorization)** | ⬜ 대기 | AuthorizationPolicy 기반 세분화된 인가 제어 |
| **Module 4.1** | **옵저버빌리티 및 서비스 메트릭** | ⬜ 대기 | Prometheus 연동 모니터링 메트릭 및 Kiali 시각화 |
| **Module 4.2** | **Tempo & OpenTelemetry 추적** | ⬜ 대기 | OTel Collector 및 Tempo를 통한 마이크로서비스 간 분산 추적 |

---

## 🛠️ 작업 가이드 및 깃 동기화 (Workspace Sync Guide)

### 1. 작업 디렉토리 정보
- **로컬 디렉토리:** `/Users/seunglee/gemini/ServiceMesh3`
- **원격 저장소 (GitHub):** `https://github.com/ailee-1111/service-mesh-3-workshop.git`

### 2. 깃 허브 동기화 명령 가이드
새로운 정보 업데이트 후, 변경사항을 원격 저장소(`main` 브랜치)로 반영하려면 아래 명령어를 사용합니다:

```bash
# 1. 변경된 파일 로컬 저장소 스테이징
git add README.md

# 2. 커밋 작성
git commit -m "docs: 업데이트 프로젝트 개요 및 클러스터 마이그레이션 정보 수립"

# 3. 원격 저장소 푸시
git push origin main
```
