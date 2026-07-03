<style>
  h1 { font-size: 24px !important; }
  h2 { font-size: 20px !important; }
  h3 { font-size: 16px !important; }
</style>

<script>
document.addEventListener("DOMContentLoaded", function() {
    var checkAndReplace = function() {
        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
        var node;
        while (walker.nextNode()) {
            node = walker.currentNode;
            if (node.nodeValue.includes("api.apps.")) {
                node.nodeValue = node.nodeValue.replace(/api\.apps\./g, "api.");
            }
        }
    };
    checkAndReplace();
    setTimeout(checkAndReplace, 100);
    setTimeout(checkAndReplace, 500);
    setTimeout(checkAndReplace, 1500);
    setTimeout(checkAndReplace, 3000);
});
</script>

# 모듈 4.1: OpenShift Service Mesh 옵저버빌리티 개요 (Observing OpenShift Service Mesh)

오픈시프트 서비스 메시가 제공하는 기본 모니터링 생태계 및 분산 관제(Observability) 포트폴리오의 구조적 아키텍처와 연동 흐름을 학습합니다. 서비스 메시가 어떻게 전착 수집된 L7 골격 메트릭을 바탕으로 실시간 서비스 토폴로지(Service Topology Graph)를 그려내고, 이상 기류 및 에러 레이턴시를 즉각 가시화하는지 그 기저 메커니즘을 규명합니다.

## 학습 목표 (Objectives)
* 모니터링과 분산 추적(Distributed Tracing) 관점에 초점을 맞추어 서비스 메시 옵저버빌리티의 기본 개념을 정밀 식별합니다.
* 가시성을 담당하는 OpenShift Service Mesh 내부의 핵심 모니터링 결합 컴포넌트들을 완벽하게 규명합니다.
* 오픈시프트 전용 내장형 서비스 메시 웹 콘솔 플러그인(OSSMC)과 정식 Kiali 독립 웹 콘솔이 선사하는 가용 능력을 정밀 대조 평가합니다.

---

## 1. Red Hat OpenShift Observability 생태계와의 조화

* **옵저버빌리티 (Observability):**
  동적으로 구동 중인 대규모 마이크로서비스 내부 전산망의 수·발신 메시지와 에러 원장, 로그 데이터를 동적으로 수집(Telemetry)하고 교차 분석함으로써, 시스템 내부의 동작 정황을 가시적이고 투명하게 파악해 낼 수 있는 종합 관제 능력입니다.
* Red Hat OpenShift Service Mesh는 오픈시프트가 기본 제공하는 강력한 옵저버빌리티 포트폴리오 장비군과 유기적으로 기습 결합하여 고품격 전역 모니터링을 실현합니다:
  - **OpenShift Logging (로그 수집 통합):** 파드와 노드 장비들로부터 방출되는 모든 원격 덤프 로그 정보를 한곳으로 전사적으로 긁어모아 정렬 및 가속 검색, 리포팅을 지원합니다.
  - **Network Observability (네트워크 가시성):** 가상 네트워크 브릿지 및 물리 포트의 트래픽 교차 변동 추이를 스캐닝하고 이상 기류를 사전에 색출해 냅니다.
  - **OpenShift Monitoring (기본 모니터링 스택):** 플랫폼 핵심 장비 및 사용자 프로젝트 프로젝트 워크로드 모니터링을 전담하며, 배후에 **`Prometheus`**(시계열 데이터베이스 메트릭 저장소), **`Thanos`**(다중 클러스터 메트릭 집계 및 초장기 보관 장치), 그리고 경보 장치인 **`Alertmanager`** 삼각 편대를 기본 가동 수립합니다.

오픈시프트 서비스 메시는 이 중에서 특히 **`OpenShift Monitoring`**과 **`Distributed Tracing`** 양대 옵저버빌리티 주축 장비를 전폭 가용하여 실시간 망 상태 가시성을 확보해 냅니다!

---

## 2. 분산 추적 (Distributed Tracing) 및 텔레메트리 기둥

분산 추적 기술은 단일 클라이언트 요청이 게이트웨이를 노크하며 서비스 내부 영역으로 침입해 들어온 이후, 소멸 회신될 때까지 거치고 통과하는 수많은 다단형 마이크로서비스들의 물리 통신 경로 전체를 실시간 단일 실선 장벽으로 이어 추적 관제합니다.

* **Span (스팬):** 요청이 마이크로서비스 하나를 무사히 거쳐 처리될 때마다 부여받아 생성되는 상황 컨텍스트 정보 지표 단위입니다.
* **Trace (트레이스):** 단일 진입 요청을 감당하기 위해 유기적으로 생성 및 수발신된 수많은 스팬(Span) 복합 자산들의 완전한 총합 구조 장부입니다.
* OpenShift Service Mesh 3.0은 차세대 분산 추적 기동을 위해 다음과 같은 표준 컴포넌트들을 탑재 수립합니다:
  - **OpenTelemetry (OTel):** 이기종 분산 시스템에서 옵저버빌리티 패킷 데이터를 기성 클라우드 벤더 종속 없이 수집 가공하여 배후 저장소로 밀어 올려 주는 범용 오픈소스 전산 프레임워크입니다.
  - **Grafana Tempo (그라파나 템포):** 기존 수명이 종결 정리된 Jaeger 백엔드를 대체하는 **오픈시프트 서비스 메시 3.0의 정식 분산 추적 백엔드 메인 시계열 데이터베이스 장비**입니다. 극도의 확장성과 메모리 다이어트 가치를 선사합니다.

