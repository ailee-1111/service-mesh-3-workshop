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

# Observing OpenShift Service Mesh

오픈시프트 서비스 메시 환경 하에서 제공하는 핵심 모니터링 체계와 실시간 서비스 트래픽 가시성 시각화 수립 사상을 학습합니다.

---

## Tracing Services With Kiali, Tempo and OpenTelemetry

### 학습 목표 (Objectives)
* 트레이스(traces), 스팬(spans) 및 트레이스 컨텍스트 전파(trace context propagation)를 포함한 분산 추적(distributed tracing) 개념을 설명합니다.
* OpenTelemetry, Tempo 및 Kiali를 포함하여 OpenShift Service Mesh의 분산 추적 구성 요소를 설명합니다.
* OpenShift Service Mesh에서 분산 추적을 위한 자동 및 수동 계측(instrumentation) 옵션을 파악합니다.
* 분산 추적 결과를 보고 분석하기 위한 세 가지 시각화 인터페이스(트래픽 그래프, Observe 메뉴, Service Mesh 워크로드 탭)를 비교합니다.

---

### 분산 추적 (Distributed Tracing)

분산 추적(Distributed Tracing)은 애플리케이션 내의 서비스 호출 경로를 추적하여 개별 서비스의 성능을 추적하는 프로세스입니다. 애플리케이션에서 수행되는 각 사용자 동작은 하나의 요청을 생성합니다. 이 요청은 응답을 생성하기 위해 많은 서비스들이 상호 작용하도록 요구할 수 있습니다. 이 요청이 거쳐 가는 경로가 바로 분산 트랜잭션(distributed transaction)입니다.

<img src="images/lab4.2-tracing-fig-001.png" width="100%" alt="Figure 1.30 & 1.31: Traffic flow in a system with and without distributed tracing" />

분산 시스템의 성능 문제를 해결하는 것은 시스템의 유지 관리 및 개발에 있어 매우 중요합니다. 단일 클라이언트 호출이 여러 서비스와 상호 작용할 수 있기 때문에, 개별 서비스의 디버깅 로그를 개별 분석하는 것만으로는 전반적인 성능 문제를 해결하는 데 큰 도움이 되지 않을 수 있습니다.

분산 추적을 활용하면 개발자가 분산 애플리케이션의 호출 흐름을 시각화할 수 있습니다. 호출 순서, 직렬로 발생하는 호출 수와 병렬로 발생하는 호출 수의 파악, 그리고 레이턴시(지연 시간)의 발생 원인을 파악하는 것은 분산 시스템을 유지 관리할 때 매우 유용합니다.

예를 들어, 어떤 요청 처리 시간이 너무 길어 성능 문제가 발생하는 경우, 속도 저하를 유발하는 특정 서비스나 서비스들을 정확히 식별하고 서비스 호출 간의 네트워크 레이턴시를 정밀 점검할 수 있습니다.

분산 추적은 현대적인 클라우드 네이티브 분산 애플리케이션 환경 하에서 서비스 간 상호 작용의 모니터링, 네트워크 프로파일링 및 트러블슈팅에 대단히 유용합니다.

---

### 분산 추적의 Traces와 Spans

분산 추적은 다음 두 가지 핵심 용어를 사용합니다:

* **Span (스팬):**
  스팬(Span)은 하나의 논리적인 작업 단위(logical unit of work)를 대변하며, 고유한 명칭, 시작 시간 및 실행 지속 시간(duration of execution)을 소지합니다. 서비스 메시 내에서 서비스 호출 흐름은 특정 순서대로 실행되는 중첩된 스팬(nested spans)들의 계층 구조 모델로 나타납니다.
* **Trace (트레이스):**
  트레이스(Trace)는 서비스 메시를 관통하여 소화되는 서비스들의 전체 실행 경로입니다. 하나의 트레이스는 하나 이상의 스팬들로 구성됩니다.

다음과 같은 서비스들로 구성된 애플리케이션 시나리오를 검토해 보겠습니다:

<img src="images/lab4.2-tracing-fig-002.png" width="100%" alt="Figure 1.32: Request call path in an application composed of many components" />

