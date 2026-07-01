# Red Hat OpenShift Service Mesh 3.0 Workshop 프로젝트

본 프로젝트는 기존 OpenShift Service Mesh 3.x (OSSM v3) 단일 실습 환경을 분석하여, **새로운 OpenShift Service Mesh 3.0 (OSSM v3 / Sail Operator)** 아키텍처에 부합하는 차세대 서비스 메시 실습 환경을 신규 클러스터에 구축하고 가이드북 대시보드를 배포하는 프로젝트입니다.

이 문서는 프로젝트의 전체 목표, 이관 작업 현황, 클러스터 접속 정보 등을 일괄 관리하기 위한 기준 문서입니다.

---

## 🎯 프로젝트 주요 목표

1. **실습 환경 최적화 및 이관:**
   - 기존 **클러스터 1 (OSSM v3)** 의 실습 구조와 핵심 사용자 대시보드 환경 파악
   - **클러스터 2 (OSSM v3)** 환경으로의 마이그레이션 수행 및 실습 환경 최적화 구성

2. **OSSM v3 실습 모듈 작성 및 검증:**
   - Sail Operator 및 Gateway API 등 OSSM v3 고유 아키텍처 실습에 필요한 환경을 구성
   - 한국어 번역 및 로컬라이징(Localized) 실습 가이드북 완비
     랩 가이드북을 작성하는 법:
     1) 업로드 된 pdf를 구성 그대로 텍스트를 한국어로 자연스럽게 번역하여 작성한다.
     2) 내용은 추가하거나 삭제하지 않는다.
     3) 본문의 중간에 'Figure'가 삽입되어 있는 부분은 '딱! 그림만을 캡쳐하여(텍스트로 된 본문 부분이 포함되지 않게)' svg확장자로 삽입한다.
     4) 명령어를 수행하는 부분은 'excute' 형식으로 작성한다.
     5) 명령어에 따른 결과값이 출력되는 부분은 text를 그대로 가져와서 shell 형식으로 표현해준다.
     6) Note 부분은 md에서 별도로 note로 표시해준다.

3. **자동 배포 및 인프라 자동화:**
   - `homeroom` 네임스페이스 기반의 가이드북 스포너(Spawner) 및 분배기 설정
   - Dockerfile 빌드 안정화 및 배포 자동화 파이프라인 수립

---

## 🖥️ 클러스터 정보 (사용자 업데이트 영역)

사용자 환경에 맞춰 아래 클러스터 접속 정보 및 네임스페이스 정보를 자유롭게 수정 및 업데이트해 주세요.

### 1. 기존 클러스터 1 (OSSM v3 환경)

해당 클러스터는 Workstation에 각 실습에 필요한 스크립트 및 'lab start' 라는 명령어를 통해 실습환경을 구축하는 스크립트가 내제되어 있다.
해당 실습환경은 단일 유저(student)에 의해 실습되는 환경으로 네임스페이스등의 환경이 단일화 구성이다.
해당 실습 환경의 Workstation에 내제되어 있는 각 실습환경 구성 및 수행에 필요한 파일 및 스크립트, 환경은 새로 구성해야 하는 신규 '클러스터2'의 환경에 userN에 맞는 환경 내에 내제하고 사용할 수 있도록 구성해야 한다.

* **API 서버 주소 (URL):** *https://api.ocp4.example.com:6443*
* **kubeconfig :** /home/student/.auth/ocp4-kubeconfig  
* **ssh 접속정보 :** ssh -i ~/.ssh/rht_classroom.rsa -J cloud-user@203.60.21.119:22022 student@172.25.252.1 -p 53009
* **ssh 접속시 패스워드:** student
* **접속 로그인 토큰:** 
* **주요 오퍼레이터 버전:** 
* **네임스페이스 구성:** `user1`, `user2`, `user3` 등 사용자별 격리 네임스페이스 및 `homeroom` 대시보드 공간



### 2. 신규 클러스터 2 (OSSM v3 환경 - 목표 대상)

해당 클러스터는 user1..user2..userN 등으로 환경을 프로비저닝하면서 필요한 user의 수가 매번 변경되어 프로비저닝된다.
해당 클러스터의 userN은 변수처리되어, 실습에 필요한 namespace나 환경 구성, 그리고 로그인 명령어등의 실습 환경, 가이드 등에 변수처리되어 사용할 수 있어야 한다.


* **API 서버 주소 (URL):** *https://api.cluster-pgx9x.pgx9x.sandbox3385.opentlc.com:6443*
* **login user:** admin
* **login password:** MjcwMjI3
* **ssh 접속정보 :** ssh lab-user@bastion.pgx9x.sandbox3385.opentlc.com
* **ssh 접속시 패스워드:** yOYT1y3NaMbH
* **접속 로그인 토큰:** 
* **주요 오퍼레이터 버전:** OSSM v3 (Sail Operator), Kiali Operator, OpenTelemetry, Tempo, Cert Manager
* **네임스페이스 구성:** `homeroom` 및 사용자별 `userX-meshintro-bookinfo` 등 가동 프로젝트 영역을 user수에 맞게 변수처리하여 구분해야 한다.



---

## 📚 서비스 메시 3.0 실습 모듈 구성 현황

OSSM v3 랩은 아래 실습 시나리오 목록을 목표로 순차 기획 및 번역이 진행 중입니다.

| 모듈 ID | 실습 제목 | 한글화 상태 | 진행 상황 및 설명 |
| :--- | :--- | :---: | :--- |
| **Index** | [Index (워크숍 대시보드 홈)](./workshop/content/index.md) | ✅ 완료 | 서비스 메시 3.0 전체 아키텍처 및 코스 목차 설명 |
| **Module 1.1** | [오픈시프트 서비스 메시 아키텍처 탐구](./workshop/content/lab1.1_architecture.md) | ✅ 완료 | OSSM v3 Sail Operator 및 CNI, 제어/데이터 평면 아키텍처 이론 |
| **Module 1.2** | [서비스 메시 쇼룸 애플리케이션](./workshop/content/lab1.2_application_intro.md) | ✅ 완료 | Bookinfo 다국어 마이크로서비스 아키텍처 이론 및 트래픽 제너레이터 사용법 설명 |
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
