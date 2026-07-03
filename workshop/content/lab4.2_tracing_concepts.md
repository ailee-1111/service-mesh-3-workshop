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

성능 문제를 해결하는 것은 분산 시스템의 유지 관리 및 개발에 있어 매우 중요합니다. 단일 클라이언트 호출이 여러 서비스와 상호 작용할 수 있기 때문에, 개별 서비스의 디버깅 로그를 개별 분석하는 것만으로는 성능 문제를 해결하는 데 도움이 되지 않을 수 있습니다.

분산 추적은 개발자가 분산 애플리케이션의 호출 흐름을 시각화할 수 있도록 지원합니다. 호출의 순서, 직렬로 발생하는 호출 수와 병렬로 발생하는 호출 수의 파악, 그리고 레이턴시(지연 시간)의 발생 원인을 파악하는 것은 분산 시스템을 유지 관리할 때 유용합니다.

예를 들어, 요청 처리 시간이 너무 길어 성능 문제가 발생하는 경우, 속도 저하를 유발하는 특정 서비스나 서비스들을 식별하고 서비스 호출 간의 네트워크 레이턴시를 검사할 수 있습니다.

분산 추적은 현대적인 클라우드 네이티브 분산 애플리케이션 환경에서 서비스 간 상호 작용의 모니터링, 네트워크 프로파일링 및 문제 해결(troubleshooting)에 유용합니다.

---

### 분산 추적의 Traces와 Spans (Traces and Spans in Distributed Tracing)

분산 추적은 다음 두 가지 핵심 용어를 사용합니다:

#### Span (스팬)
스팬(Span)은 하나의 논리적인 작업 단위를 대변하며, 고유한 명칭, 시작 시간 및 실행 지속 시간(duration of execution)을 가집니다. 서비스 메시 내에서 서비스 호출 흐름은 특정 순서대로 실행되는 중첩된 스팬(nested spans)들의 모델로 표출됩니다.

#### Trace (트레이스)
트레이스(Trace)는 서비스 메시 내 서비스들의 실행 경로입니다. 하나의 트레이스는 하나 이상의 스팬들로 구성됩니다.

다음과 같은 서비스들로 구성된 애플리케이션을 검토해 보겠습니다:

<img src="images/lab4.2-tracing-fig-002.png" width="100%" alt="Figure 1.32: Request call path in an application composed of many components" />

이 예제 시나리오에서는 다음과 같은 흐름이 진행됩니다:
* `Service A`가 애플리케이션의 요청 진입점(request entry point) 역할을 맡습니다.
* `Service A`가 애플리케이션의 진입점이므로, 시스템은 이 단위를 **부모 스팬 (parent span)**이라고 부릅니다. `Service A`는 두 가지 서비스 호출을 수행하는데, 하나는 `Service B`로의 호출이고 다른 하나는 `Service E`로의 호출입니다. 따라서 `Service B`와 `Service E`는 `Service A` 배후 하위에 속한 **자식 스팬 (child spans)**이 됩니다.
* `Service B`는 다시 `Service A`로 최종 응답을 회신하여 돌려보내기 전에 `Service C`와 `Service D`를 순차 호출합니다. 이 경우 `Service B`가 부모 스팬 역할을 수행하게 되며, `Service C`와 `Service D`가 이 `Service B` 하위의 자식 스팬이 됩니다.

아래 다이어그램 차트 명세는 동일한 단일 트레이스와 이를 지탱하는 구성 스팬들의 시간 분포 계층 바(Horizontal Bars) 그래픽 형상입니다:

<img src="images/lab4.2-tracing-fig-003.png" width="100%" alt="Figure 1.33: Traces and spans" />

---

### Red Hat OpenShift 환경에서의 분산 추적 (Distributed Traces in Red Hat OpenShift)

Red Hat OpenShift Service Mesh는 OpenShift 옵저버빌리티 플랫폼을 통해 분산 추적 기능을 통합 제공합니다.

OpenShift Service Mesh 내의 분산 추적 솔루션은 다음 세 가지 핵심 컴포넌트를 상호 결합하여 작동합니다: **OpenTelemetry**, **Tempo** 및 **Kiali**.

#### OpenTelemetry
메시 내부의 서비스들로부터 추적 데이터(trace data)를 수집하는 계측 프레임워크를 제공합니다. Envoy 사이드카 프록시들은 요청이 메시를 관통하여 흐르는 과정에서 트레이스 컨텍스트 헤더 정보를 자동으로 생성하고 전파하여, 개별 서비스 상호 작용 단계마다 스팬을 생성해 줍니다.