이 시나리오 예제에서는 다음과 같은 흐름이 전개됩니다:
* `Service A`가 애플리케이션의 요청 진입점(request entry point) 역할을 맡습니다.
* `Service A`가 애플리케이션의 진입점이므로, 시스템은 이 단위를 **부모 스팬 (parent span)**이라고 부릅니다. `Service A`는 두 가지 서비스 호출을 수행하는데, 하나는 `Service B`로의 호출이고 다른 하나는 `Service E`로의 호출입니다. 따라서 `Service B`와 `Service E`는 `Service A` 배후 하위에 속한 **자식 스팬 (child spans)**이 됩니다.
* `Service B`는 다시 `Service A`로 최종 응답을 회신하여 돌려보내기 전에 `Service C`와 `Service D`를 순차 노크 호출합니다. 이 경우 `Service B`가 부모 스팬 역할을 수행하게 되며, `Service C`와 `Service D`가 이 `Service B` 하위의 자식 스팬이 됩니다.

아래 라인 그래프 도식은 단일 트레이스와 이를 지탱하는 하위 구성 스팬 조각들의 계층적 지속 시간 분포를 타임라인 선상 위에 입체 전시한 형상입니다:

<img src="images/lab4.2-tracing-fig-003.png" width="100%" alt="Figure 1.33: Traces and spans" />

---

### Red Hat OpenShift 환경에서의 분산 추적 아키텍처

Red Hat OpenShift Service Mesh는 OpenShift 옵저버빌리티 플랫폼을 통해 완전한 분산 추적 기능을 통합 제공합니다.

OpenShift Service Mesh 내의 분산 추적 솔루션은 다음 세 가지 핵심 컴포넌트를 상호 결합하여 작동합니다: **OpenTelemetry**, **Tempo** 및 **Kiali**.

* **OpenTelemetry:**
  메시 내부의 서비스들로부터 추적 데이터(trace data)를 수집하는 수집 및 계측 프레임워크를 제공합니다. Envoy 사이드카 프록시들은 요청이 메시를 관통하여 흐르는 과정에서 트레이스 컨텍스트 헤더 정보를 자동으로 생성하고 다음 노드로 전파(propagate)하여, 개별 서비스 상호 작용 단계마다 스팬을 자동으로 형성해 줍니다.
* **Tempo:**
  추적 데이터를 보관하고 검색 쿼리를 가동하는 분산 추적 저장소 백엔드 역할을 담당합니다. 클라우드 네이티브 기반 추적 시스템인 Tempo는 대용량의 추적 데이터를 고속 효율적으로 처리하며 OpenShift 옵저버빌리티 스택과 매끄럽게 융합됩니다. Tempo는 메시 전역에 전개된 OpenTelemetry 컬렉터로부터 추적 원장 데이터를 수신하여 이를 가시화 및 성능 분석에 활용할 수 있게 제공합니다.
* **Kiali:**
  OpenShift Service Mesh 하위에서 분산 추적 결과를 감상하기 위한 전용 메인 시각화 인터페이스 웹 화면을 선사합니다. Kiali는 오픈시프트 서비스 메시 콘솔 플러그인(OSSMC) 기술을 동원해, 수집된 분산 추적 데이터를 대시보드의 실시간 트래픽 그래프 및 서비스 뷰 상에 직접 융합 매립해 줍니다. 아울러 클러스터 옵저버빌리티 오퍼레이터가 제공하는 추적 플러그인 인터페이스를 통해 추적 데이터의 심층 분석을 동시 수행할 수 있습니다. 
  
  이러한 시각화 인터페이스들의 유기적 연대를 통해, 관제사는 단일 통합 화면 상에서 토폴로지, 메트릭, 그리고 트레이스를 입체적으로 비교 프로파일링하여 전반적인 애플리케이션의 거동과 성능을 완벽하게 파악할 수 있게 됩니다.

---

### OpenShift Service Mesh의 분산 추적 구성 요소를 다루는 아키텍처 흐름

<img src="images/lab4.2-tracing-fig-004.png" width="100%" alt="Figure 1.34: Components for distributed tracing on OpenShift and OpenShift Service Mesh" />