---

### 3. OpenShift Service Mesh 가시성 통합 작동 흐름 아키텍처

아래 도해는 Kiali 관제 서버와 오픈시프트 전용 웹 콘솔 플러그인(OSSMC)이 배후의 프로메테우스, OTel 컬렉터, 템포 백엔드 및 이스티오 제어부 API 세력들과 유기적으로 어떻게 실시간 연대 교차하여 가시적인 실시간 트래픽 토폴로지를 그려내는지 전사적 데이터 파이프라인 작동 흐름을 완벽하게 투명 증명합니다:

<img src="images/lab4.1-observability-fig-001.png" width="100%" alt="Figure 1.1: Integration of Kiali and OSSMC with OpenShift observability components" />

#### Kiali 데이터 수집 및 4단계 렌더링 파이프라인 작동 원리:
1. **메트릭 수집 및 덤프 (Data collection):** 오픈시프트 유저 시계열 프로메테우스가 각 파드 옆의 Envoy 프록시들과 비즈니스 컨테이너로부터 실시간 유량 메트릭 데이터를 주기적으로 스크래핑해 모읍니다. ❶
2. **설정 명세 스캐닝 (Configuration retrieval):** Kiali 서버가 오픈시프트 API 서버 및 이스티오 제어부 API를 상시 노크하여, 가상 서비스 및 대상 규칙 등의 최신 L7 설정 배치 현형을 실시간으로 가져옵니다. ❷
3. **상호 교차 계산 정합 (Data processing):** Kiali 코어 엔진이 앞서 수집한 원격 프로메테우스 L7 메트릭 값들과 이스티오 설정 룰들의 논리적 연결성을 대조 상호 분석 연계합니다. ❸
4. **대시보드 실시간 렌더링 (Visualization):** 분석 결합이 완료된 무결한 가시성 시각화 소스를 오픈시프트 전용 서비스 메시 콘솔 플러그인(OSSMC) 인터페이스 단으로 송출하여 웹 콘솔 UI 상에 미려하게 전사 표출합니다! ❹

> [!IMPORTANT]
> **중요 (IMPORTANT)**
> Kiali 콘솔이 선사하는 거의 대부분의 지능형 관제 비주얼 능력과 토폴로지 분석력은 배후의 **`Prometheus`가 수집 축적해 주는 L7 메트릭 정보에 전적으로 200% 의존**하여 작동합니다! 만일 프로메테우스 수집 선로에 단절이 일어날 경우 Kiali의 가시성 화면 역시 영구 정지 마비되므로, 프로메테우스 모니터링 파이프라인의 연속성은 옵저버빌리티 수립의 최우선 사명입니다.

---

## 4. Kiali 고유의 3대 핵심 관리 능력 (Key Capabilities)

Kiali 가 관제사에게 선사하는 **3대 핵심 관리 능력**을 면밀히 분석합니다.

### ① 실시간 서비스 토폴로지 시각화 (Service Topology Visualization)
* 마이크로서비스 간의 수발신 상호 디펜던시 관계와 물리적 동적 호출 유동을 한눈에 식별하는 라이브 동적 그래프를 그려냅니다.
* 그래프 위에서 요청 처리 속도, L7 에러율 덤프 지표, 서킷 브레이커 격발 추방 정황, 타임아웃 레이턴시 급증 상황 등을 입체적으로 관측할 수 있습니다.

### ② 구성 자산 통제 관리 (Configuration Management)
* 가상 서비스, 대상 규칙, 게이트웨이 및 사이드카 설정의 배치 현형을 실시간으로 모니터링하고 문법 오류 및 중복 충돌을 선제 체크 경고해 줍니다.

### ③ 전계 보증 계산 (Observability and Monitoring)
* 라이브 메트릭 실시간 차트 제공, OTel 기반의 분산 추적 그라파나 템포 UI 연계 팝업 단추 장착, 서비스 전역 헬스 등급 자율 정비 계산 경보 장벽 개설 등을 수행합니다.

---

## 5. OpenShift 내장형 플러그인(OSSMC)의 장단점 및 CLI 연동