#### Tempo
추적 데이터를 보관하고 검색 쿼리를 가동하는 분산 추적 백엔드 역할을 담당합니다. 클라우드 네이티브 기반 추적 시스템인 Tempo는 대용량의 추적 데이터를 효율적으로 처리하며 OpenShift 옵저버빌리티 스택과 매끄럽게 통합됩니다. Tempo는 메시 전역에 배포된 OpenTelemetry 컬렉터로부터 추적 데이터를 수신하여 이를 가시화 및 분석에 활용할 수 있게 제공합니다.

#### Kiali
OpenShift Service Mesh 하위에서 분산 추적을 감상하기 위한 기본 시각화 인터페이스를 제공합니다. Kiali는 오픈시프트 서비스 메시 콘솔 플러그인(OSSMC)을 통해, 추적 데이터를 대시보드의 트래픽 그래프 및 서비스 뷰 상에 직접 통합해 줍니다. 아울러 옵저버빌리티 오퍼레이터가 제공하는 추적 플러그인을 통해 추적 데이터를 조회하고 분석할 수 있는 대체 인터페이스를 제공합니다. 이러한 시각화 인터페이스들을 통해 단일 화면 상에서 토폴로지, 메트릭, 그리고 트레이스를 상호 연계 분석하여 애플리케이션의 거동과 성능에 대한 전반적인 뷰를 파악할 수 있게 됩니다.

---

### OpenShift 및 OpenShift Service Mesh 상의 분산 추적 구성 요소

<img src="images/lab4.2-tracing-fig-004.png" width="100%" alt="Figure 1.34: Components for distributed tracing on OpenShift and OpenShift Service Mesh" />

오픈시프트 및 오픈시프트 서비스 메시 전역 상에 분산 추적 시스템을 설치 구성하는 세부 원리는 참고 자료 가이드를 참조하십시오.

---

### OpenShift Service Mesh 의 계측(Instrumentation) 옵션

OpenShift Service Mesh는 비즈니스 애플리케이션의 소스 코드를 변경할 필요 없이 Envoy 사이드카 프록시를 통해 자동 분산 추적 기능을 제공합니다. Envoy 프록시는 요청이 메시를 관통하여 흐르는 과정에서 트레이스 컨텍스트 헤더를 자동으로 생성 및 전파하여, 서비스 간 상호 호출 단계마다 스팬을 자동으로 형성시킵니다. 이 자동화된 계측은 서비스 토폴로지, 네트워크 레이턴시 및 L7 HTTP 수준의 요청 흐름에 대한 즉각적인 가시성을 제공합니다.

자동화된 분산 추적 기능을 구동하기 위해 다음 구성 요소가 필요합니다:
* 설치 및 구성 완료된 **Tempo Operator**.
* Cluster Observability 오퍼레이터가 제공하는 **Distributed Tracing UI 플러그인**.
* 각 서비스 프로젝트 네임스페이스 위에 각인된 **`istio-injection=enabled`** 레이벨.
* 각 네임스페이스 하위에 배포되어 Envoy 프록시들로부터 메트릭을 스캐닝해 가는 **`PodMonitor`** 모니터링 리소스.

그러나, Envoy 프록시 수준에서 수집하는 자동 추적 방식은 서비스 간의 네트워크 레벨 스팬 정보만을 획득합니다. 마이크로서비스 내부에서 발생하는 정밀 연산 지연(예: 데이터베이스 쿼리 조회, 내부 비즈니스 로직, 또는 커스텀 연산 등) 정보까지 깊이 파고드는 가시성을 확보하기 위해서는, **OpenTelemetry API를 애플리케이션 소스 코드 내에 주입하는 애플리케이션 레벨의 계측(Application-level Instrumentation)** 장치가 수반되어야 합니다.

애플리케이션 계측은 내부 연산을 위한 추가적인 스팬을 생성하고, 주문 ID나 사용자 정보 등 비즈니스 컨텍스트 속성을 추가하며, 특정 에러 및 성능 지표를 감지할 수 있게 지원하여 Envoy가 제공하는 자동 추적 방식을 보완합니다. 

가령, 전자상거래 애플리케이션의 결제 checkout 트랜잭션을 예시로 들겠습니다. 기본 계측 처리 하위에서는 단지 하나의 서비스가 다른 서비스를 호출했고 처리하는 데 걸린 전체 지속 시간 정보만 표시됩니다:

```bash
frontend ➔ checkout-service (234ms total)
```

만일 애플리케이션 레벨 계측이 주입되어 있는 경우, 우리는 내부 연산 경로에 대한 구체적인 세부 정보 조각들을 추가로 감상할 수 있게 됩니다:

```
frontend ➔ checkout-service (234ms total)
 ├─ validateCart (5ms)
 ├─ checkInventory (180ms)
 │   └─ database.query (175ms)
 ├─ calculateTax (10ms)
 ├─ processPayment (35ms)
 │   └─ stripeAPI.charge (30ms)
 └─ createOrder (4ms)
```

위의 예제를 통해, 데이터베이스 쿼리 조회가 해당 트레이스 상에서 가장 많은 소요 지연 시간(또는 스팬)을 차지하는 핵심 병목 구간임을 명쾌하게 진단해 낼 수 있게 됩니다.

OpenTelemetry는 애플리케이션 계측을 위해 **자동 계측(Automatic instrumentation)**과 **수동 계측(Manual instrumentation)** 두 가지 방식을 제공합니다.

#### 자동 계측 (Automatic instrumentation)
소스 코드 변경을 최소화하고 HTTP 클라이언트, 데이터베이스 드라이버, 메시지 큐, 캐시 시스템 등 자주 사용되는 표준 라이브러리 및 프레임워크를 자동으로 계측하는 언어별 런타임 에이전트를 가동합니다. OpenTelemetry 진영에서는 이를 **제로 코드 계측 (Zero-code instrumentation)**이라 명명합니다. 주요 지원 라이브러리 에이전트 목록은 다음과 같습니다:
* Java Quarkus: `quarkus-opentelemetry` 공식 확장 라이브러리
* Node.js: `@opentelemetry` Node.js용 메타패키지
* Python: `opentelemetry-distro` 파이썬 패키지
* Go: `OpenTelemetry-Go` 공식 구현 패키지

가령, Node.js 애플리케이션 환경 하에 자동 계측 에이전트 필터를 주입하고자 할 때는 다음과 같은 패키지 빌드 및 실행 쉘 환경 변수 명세 조합을 활용하여 코드를 손대지 않고 구동시킬 수 있습니다:

```bash
[user@host application-src]$ npm install --save @opentelemetry/api
[user@host application-src]$ npm install --save @opentelemetry/auto-instrumentations-node
[user@host application-src]$ env OTEL_TRACES_EXPORTER=otlp OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=opentelemetry-endpoint \
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

#### 수동 계측 (Manual instrumentation)
소스 코드 내부 영역에 직접 OpenTelemetry API 명세를 임포트 주입하고, 커스텀 스팬 생성 구문(`tracer.startActiveSpan(...)`)과 속성을 개발자 수동으로 설계 타이핑하여 통제하는 고정밀 통제 방식입니다. 가상 서비스가 제공하는 비즈니스 핵심 동작 경로에 대해 가장 세분화된 지연 포렌식 관제력을 가집니다. 단, 수동 기입 변경 비용 소모가 필요합니다.

가령 Node.js 소스 코드 비즈니스 연산 단락 하위에 특정 다이스 롤 횟수 연산 구간의 세부 레이턴시를 측정할 수동 커스텀 스팬을 형성하고자 할 때는 다음과 같은 자바스크립트 설계를 이식합니다:

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
❷ 해당 마이크로서비스 또는 수집 컴포넌트명을 식별할 수 있는 전용 트레이서 객체 인스턴스를 발급 획득합니다.
❸ 지정 이름(`rollTheDice`)을 부여한 커스텀 활성 스팬 작동을 트리거 격발시킵니다.
❹ 연산 처리가 끝난 직후 지점에, **생성했던 스팬 객체의 종료 구문(`span.end()`)을 실행 선언**해 주어야만 추적 데이터가 안전하게 기록 및 정상 배송 전송됩니다.

자동 및 수동 계측의 보다 자세한 사항은 참고 자료 섹션의 개발 프레임워크용 OpenTelemetry 가이드를 참조하십시오. 자동 및 수동 계측은 OpenShift Service Mesh가 제공하는 자동 추적 방식과 상호 조화롭게 작동하여, 네트워크 서비스 호출 유동과 하위 세부 애플리케이션 작업 처리가 한 타임라인 바 선상에 병합 표출되는 전역 관제를 수립합니다.

---

### 트레이스 컨텍스트 전파 (Trace Context Propagation)

수동 계측 수립 시, 전체 요청 경로 상에 걸쳐 트레이스 컨텍스트(trace context)를 다음 마이크로서비스로 끊김 없이 배달 이송 전파해야만 합니다. 컨텍스트 전파는 서비스 간 HTTP 요청 헤더 패킷 하위에 트레이스 ID(trace IDs), 스팬 ID(span IDs) 및 부모 관계 메타 데이터를 실어 내보냄으로써, 분산 추적 백엔드가 이 개별 파편 스팬들을 단일 통합 트레이스 선으로 수렴 정합할 수 있도록 제어합니다. 만일 컨텍스트 헤더 배달에 누설 결락이 발생할 경우, 각 마이크로서비스들은 자신만의 독립 단절된 유령 트레이스를 파편화해 뿜어내어 전사적 흐름 추적이 완전히 무력화 파괴됩니다.

오픈시프트 서비스 메시 내부에 장착된 Envoy 사이드카 프록시들은 네트워크 경계선 외부 입출입 단계 상에서의 트레이스 컨텍스트 전송 제어를 자동으로 수행해 줍니다. 

**그러나, 여러분의 비즈니스 애플리케이션 내부에서 하위의 다른 마이크로서비스로 아웃바운드 HTTP 요청을 생성해 전송할 때에는, 이 헤더 정보값들을 다음 요청 헤더에 직접 복사 이송해 주는 처리를 소스 코드 내에 직접 내장 보장해야만 합니다!** 

만일 여러분의 소스 코드가 자동화 전파 능력을 갖춘 별도의 OTel 라이브러리를 가용 중이라면 자동으로 전파가 조율되지만, 그렇지 않은 고전적인 환경 하에서는 이 헤더 값들을 직접 수동 포워딩 바인딩해주어야만 합니다.

현재 우리 메시 환경이 Zipkin 호환용 B3 포맷 헤더(`x-b3-traceid`, `x-b3-spanid`, `x-b3-parentspanid`)를 사용하는 중인지, 아니면 최신 표준 OpenTelemetry 규격인 W3C 포맷 헤더(`traceparent` 및 `tracestate`)를 추종하는 중인지는 이스티오 전역 설정 맵의 `extensionProviders` 명세를 스캐닝함으로써 즉시 검증할 수 있습니다:

<img src="images/lab4.2-tracing-fig-005.png" width="100%" alt="Figure 1.35: OpenTelemetry tracing provider in the Istio configuration map" />

---

### 분산 추적 시각화 기법: 트래픽 그래프 통합 (Visualizing Traces: Traffic Graph Integration)

오픈시프트 전용 웹 콘솔은 분산 추적 결과를 감상하고 분석하기 위해 다양한 종류의 다단식 관제 인터페이스를 지원 제공합니다.

오픈시프트 웹 콘솔 상에서 제공하는 트랙 그래프(Traffic Graph) 뷰포트는 실시간 서비스 메시 트래픽 흐름 토폴로지 정보를 제공합니다. 관제사는 이 그래프 선상을 타고 들어가 특정 서비스의 분산 추적 결과를 심층 드릴다운 감상할 수 있습니다.
* **진입로:** 토폴로지 상의 특정 마이크로서비스 노드 상자를 원클릭하여 세부 디테일 정보를 띄웁니다.

<img src="images/lab4.2-tracing-fig-006.png" width="100%" alt="Figure 1.36: Traffic graph after clicking a service node" />

* 노드 상세 우측 패널 하단에 개설된 여러 가용 탭 중에서 **`Traces`** 탭을 클릭하여, 해당 서비스가 관여된 실시간 트레이스들의 리스트 정보를 조회합니다.
* 트레이스 목록 중 타깃 한 건을 클릭하는 즉시, 해당 트랜잭션 패킷이 통과해 나간 동서 통신 노선들이 그래프 맵 상에 **하늘색 굵은 실선으로 실시간 비주얼 가시화**됩니다! 또한, 우측 디테일 패널 하위로 해당 트레이스의 상세 정보 주머니를 개설해 줍니다.

<img src="images/lab4.2-tracing-fig-007.png" width="100%" alt="Figure 1.37: The service detail panel containing the trace subpanel" />

이러한 통합 비주얼 감상 기능을 통하면, 관제사는 거시적 토폴로지 맵 선상 위에서 이상 결락 및 레이턴시 병목 구간의 정확한 물리 위치를 1초 만에 포착해 내고 특정 스팬 분석 단계로 다이렉트 도달할 수 있는 극치의 옵저버빌리티를 누리게 됩니다.

---

### 분산 추적 시각화 기법: Observe ➔ Traces 전역 메뉴 (Visualizing Traces: The OpenShift Console Observe Menu)

오픈시프트 웹 콘솔은 클러스터 전역 단위의 대규모 트레이스 지표를 검색 집계하기 위해, 개발자 관점 왼쪽 탐색 창의 **`Observe ➔ Traces`** 메뉴를 제공합니다. Red Hat Observability 오퍼레이터가 이 인터페이스 화면을 정식 렌더링 구동해 줍니다.

<img src="images/lab4.2-tracing-fig-008.png" width="100%" alt="Figure 1.38: Observe traces view in OpenShift console" />

이 전역 관제 메뉴판을 통하면 다음 액션들을 고속 소화할 수 있습니다:
* **트레이스 필터링 검색 (Search and filter traces):** 서비스명, 호출 오퍼레이션 유형, 쿠키 태그, 소요 지속 시간 범위 및 특정 시간 대역 윈도우 조건을 입력하여 원하는 이상 요청 건만 콕 집어 고속 발굴해 냅니다.
* **추적 리스트 목록 감상 (View trace lists):** 클러스터 내에서 축적된 전체 트레이스 목록을 시간대 및 지체 크기 순서로 정렬하여 스캐닝합니다.
* **트레이스 분포도 프로파일링 (Analyze trace distributions):** 전체 트레이스들의 지속 시간 분포 추이를 히스토그램 산포도 차트로 시각 렌더링하여 성능 아웃라이어 파드를 실시간 색출합니다.
* **심층 트레이스 팩트 체크 (Deep-dive into specific traces):** 단 건의 트레이스를 지목 선별하여, 그 배후 하위에서 다단 격발된 모든 스팬(Span)들의 정밀 타임라인 시퀀스 계층 바를 도해 판독합니다.

<img src="images/lab4.2-tracing-fig-009.png" width="100%" alt="Figure 1.39: Span hierarchy and timing details view" />

이 상세 스팬 타임라인 차트는 다음 시각 지표를 제공합니다:
* 가로축 타임 바의 길이 규격으로 각 스팬의 순수 처리 레이턴시를 비례 시각화 표출합니다.
* 들여쓰기 트리 계층 구조로 부모 스팬과 자식 스팬 간의 하향 상속 종속 관계를 완벽히 도해합니다.
* 다단형 서비스 호출이 병렬(Parallel) 구조로 동시 처리되었는지, 아니면 직렬(Sequential) 구조로 대기 지연 처리 되었는지를 투명하게 구분해 줍니다.

---

### 분산 추적 시각화 기법: Service Mesh 및 Traces 상세 탭 (Visualizing Traces: Service Mesh Workload and Service Traces Tab)

오픈시프트 서비스 메시 콘솔 플러그인은 개발자의 파드 관리 상세 화면(Deployments, Services, StatefulSets 등) 내부에 **"Service Mesh"** 라는 고유의 정식 통합 탭을 마운트해 줍니다.

<img src="images/lab4.2-tracing-fig-010.png" width="100%" alt="Figure 1.40: Service mesh tab in an OpenShift resource" />

이 서비스 메시 상세 탭 안에는 추가로 **`Traces`** 라는 고유의 분산 추적 관제 서브 메뉴 탭이 수립 기동 됩니다.

<img src="images/lab4.2-tracing-fig-011.png" width="100%" alt="Figure 1.41: Traces tab view in a deployment resource" />

개발자는 이 특정 워크로드 전용 탭 선상에서 다음 세부 분석을 집중 수행할 수 있습니다:
* **특정 워크로드 관여 트레이스 일괄 조회:** 해당 마이크로서비스 파드가 최초 인입 수신점 역할을 수행했거나 통신 선로 도중에 가입하여 처리했던 모든 전용 트레이스 목록만 격리 조회합니다.
* **수발신 방향성 필터링 (Filter by direction):** 파드로 들어온 요청 트랙인 인바운드(Inbound)와, 파드가 다른 하위 노드로 쏘아 보낸 아웃바운드(Outbound) 트레이스 노선을 스플릿 분리하여 밀착 대조합니다.
* **특정 파드 소관 성능 안착 수준 계산:** 해당 파드가 트랜잭션의 응답 지연에 기여하고 갉아먹은 순수 소요 수치를 타임라인 계층 바 대조를 통해 정밀하게 증명 계산해 냅니다.
* **에러 정밀 분석:** 에러 코드가 검출된 특정 트레이스만 필터링하여 관련 예외 로그를 결합 스캐닝합니다.
* **메트릭과의 실시간 정합 (Correlate with metrics):** 동시 처리 L7 트래픽 가동 수치 곡선 차트와 분산 추적 트레이스를 단일 화면 상에 양방향 교차 대조하여, 가중치 변화나 서킷 브레이킹 정책 적용 전후의 시스템 변동 정황을 정량적으로 완벽 증명합니다.

이 개별 워크로드 전용 탭은 다음과 같은 해결 시나리오 시 최고의 조도 검수 능력을 발휘합니다:
* 특정 신규 마이크로서비스 패치 버전에 대한 미세 레이턴시 집중 프로파일링.
* 특정 배포 워크로드가 메시 내부의 다른 이기종 파드들과 어떻게 패킷을 주고받는지 그 로직의 건전성 판독.
* L7 정책 변경 적용에 따른 개별 파드 성능 변화 추이 대조.

---

### 3대 분산 추적 관제 인터페이스 비교 분석

오픈시프트 웹 콘솔은 관제사의 상황별 문제 분석 해결 시나리오에 부합하도록 최적 개화된 3가지 서로 다른 추적 뷰포트 인터페이스를 선사합니다:

| **시각 인터페이스 (Visualization)** | **최고 조도 관제 스코프 (Best For)** | **실무 핵심 기동 사례 (Primary Use Cases)** |
| :--- | :--- | :--- |
| **Traffic Graph (Kiali 토폴로지)** | 메시 전역 트래픽 우회 공간 기하 관제 | mTLS 보안 유실 지점 색출, 라우팅 룰 이탈 검출, 병목 컴포넌트 거시 스캐닝 |
| **Observe Menu (오픈시프트 전역)** | 클러스터 단위 대량 트레이스 산포 집계 | 전역 에러 필터링 검색, 장기 시계열 히스토그램 대조, 성능 이상 아웃라이어 발굴 |
| **Service Mesh Workload Tab** | 특정 마이크로서비스 한정 심층 미세 관제 | 특정 파드 단위 미세 레이턴시 소모 계산, 수·발신 통신 비율과 트레이스의 실시간 교차 대조 |

---

### 수립된 메트릭 지표와 트레이스의 상관정합 분석 기법 (Correlating Metrics and Traces)

오픈시프트 웹 콘솔은 메트릭 통계 곡선과 트레이스 타임라인을 긴밀히 하나의 화면에 상호 교차 매칭해 전시하는 정합 분석 기조를 기본 선사합니다:
* **토폴로지 맵(Kiali):** 전역 트래픽의 호출 경로와 실시간 서비스 간 상호 의존 관계(Topology)를 매끄럽게 모니터링합니다.
* **메트릭 차트(Prometheus):** 병목 발생 마이크로서비스 노드가 뿜어내는 수발신 평균 트래픽 수치 편동을 실시간 감상합니다.
* **분산 트레이스(Tempo/OTel):** 해당 특정 결락 시점에 유입 소멸되었던 트랜잭션 개별 단 건의 심층 타임라인 계층 바와 오류 원장(Error logs)을 정교하게 분석합니다.

이 입체적 상관분석 조율을 통해 관제사는 다음 **5대 핵심 프로덕션 트러블슈팅 과제**를 손쉽게 소화할 수 있게 됩니다:
* "우리 시스템의 전체적인 레이턴시 병목 및 성능 저하를 수반시키는 핵심 장벽 마이크로서비스가 어디인가?"
* "왜 특정 사용자의 API 콜이 평소보다 수십 배 지체 소요되고 있는가?"
* "호출 실패 요청이 터지는 시점에 정확한 서비스 간의 다단식 상호 시퀀스 노선이 어떻게 수립되어 있는가?"
* "실제 에러가 터지고 있는 L7 파이트 라인(Request Path) 상의 예외 크래시 덤프 로그가 무엇인가?"
* "특정 마이크로서비스의 L7 라우팅 가중치(Canary) 및 서킷 격리 설정이 실제 트랜잭션 수치에 어떤 물리적 부작용을 끼쳤는가?"

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