오픈시프트 및 오픈시프트 서비스 메시 전역 상에 분산 추적 시스템을 설치 구성하는 세부 원리는 참고 자료 가이드를 정독하십시오.

---

### OpenShift Service Mesh 의 계측(Instrumentation) 옵션 명세

OpenShift Service Mesh는 비즈니스 애플리케이션의 소스 코드를 단 한 글자도 수정하지 않고도 Envoy 사이드카 프록시 노선 단에서 **자동 분산 추적(Automatic Distributed Tracing)** 처리를 수행합니다. Envoy 프록시는 요청이 메시 내로 인입 통과해 나갈 때 트레이스 컨텍스트 헤더를 자율 생성 및 전파하여, 서비스 간 상호 호출 단계마다 스팬을 자동으로 형성시킵니다. 이 자동 계측 처리는 애플리케이션 전반의 서비스 토폴로지, 네트워크 레이턴시 및 L7 HTTP 수준의 요청 흐름에 대한 즉각적인 통계 시각화를 선사합니다.

이 자동화된 분산 추적 기능을 정상 가동하기 위해 다음 구성 요소를 클러스터 상에 완비해야 합니다:
* 정격 설치 및 자율 구동 구성이 완료된 **Tempo Operator** 장비.
* 클러스터 옵저버빌리티 오퍼레이터(Cluster Observability Operator)가 제공하는 **Distributed Tracing UI 플러그인** 마운트 완료.
* 각 서비스 프로젝트 네임스페이스 위에 각인된 **`istio-injection=enabled`** 이스티오 인젝션 레이벨 딱지 확인.
* 각 서비스 프로젝트 하위에 정식 배포 수립되어 Envoy 프록시들로부터 메트릭을 periodic 스캐닝해 가는 **`PodMonitor`** 모니터링 수집 규칙 확인.

그러나, 오직 Envoy 프록시 수준에서 유출 획득하는 자동 추적 방식은 서비스 간 경계선 상의 네트워크 L7 레이어 스팬 정보만을 수렴해 오는데 한계를 가집니다.

마이크로서비스 "내부 비즈니스 로직 단"에서 발생하는 정밀 전산 소요 지연(예: 데이터베이스 질의 쿼리 지연, 파일 입출력 병목, 내부 복잡 알고리즘 연산 시간, 외부 서드파티 API 결착 시간 등) 정보까지 완벽하게 파고드는 극치의 가시성을 확보하기 위해서는, **OpenTelemetry API를 애플리케이션 소스 코드 내에 주입 매립하는 애플리케이션 레벨의 수동 계측(Application-level Instrumentation)** 장치가 반드시 수반 결합되어야만 합니다!

애플리케이션 계측 설계는 Envoy 프록시가 수확해 온 네트워크 스팬 배후 하위에 상세 비즈니스용 스팬을 자식 계층으로 주입 생성할 수 있게 유도하고, 주문 ID나 사용자 고유 속성 등의 커스텀 주머니 정보 키값들을 스팬에 함께 실어 내보낼 수 있도록 설계할 수 있습니다. 

가령, 쇼핑몰 애플리케이션의 결제 checkout 트랜잭션 흐름을 대조해 보겠습니다. 단순한 프록시 자동 추적 방식 하에서는 단순히 frontend 서비스가 checkout 서비스를 노크했고 234ms가 지체되었다는 겉면 껍데기 통계만 보존 표시됩니다:

```bash
frontend ➔ checkout-service (234ms total)
```

반면, 소스 코드 단에 수동 OpenTelemetry API 계측 설계가 가미되어 있는 경우, 우리는 234ms 중에서 무려 175ms의 지연 병목 현상이 다름 아닌 DB 인벤토리 재고 쿼리 조회 구간에서 집중 파괴적으로 소모 격발되었음을 아주 정확하게 찾아내어 교정 타깃팅할 수 있게 됩니다!

```bash
frontend ➔ checkout-service (234ms total)
 ├─ validateCart (5ms)
 ├─ checkInventory (180ms)
 │   └─ database.query (175ms)
 ├─ calculateTax (10ms)
 ├─ processPayment (35ms)
 │   └─ stripeAPI.charge (30ms)
 └─ createOrder (4ms)
```