레드햇은 Kiali 화면 전체를 별도 도메인으로 나가지 않고 오픈시프트 관리자/개발자 웹 콘솔 내부 메뉴 안으로 직접 투영 삽입해 주는 **`OSSMC (OpenShift Service Mesh Console)`** 플러그인 장비를 기본 패키지 제공합니다.
* **OSSMC의 실무적 혜택:**
  - 쿠버네티스 디플로이먼트나 서비스의 디테일 화면 우측 상단 탭 메뉴 안에 **"Service Mesh"** 라는 고유의 서브 탭을 기습 매립해 줍니다. 따라서 개발자는 본인 파드를 점검하다가 탭 전환 단 한 번만으로 해당 파드 Envoy 프록시가 가입 수용한 실시간 L7 메트릭 변동 추이를 즉석에서 감상할 수 있는 엄청난 UX 일치성을 확보하게 됩니다!

<img src="images/lab4.1-observability-fig-002.png" width="100%" alt="Other OpenShift and Kubernetes objects show a new Service Mesh tab" />

* **OSSMC 적용 한계:**
  - 독립 Kiali 웹 콘솔과 달리, 오픈시프트 전용 플러그인은 **하나의 웹 브라우저 화면 상에서 동시 단 하나의 서비스 메시(Single Mesh) 영역만을 관제 렌더링**할 수 있는 명확한 스코프 물리 한계를 지닙니다. 여러 제어 평면 메시가 구동 중인 대형 클러스터 환경 하에서 다중 관제를 이식하고자 할 때에는 독립형 Kiali 서버 웹 인터페이스로 직접 우회 접속해야만 합니다.

Kiali 독립 콘솔의 정식 접속 URL 경로 주소를 터미널 상에서 즉시 발굴해 내고자 할 때는 다음 `oc` 명세를 실행하여 조회할 수 있습니다:

```bash
echo "https://$(oc get routes -n project_for_istio_and_kiali kiali -o jsonpath='{.spec.host}')"
```

---

## 6. Kiali 실시간 트래픽 그래프 뷰의 핵심 세부 활용 요령

Kiali 및 OSSMC가 렌더링하는 다단형 라이브 트래픽 그래프 뷰의 세부 감상 및 기동 통제 요령을 밀착 요약합니다.

### ① 그래프 렌더링 세분화 4대 등급 (Graph Types)
관제사가 보고자 하는 입체적 시각 심도에 맞춰 그래프 뷰포트 필터를 다음과 같이 4가지 종류로 가변 전환할 수 있습니다:
* **App graph (애플리케이션 기반 뷰):** 파드들을 단일 논리 앱 지표로 수렴 집계하여, 서비스 간의 비즈니스 논리 구조만을 고도로 심플하게 도해합니다.
* **Service graph (쿠버네티스 서비스 기반 뷰):** 오직 쿠버네티스 서비스(`Service`) 가상 도메인 엔드포인트 노선 간의 패킷 유입 정황만을 단순화해 표출합니다.
* **Versioned app graph (버전 분할 기반 뷰):** 동일 앱에 여러 subset 버전들(예: `reviews v1`, `v2`, `v3`)이 전개되어 있다면, 노드 박스를 여러 개로 분할 전개하여 카나리 가중 배정 상태를 미세 대조할 수 있도록 배려해 줍니다.
* **Workload graph (물리 파드 기반 뷰):** 실제 처리 파드 인스턴스 장비들 간의 워크로드 대 워크로드 물리 다이렉트 통신 정황을 가장 세밀하게 디테일 현미경 렌더링해 줍니다.

### ② 실시간 헬스 컬러 관제표 (Health Colors)
Kiali 그래프 선로와 노드 원장 테두리의 색상은 실시간으로 분석 갱신되며 다음 헬스 등급을 암시해 줍니다:
* **Green (초록색):** 에러율 0% 가량의 최고 조도의 완벽 무결 헬스 패스 상태.
* **Yellow/Orange (노란색/황색):** 경고 상태. 일부 요청의 지연 마비나 에러 덤프가 누적 포착되기 시작함.
* **Red (빨간색):** 심각 위험 상태. 유입 요청의 대다수가 5xx 등의 치명적 실패 크래시를 겪고 있어 즉각적 롤백 개입이 시급함.
* **Gray (회색):** 유입 트래픽이 없어 대기 기동 상태에 머물러 있는 유휴(Idle) 노드 상태.

<img src="images/lab4.1-observability-fig-005.png" width="100%" alt="Different colors point to the health of services and communications" />

### ③ 사이드 패널 상세 현미경 및 타임 리플레이 (Side Panel & Replay)
* 그래프 상의 특정 노드를 윈클릭하는 순간 우측에서 접이식 **사이드 패널(Side Panel)**이 돌출 가동되며, 해당 노드의 동시 처리량 차트, mTLS 자물쇠 신원 정보, 관련 OTel Span 추적 링크를 팝업 전시합니다.
* 상단의 **`Replay (타임 리플레이)`** 기능을 활성화하면, 이미 흐르고 지나간 과거의 기 특정 시간대 혼잡 발생 시점의 트래픽 흐름을 비디오 테이프 되감듯이 실시간 역재생(Play/Pause) 분석해 볼 수 있는 극치의 사후 소스 포렌식 관제력을 선사합니다!

<img src="images/lab4.1-observability-fig-007.png" width="100%" alt="Some display menu options" />