위 실선 계층 타임라인 대조를 통해, 현재 이 트랜잭션 선상에서 데이터베이스 쿼리가 전체 시간을 갉아먹는 핵심 범인 스팬 노드임을 일목요약하게 파악할 수 있습니다.

OpenTelemetry 프레임워크는 소스 이식을 위해 **자동 계측(Automatic instrumentation)**과 **수동 계측(Manual instrumentation)** 양대 설계 수단을 정식 열어두고 있습니다.

#### ① 자동 계측 (Automatic instrumentation)
* 개발 언어 런타임 환경에 침투하는 전용 에이전트(Agent)나 프레임워크 확장 라이브러리(Java Quarkus의 `quarkus-opentelemetry` 패키지, Node.js의 `@opentelemetry/api` 및 `@opentelemetry/auto-instrumentations-node` 의존 구성 등)를 정격 가입 가동하는 무수정 수집 방식입니다. 
* 개발자가 손수 코딩 작업을 가하지 않는다고 하여 업계에서는 이를 **제로 코드 계측 (Zero-code instrumentation)**이라 명명합니다. 주요 지원 런타임 에이전트 목록은 다음과 같습니다:
  - **Java Quarkus:** `quarkus-opentelemetry` 공식 확장 패키지 탑재
  - **Node.js:** `@opentelemetry` 자바스크립트용 메타패키지 라이브러리 탑재
  - **Python:** `opentelemetry-distro` 파이썬 패키지 이식
  - **Go:** `OpenTelemetry-Go` 공식 모듈 바인딩

가령, Node.js 애플리케이션의 기동 런타임 하단에 전역 자동 계측 에이전트 필터링을 주입하고자 할 때는 다음과 같은 패키지 빌드 및 실행 쉘 환경 변수 명세 조합을 활용하여 코드를 손대지 않고 구동시킬 수 있습니다:

```bash
[user@host application-src]$ npm install --save @opentelemetry/api
[user@host application-src]$ npm install --save @opentelemetry/auto-instrumentations-node
[user@host application-src]$ env OTEL_TRACES_EXPORTER=otlp OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=opentelemetry-endpoint \
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

#### ② 수동 계측 (Manual instrumentation)
* 소스 코드 내부 영역에 직접 OpenTelemetry API 명세를 임포트 주입하고, 커스텀 스팬 생성 구문(`tracer.startActiveSpan(...)`)과 속성을 개발자 손수 타이핑 설계하여 통제하는 고정밀 통제 방식입니다.
* 비즈니스 핵심 동작 경로에 대해 가장 세분화된 지연 포렌식 관제력을 가집니다. 단, 수정 코딩 비용 소모가 필요합니다.

가령 Node.js 소스 코드 비즈니스 연산 단락 하위에 특정 다이스 롤 횟수 연산 구간의 세부 레이턴시를 측정할 수동 커스텀 스팬을 형성하고자 할 때는 다음과 같은 완수 코딩 설계 양식을 이식합니다:

```javascript
const { trace } = require('@opentelemetry/api'); ❶
const tracer = trace.getTracer('dice-service'); ❷

function rollOnce(min, max) {
  return Math.floor(Math.random() * (max - min + 1) + min);
}

function rollTheDice(rolls, min, max) {
  // Create a span. A span must be closed.
  return tracer.startActiveSpan('rollTheDice', (span) => { ❸
    const result = [];
    for (let i = 0; i < rolls; i++) {
      result.push(rollOnce(min, max));
    }
    // Be sure to end the span!
    span.end(); ❹
    return result;
  });
}
```

❶ 분산 추적 통제 기능을 코드 단에 수배하기 위해 OpenTelemetry API 모듈 패키지를 정격 가져옵니다(import).
❷ 해당 마이크로서비스 또는 수집 컴포넌트명을 우회 식별할 수 있는 전용 트레이서 객체 인스턴스를 발급 획득합니다.
❸ 측정하고자 하는 비즈니스 연산 시작 직전에 고유 이름(`rollTheDice`)을 부여한 커스텀 활성 스팬 작동을 트리거 격발시킵니다.
❹ **실무 수전 가이드 핵심 필독:** 연산 처리가 무사히 끝난 직후 지점에, **생성했던 커스텀 스팬 객체의 종료 구문(`span.end()`)을 무조건 실행 보증 보장**해 주어야만 통신 패킷 메모리 leak 폭사 장애 현상을 완벽히 방어 차단할 수 있습니다!

---

### 트레이스 컨텍스트 전파 (Trace Context Propagation)의 동작 메커니즘

수동 계측 수립 시 가장 빈번히 유발되는 치명적 실수가 바로 **`컨텍스트 전파(Context Propagation)`** 누설 누락 필터 오류입니다.

* **컨텍스트 전파 메커니즘의 정의:**
  - 메시 내부의 서비스 A가 서비스 B를 호출할 때, 이스티오 프록시 단에서 발급해 준 고유의 추적 ID 정보들을 HTTP 요청 헤더 패킷(W3C 표준 규격인 **`traceparent`** 및 **`tracestate`** 지표!) 하위에 곱게 실어 전달 전파해야 합니다.
  - 이 헤더들이 무사히 다음 단계로 배달 이송되어야만, 수신측 마이크로서비스 프록시가 해당 ID를 상속받아 동일 트레이스 계층 바의 자식 스팬 격으로 예쁘게 결합해 줍니다.
* **개발자 주의점 (헤더 전달 의무):**
  - **Envoy 사이드카 프록시는 네트워크 경계선 외부 전파는 자동 처리해 주지만, 마이크로서비스 "내부 비즈니스 코드 단"에서 다른 하위 마이크로서비스로 아웃바운드 HTTP 요청을 전송해 내보낼 때 기존에 인입받았던 헤더 값들을 다음 요청 헤더에 직접 복사 바인딩 이송시켜 주는 처리는 자동화해주지 못합니다!**
  - 그러므로 개발자는 수동 기입 처리를 동원해서라도 인입 수신된 `traceparent` 쿠키 헤더값들을 하위 아웃바운드 REST 클라이언트 헤더 주머니 명세 상에 반드시 실어 내보내는 **헤더 포워딩(Header Forwarding) 로직을 소스 코드 내에 무조건 탑재 보장**해 주어야만 파국적 추적 단절(Disconnected Traces) 현상을 미연에 완벽 방어할 수 있습니다!

현재 우리 메시 환경이 Zipkin 호환용 B3 포맷 헤더(`x-b3-traceid` 등)를 사용하는 중인지, 아니면 최신 표준 OpenTelemetry 규격인 W3C 포맷 헤더(`traceparent` 등)를 추종하는 중인지는 이스티오 전역 설정 맵의 `extensionProviders` 명세를 스캐닝함으로써 즉시 명령검증할 수 있습니다:

<img src="images/lab4.2-tracing-fig-005.png" width="100%" alt="Figure 1.35: OpenTelemetry tracing provider in the Istio configuration map" />

---

### 오픈시프트 3대 분산 추적 관제 인터페이스 입체 분석

관제사가 상황별로 골라 가동할 수 있는 오픈시프트 웹 UI 상의 **3대 분산 추적 관제 필터 채널**의 장단점과 primary use cases를 정밀 비교 도해합니다.

#### ① 채널 A: Kiali 트래픽 토폴로지 연동 채널 (Topology-based)
* **진입로:** `Service Mesh` ➔ `Traffic Graph` 메뉴 접속 후 특정 타깃 서비스 노드를 윈클릭하고 우측 돌출 패널의 **`Traces`** 탭을 정격 활성화합니다.
* **관제 비주얼:** 특정 트레이스를 지목하는 순간, 해당 트래픽이 통과해 나간 메시 내부의 파드 노선 에지 실선들이 영롱한 **하늘색 굵은 실선으로 라이브 가시화**되어 흐르는 장관을 감상할 수 있습니다!
* **실무 수립 사용처:** 메시 내부의 물리적 통신 우회 가중 노선 경로와 mTLS 차단 지점의 범위를 공간 거시적 관점에서 한눈에 스캐닝하고자 할 때 최고 조도의 가치를 선사합니다.

<img src="images/lab4.2-tracing-fig-006.png" width="100%" alt="Figure 1.36: Traffic graph after clicking a service node" />
<img src="images/lab4.2-tracing-fig-007.png" width="100%" alt="Figure 1.37: The service detail panel containing the trace subpanel" />

#### ② 채널 B: 전역 Observe ➔ Traces 대시보드 채널 (Cluster-wide)
* **진입로:** 오픈시프트 개발자 관점 왼쪽의 **`Observe`** 메뉴 ➔ **`Traces`** 메뉴를 전격 노크합니다.
* **관제 비주얼:** 클러스터 전역에서 모아들이는 Tempo 백엔드의 전체 시계열 덤프 차트와 에러 분포 산포도(Scatter Plot) 차트를 실시간 표출합니다.
* **실무 수립 사용처:** 특정 네임스페이스와 상관없이, 현재 전역 클러스터 내에서 에러를 뿜고 있거나 레이턴시 기준 한계점을 심각히 돌파 이탈 중인 아웃라이어 트레이스 표본만을 고속 필터링 검색 발굴해 내고자 할 때 가장 효과적입니다.

<img src="images/lab4.2-tracing-fig-008.png" width="100%" alt="Figure 1.38: Observe traces view in OpenShift console" />
<img src="images/lab4.2-tracing-fig-009.png" width="100%" alt="Figure 1.39: Span hierarchy and timing details view" />

#### ③ 채널 C: 워크로드 상세 Service Mesh 탭 채널 (Workload-centric)
* **진입로:** 오픈시프트 `Workloads` ➔ `Deployments` 진입 후 특정 배포본 상세 창 우측 최상단의 **`Service Mesh`** 전용 서브 탭을 전격 클릭합니다.
* **관제 비주얼:** 해당 특정 마이크로서비스 파드가 직접 수·발신 처리했던 L7 동시 유량 트래픽 통계와 분산 추적 타임라인 차트를 한 브라우저 화면 상에 정밀 매칭 결합 전시합니다.
* **실무 수립 사용처:** 특정 마이크로서비스 개발팀 소관 장비 전용으로 격리 튜닝 분석 및 서킷 브레이커 감금 파드의 레이턴시 복구 시점을 밀착 포착하고자 할 때 최고의 정합 밀착 관제력을 보여줍니다.

<img src="images/lab4.2-tracing-fig-010.png" width="100%" alt="Figure 1.40: Service mesh tab in an OpenShift resource" />
<img src="images/lab4.2-tracing-fig-011.png" width="100%" alt="Figure 1.41: Traces tab view in a deployment resource" />

---

### 3대 분산 추적 관제 인터페이스 비교 요약 테이블

| **시각 인터페이스 (Visualization)** | **최고 조도 관제 스코프 (Best For)** | **실무 핵심 기동 사례 (Primary Use Cases)** |
| :--- | :--- | :--- |
| **Traffic Graph (Kiali 토폴로지)** | 메시 전역 트래픽 우회 공간 기하 관제 | mTLS 보안 유실 지점 색출, 라우팅 룰 이탈 검출, 병목 컴포넌트 거시 스캐닝 |
| **Observe Menu (오픈시프트 전역)** | 클러스터 단위 대량 트레이스 산포 집계 | 전역 에러 필터링 검색, 장기 시계열 히스토그램 대조, 성능 이상 아웃라이어 발굴 |
| **Workload Tab (상세 Service Mesh)** | 특정 마이크로서비스 한정 심층 미세 관제 | 특정 파드 단위 미세 레이턴시 소모 계산, 수·발신 통신 비율과 트레이스의 실시간 교차 대조 |

---

### 수립된 메트릭 지표와 트레이스의 상관정합 분석 기법 (Correlating Metrics and Traces)

오픈시프트 전산 웹 콘솔은 메트릭 통계 곡선과 트레이스 타임라인을 긴밀히 하나의 화면에 상호 교차 매칭해 전시하는 정합 분석 기조를 기본 선사합니다:
* **토폴로지 맵(Kiali):** 전역 트래픽의 호출 경로와 실시간 서비스 간 상호 의존 관계(Topology)를 매끄럽게 모니터링합니다.
* **메트릭 차트(Prometheus):** 병목 발생 마이크로서비스 노드가 뿜어내는 수발신 평균 트래픽 수치 편동을 실시간 감상합니다.
* **분산 트레이스(Tempo/OTel):** 해당 특정 결락 시점에 유입 소멸되었던 트랜잭션 개별 단 건의 심층 타임라인 계층 바와 오류 원장(Error logs)을 정교하게 분석합니다.

이 입체적 상관분석 조율을 통해 관제사는 다음 **5대 핵심 프로덕션 트러블슈팅 과제**를 손쉽게 소화할 수 있게 됩니다:
1. "우리 시스템의 전체적인 레이턴시 병목 및 성능 저하를 수반시키는 핵심 장벽 마이크로서비스가 어디인가?" ➔ **[즉석 진단 규명 가능!]**
2. "왜 특정 사용자의 API 콜이 평소보다 수십 배 지체 소요되고 있는가?" ➔ **[구간별 지체 시간 분석 완수!]**
3. "호출 실패 요청이 터지는 시점에 정확한 서비스 간의 다단식 상호 시퀀스 노선이 어떻게 수립되어 있는가?" ➔ **[전사적 트랙 추적 완수!]**
4. "실제 에러가 터지고 있는 L7 파이트 라인(Request Path) 상의 예외 크래시 덤프 로그가 무엇인가?" ➔ **[로그와 스팬의 정밀 결합 결착!]**
5. "특정 마이크로서비스의 L7 라우팅 가중치(Canary) 및 서킷 격리 설정이 실제 트랜잭션 수치에 어떤 물리적 부작용을 끼쳤는가?" ➔ **[인프라 셋업 변화 평가 완수!]**

---

### 연관 기술 참고 자료 (REFERENCES)

* [Red Hat OpenShift: Distributed Tracing guide](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html-single/distributed_tracing/index) <i class="fas fa-external-link-alt"></i>
* [Red Hat OpenShift: Installing the Distributed Tracing Platform](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html-single/distributed_tracing/index#distr-tracing-tempo-installing) <i class="fas fa-external-link-alt"></i>
* [Red Hat OpenShift Service Mesh: Distributed Tracing and Service Mesh chapter in the Observability guide](https://docs.redhat.com/en/documentation/red_hat_openshift_service_mesh/3.1/html-single/observability/index#ossm-distr-tracing) <i class="fas fa-external-link-alt"></i>
* [Red Hat Developers: The Path to Distributed Tracing - an OpenShift Observability Adventure](https://www.redhat.com/en/blog/the-path-to-distributed-tracing-an-openshift-observability-adventure) <i class="fas fa-external-link-alt"></i>
* [Red Hat Developers: The path to distributed tracing - an OpenShift Observability adventure part II - A twist in the myth](https://www.redhat.com/en/blog/path-distributed-tracing-openshift-observability-adventure-part-ii-twist-myth) <i class="fas fa-external-link-alt"></i>
* [Red Hat Developers: The Path to Distributed Tracing - a Red Hat OpenShift Observability Adventure part 3 Building the bridge](https://www.redhat.com/en/blog/the-path-to-distributed-tracing-part-3-building-the-bridge) <i class="fas fa-external-link-alt"></i>
* [Quarkus: Using OpenTelemetry Tracing Quarkus Guide](https://quarkus.io/guides/opentelemetry-tracing) <i class="fas fa-external-link-alt"></i>
* [OpenTelemetry.io: Getting Started Node.js OpenTelemetry Guide](https://opentelemetry.io/docs/languages/js/instrumentation/) <i class="fas fa-external-link-alt"></i>
* [OpenTelemetry.io: Getting Started Python OpenTelemetry Guide](https://opentelemetry.io/docs/languages/python/getting-started/) <i class="fas fa-external-link-alt"></i>
* [OpenTelemetry.io: Getting Started Go OpenTelemetry Guide](https://opentelemetry.io/docs/languages/go/getting-started/) <i class="fas fa-external-link-alt"></i>
