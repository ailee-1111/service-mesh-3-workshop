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

## Collecting Service(서비스) Metrics(메트릭)

### 학습 목표 (Objectives)
* 애플리케이션 계측(instrumenting)을 위한 Prometheus 메트릭 유형과 그 사용 사례를 파악합니다.
* Node.js 및 Java Quarkus 애플리케이션을 계측하여 사용자 지정 메트릭을 노출(expose)하는 방법을 설명합니다.
* OpenShift 서비스 모니터(service monitor) 리소스가 애플리케이션 메트릭을 OpenShift 사용자 워크로드 모니터링(user workload monitoring)과 통합하는 방법을 설명합니다.
* PromQL 및 OpenShift 웹 콘솔을 사용하여 서비스 메시 및 사용자 지정 애플리케이션 메트릭을 쿼리하고 시각화합니다.

---

### Collecting Service(서비스) Metrics(메트릭) 개요

옵저버빌리티(Observability)는 서비스 메시 하에서 분산 애플리케이션을 운영하고 트러블슈팅하는 데 필수적입니다. 메트릭(Metrics(메트릭))은 서비스 건전성, 성능 및 동작에 대한 정량적 데이터(quantitative data)를 제공하여, 문제를 탐지하고 성능을 최적화하며 신뢰할 수 있는 서비스를 전달할 수 있도록 보장합니다.

이번 강의에서는 애플리케이션을 계측하여 사용자 지정 메트릭을 노출하는 방법, 해당 메트릭을 수집하도록 OpenShift 모니터링을 구성하는 방법, 그리고 OpenShift 웹 콘솔을 사용해 메트릭 데이터를 쿼리하는 방법을 학습합니다. Node.js 및 Java 애플리케이션에 대한 메트릭 계측을 모두 탐구하고, 서비스 모니터(service monitor) 리소스의 역할을 이해하며, 서비스 동작을 분석하기 위한 Prometheus 쿼리를 작성하는 실습을 진행합니다.

메트릭은 Prometheus가 시간이 지나면서 수집하는 숫자 측정값(numerical measurements)으로, 애플리케이션 및 인프라 성능, 건전성 및 동작을 파악하는 데 도움을 줍니다. 서비스 메시 환경에서 메트릭은 메시 내 모든 서비스에 대한 요청 트래픽, 레이턴시, 에러율 및 리소스 사용량에 대한 가시성을 제공합니다.

Red Hat OpenShift Service Mesh는 종합적인 메트릭 수집 및 시각화 능력을 제공하기 위해 OpenShift 모니터링 스택과 통합 연동됩니다.

---

### OpenShift 에서의 메트릭 (Metrics(메트릭) in OpenShift)

OpenShift는 두 가지 유형의 모니터링을 제공합니다:

* **Platform monitoring (플랫폼 모니터링):**
  노드, 제어 평면 서비스 및 클러스터 오퍼레이터들과 같은 클러스터 인프라 구성 요소로부터 메트릭을 수집합니다. OpenShift는 기본적으로 이 모니터링을 활성화하며 클러스터 관리자가 이를 전담 관리합니다.
* **User workload monitoring (사용자 워크로드 모니터링):**
  사용자 애플리케이션 및 네임스페이스로부터 메트릭을 수집합니다. 클러스터 관리자가 이 기능을 활성화하면, 여러분만의 자체 워크로드 및 사용자 지정 애플리케이션 메트릭을 모니터링할 수 있게 됩니다.

오픈시프트 클러스터 관리자가 사용자 워크로드 모니터링을 활성화하면, 다음과 같은 표준 컨테이너 및 워크로드 메트릭을 쿼리 조회할 수 있습니다:
* CPU 사용량: `container_cpu_usage_seconds_total`
* 메모리 사용량: `container_memory_working_set_bytes`
* 컨테이너 재시작 횟수: `kube_pod_container_status_restarts_total`
* 디플로이먼트 복제본 한도: `kube_deployment_status_replicas`

일반 사용자가 메트릭을 조회하는 데 필요한 역할 기반 액세스 제어(RBAC) 구성에 대한 자세한 정보는 참고 자료 섹션을 참조하십시오.

---

### 서비스 메시 메트릭 (Service Mesh Metrics(메트릭))

서비스 메시에 네임스페이스를 통합 편입시키는 순간, Envoy 사이드카 프록시들은 메시를 통해 흐르는 네트워크 트래픽에 대한 메트릭을 무설정 자동으로 수집하여 방출하기 시작합니다.

이 수집 메트릭 지표 목록은 다음과 같습니다:
* `istio_requests_total`: 서비스에 도달한 총 누적 요청 횟수.
* `istio_request_duration_seconds`: 요청을 백엔드가 인계받아 완전히 처리 소요한 레이턴시 시간.
* `istio_request_bytes`: HTTP 요청 바디(Request Body)의 데이터 물리 크기.
* `istio_response_bytes`: HTTP 응답 바디(Response Body)의 데이터 물리 크기.

서비스 메시 메트릭은 다음과 같이 다양한 차원으로 데이터를 필터링하고 집계(aggregate)할 수 있게 도와주는 라벨(labels) 주머니 지표를 상시 품고 가동됩니다:
* 소스(Source) 및 목적지(Destination) 워크로드 명세
* HTTP 응답 상태 코드 (Response Code)
* 사용 요청 통신 프로토콜 (HTTP, gRPC, TCP 등)
* 타깃 서비스 subsets 버전 레이벨

이 라벨 지표들을 활용하면 "invoices 서비스의 에러율이 현재 몇 %인가?" 또는 "stock 서비스의 버전 2로 향하는 요청들의 95% 분위수(95th percentile) 지연 속도가 얼마인가?" 와 같은 심층적인 관제 쿼리 질문에 대해 명쾌한 통계 답변을 얻을 수 있습니다.

---

### Prometheus 메트릭 유형

Prometheus는 네 가지 핵심 메트릭 유형을 정의하고 있습니다. 애플리케이션을 올바르게 계측(instrumenting)하려면 이 유형들의 거동 원리를 정밀하게 파악하고 있어야 합니다:

* **Counter (카운터):**
  시간이 지남에 따라 오직 우상향 누적 증가만 하거나, 파드 재시작 시점에만 0으로 초기화 리셋되는 누적 집계 메트릭 규격입니다. 처리 완료된 누적 요청수, 감지된 에러 횟수, 또는 완료된 비즈니스 타스크 수량과 같이 상시 수치가 불어나는 지표에 전폭 매립 활용합니다.
* **Gauge (게이지):**
  시간의 유동에 따라 실시간으로 자유롭게 늘어나거나 줄어들며 진동하는 변동 메트릭 규격입니다. 현재 사용 중인 메모리 소모 수치, 활성화된 동시 커넥션 개수, 큐 보관 깊이(Queue Depth) 또는 현재 가동 온도 데이터 등과 같이 상시 등락 변동하는 값에 대입 셋업 합니다.
* **Histogram (히스토그램):**
  소요 시간이나 응답 패킷 크기 같은 관측 명세값들을 사전 정의된 특정 경계 범위(Bucket) 안에 실시간 스택 정렬해 모으는 입체적 메트릭 규격입니다. cluster monitoring operator는 Red Hat에서 제공하는 프로메테우스 오퍼레이터의 분위수(Quantiles) 또는 백분위수(Percentiles) 연산 해석을 위해 이 히스토그램 버킷 데이터를 스캐닝 활용합니다.
* **Summary (요약 지표):**
  히스토그램과 유사하게 응답 분산값을 수렴해 분위수를 산출하지만, 서버 쿼리 타임에 분위수 연산을 소화하는 히스토그램과 달리 클라이언트 SDK 라이브러리 단에서 연산을 전담 선행 처리해 보관하는 특성을 띱니다. 현대 프로메테우스 모니터링 스택 설계 구조 하에서는 보다 가치 있는 다단 집계를 유연히 이송 지원하는 히스토그램의 사용을 적극 지향 권장합니다.

<img src="images/lab4.3-fig-024.png" width="100%" alt="Figure 1.24: Prometheus metrics types" />

커스텀 메트릭을 개설 장착할 때는 비즈니스 요구 해결 시나리오에 부합하는 정격 유형을 골라 매립하십시오. 단순 이벤트 빈도 측정 시에는 카운터(counter), 시시각각 편동하는 현재 수치 측정 시에는 게이지(gauge), 전체적인 분포 산포도 계산 시에는 히스토그램(histogram)을 사용합니다.

---

### Prometheus 메트릭을 사용한 Node.js 애플리케이션 계측 가이드

마이크로서비스로부터 메트릭을 유출 송출하는 구체적인 수단은 개발 언어 환경에 따라 제각각 다릅니다. 이 장에서는 자바스크립트 Node.js 및 자바 Quarkus 환경 하에서 어떻게 메트릭을 연동 수립하는지 그 이론 설계를 고찰합니다.

Node.js 애플리케이션에서 사용자 지정 메트릭을 수집하려면, 자바스크립트 전용 공식 프로메테우스 클라이언트 패키지인 **`prom-client`** 라이브러리에 의존해야 합니다.

먼저, `package.json` 파일을 열어 해당 의존 라이브러리 사양이 npm 빌드 패키지 상에 정상 장착 등록되어 구동 중인지 검수합니다:

```bash
[user@host ~]$ npm install prom-client
```

의존성이 준비되면, 비즈니스 애플리케이션 메인 엔트리 소스 코드 상단에 모듈을 정식 임포트(require) 하고 다른 이기종 앱들의 메트릭과의 전산 충돌을 방어하기 위해 고유 접두 필터(`prefix`) 키값을 장착 기동 이식합니다:

```javascript
const prometheus = require('prom-client');
const prefix = 'invoices_svc';
prometheus.collectDefaultMetrics({ prefix });
```

`collectDefaultMetrics()` 기능 선언은 노드제이에스 가동 프로세스의 순수 내부 CPU 사용 추이, 가비지 콜렉터 메모리 적체율, 이벤트 루프 지연 주기 등 런타임 성능 지표 전체를 `invoices_svc_` 접두사를 부착한 채 백그라운드로 안전하게 자동 집계 송출을 전개해 줍니다.

#### 1) 커스텀 Counter (카운터) 메트릭 선언 및 증량 예시
카운터는 계속 위로 우상향 증가만 감행하는 누적 집계에 전격 이식 선언합니다. 아래 코드는 청구서가 발행 완료된 누적 수치를 집계 추적하기 위해 카운터 변수를 수립 매립하는 모습입니다:

```javascript
const invoices_num = new prometheus.Counter({
  name: 'invoices_svc:invoices_count',
  help: 'Number of created invoices'
});
```

비즈니스 이벤트가 무사 격발 성료 되었을 때, 증량 트리거를 걸어 카운터 수치를 누적 증가시킵니다:

```javascript
invoices_num.inc();    // 누적 수치 1개 증가
invoices_num.inc(5);   // 누적 수치 5개 강제 가중 증가
```

#### 2) 커스텀 Gauge (게이지) 메트릭 선언 및 레이턴시 측정 예시
게이지 지표는 실시간 진동 편동하는 값이나 응답 레이턴시 측정 타임라인에 장착 수립합니다. 아래 코드는 청구서 발행 연산 동작에 소요된 지연 임계 타임라인을 미세 프로파일링하기 위해 게이지 변수를 선언하는 모습입니다:

```javascript
const responseTime = new prometheus.Gauge({
  name: 'invoices_svc:invoices_creation_time',
  help: 'Time taken in seconds to create an invoice'
});
```

`prom-client` 가 제공하는 고성능 자율 타이머 연동 제어 메소드를 결합하여 라우팅 처리 내부 구간에 타이머 시작 및 종료 end 선언부를 안전하게 이식합니다:

```javascript
app.get('/create_invoice', async function (req, res) {
  responseTime.setToCurrentTime();
  const end = responseTime.startTimer(); ❶
  
  // 비즈니스 처리 처리 로직 기동
  await processRequest();
  
  end(); ❷ // 타이머 소요 시간을 자동으로 감지해 게이지 값으로 완전 각인 성료
  res.send(response);
});
```

❶ 응답 처리 시작 지점에 타이머 측정 객체(`end` 매핑) 작동을 즉각 기동 개시시킵니다.
❷ 처리가 무사 완료된 응답 출력 직전 시점에, 작동 종료(`end()`)를 최종 선언하여 소요 레이턴시를 물리 초(Seconds) 규격 데이터로 게이지에 즉시 축적 보관합니다.

#### 3) 프로메테우스 원격 수집 엔드포인트 `/metrics` 리스너 개설
프로메테우스 스크래퍼가 주기적으로 안전하게 데이터를 긁어갈 수 있도록, 수발신용 L7 경로 API 리스너를 개방 설계 매립해 줍니다:

```javascript
app.get('/metrics', async function (req, res) {
  res.set('Content-Type', prometheus.register.contentType);
  res.send(await prometheus.register.metrics());
});
```

이 경로 통로는 프로메테우스가 요구하는 표준 텍스트 포맷 양식에 완벽히 수렴하는 기성 원격 계측 명세서 원본 데이터 전체를 막힘없이 출력 렌더링 회신해 줍니다.

---

### Java Quarkus 애플리케이션에 Micrometer 라이브러리 계측 설계

자바 쿼커스 프레임워크 기반 마이크로서비스는 프로메테우스와 클라우드 옵저버빌리티 연동을 위해 벤더 독립적인 강력한 공통 파사드 인터페이스 라이브러리인 **`Micrometer`** 전용 패키지를 적극 활용 가동합니다.

오픈시프트 서비스 메시 환경 하에서 자바 쿼커스가 호환 수립할 수 있는 **3대 대표적 메트릭 계측 방식**의 세부 기능 장단점을 정밀 분석 대조합니다:

| **제어 기능 사양 (Feature)** | **SmallRye Metrics(메트릭)** | **Micrometer (마이크로미터)** | **OpenTelemetry (OTel)** |
| :--- | :--- | :--- | :--- |
| **Extension (의존 오퍼레이터)** | `quarkus-smallrye-metrics` | `quarkus-micrometer` + `quarkus-micrometer-registry-prometheus` | `quarkus-opentelemetry` |
| **Metrics(메트릭) endpoint (수집 엔드포인트)** | `/metrics` 혹은 `/q/metrics` | **`/q/metrics`** 전용 통로 개설 | 커스텀 임의 경로 튜닝 지원 (OTLP Exporter) |
| **Instrumentation style (계측 인터페이스)** | 어노테이션(Annotation) 기반 | **어노테이션 선언 및 programmatic API 양방향 혼합 지원** | 프로그래밍 API 고가용성 전용 셋업 |
| **Status (현재 기술 권장 등급)** | **Quarkus 3.x 세력 이후 정식 Deprecated 종결 정리** | **현재 자바 엔터프라이즈 실무 상의 가장 강력한 표준 권장 기조(Current Recommended)** | 차세대 완전 통합 옵저버빌리티를 향한 미래 지향 핵심 지표 |
| **Backend support (백엔드 호환 포트)** | 오직 프로메테우스만 매핑 수용 | **프로메테우스, InfluxDB, Datadog 등 다중 멀티 백엔드 동시 송출** | OTLP 프로토콜 관통 다중 백엔드 지원 |
| **Traces(추적) integration (추적 데이터 결합성)** | 지원 불가 | 독립적인 타 추적 에이전트와만 연계 연쇄 연동 가능 | **메트릭, 트레이스, 로그 3각 데이터를 완전 단일 구조로 융합 처리** |
| **Learning curve (개발 이식 장벽)** | 매우 낮음 | **매우 낮음 (선언적 어노테이션 한 줄 주입으로 성료)** | 중간 수준 (명시적인 programmatic 자바 빌더 코딩 수반) |
| **Flexibility (설정 유연성)** | 극히 협소함 | 중간 수준 | 극도로 자유롭고 세밀한 커스텀 통제 가용 |

이번 학습 과정에서는 현재 업계에서 가장 안정한 대세 기술이자 강력 추천 방식인 **`Micrometer`** 라이브러리 이식 설정을 기준으로 전산화 설계를 파악합니다.

Quarkus 애플리케이션 내부에서 Micrometer 모니터링 필터를 전격 이식 가동하기 위해, 프로젝트 의존 설계 파일인 `pom.xml` 하단에 다음 2종 패키지 디펜던시 설정을 매립합니다:

```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-micrometer</artifactId>
</dependency>
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-micrometer-registry-prometheus</artifactId>
</dependency>
```

이 확장 팩이 결착 기동되는 순간, 쿼커스 엔진은 내부 JVM 하드웨어 가동률 통계 장치와 결합 수렴하여 프로메테우스 표준 포맷 출력 엔드포인트 통로인 **`/q/metrics`**를 자동 생성하여 개방 가동합니다.

#### 1) 선언적 `@Counted` 어노테이션 장착 제어
마이크로미터가 제공하는 `@Counted` 어노테이션을 자바 비즈니스 처리 메소드 선언부 상단에 주입해 주면, 해당 API 엔드포인트가 노크되어 성공 회신될 때마다 누적 카운터를 프로메테우스 전용 `invoices_requested_total` 이름의 카운터 지표로 무설정 자율 수립하고 1개씩 자동 가산 증가시킵니다.

```java
import io.micrometer.core.annotation.Counted;

@GET
@Path("/invoice")
@Counted(value = "invoices_requested", description = "count of invoices requested")
public String createInvoice() {
    // 인보이스 생성 비즈니스 로직
    return "Invoice created";
}
```

메소드 호출이 아닌 내부 특정 세부 조건 제어(예: 만족도 난수 레이팅 판독 구문 등) 분기 하단에 카운터를 단독 중첩 장착할 때에도 동일하게 어노테이션 조건 수립이 가용합니다:

```java
@Counted(value = "invoice_process_rating", description = "Overall customer rating for the invoice process")
Integer getCalculatedRating() {
    return calculateRating();
}
```

#### 2) 프로그래밍 방식의 Programmatic Counter (프로그래밍 카운터) 제어
만일 어노테이션 없이 세밀한 에러 처리 조건 하위에서 성패 여부에 따라 서로 분리된 카운터(성공 카운터 대 실패 카운터) 증량을 조건부 제어하고 싶을 때에는, 자바 코드 내부에서 직접 마이크로미터의 `MeterRegistry` 빈 장치를 인젝션 받아 자율 수동 코딩 설계할 수 있습니다:

```java
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import jakarta.inject.Inject;

@Inject
MeterRegistry registry;

private Counter invoicesCreated;
private Counter invoicesFailed;

@PostConstruct
void initMetrics() {
  invoicesCreated = Counter.builder("invoices_created_total")
    .description("Total number of invoices successfully created")
    .register(registry);
    
  invoicesFailed = Counter.builder("invoices_failed_total")
    .description("Total number of failed invoice creation attempts")
    .register(registry);
}

@GET
@Path("/invoice")
public String createInvoice() {
  try {
    // 인보이스 생성 비즈니스 연산 구동
    invoicesCreated.increment(); // 성공 수치 1개 가산 증가
    return "Invoice created";
  } catch (Exception e) {
    invoicesFailed.increment(); // 실패 수치 1개 가산 증가
    return "Invoice failed";
  }
}
```

#### 3) 선언적 `@Timed` 어노테이션 장착 제어
`@Timed` 어노테이션을 자바 메소드 위에 주입 각인해 두면, 마이크로미터 엔진이 해당 메소드가 인계 시작되어 반사 종료 완료될 때까지의 물리 지속 소요 시간 정보를 1/1000초 정밀 단위로 자동 타이밍 추적하여 버킷 통계를 그려 냅니다:

```java
import io.micrometer.core.annotation.Timed;

@GET
@Path("/invoice")
@Timed(value = "invoice_process_time", description = "A measure of how long it takes to process an invoice")
public String createInvoice() {
    // 인보이스 생성 처리 로직
    return "Invoice created";
}
```

`@Timed` 필터는 기동 즉시 프로메테우스 상에 다음 삼각 편대 정밀 시계열 데이터셋을 자율 발행합니다:
* `invoice_process_time_seconds_count`: 누적 호출 횟수 통계
* `invoice_process_time_seconds_sum`: 소요 시간들의 누적 합산값
* `invoice_process_time_seconds_bucket`: 분위수 통계 산출용 히스토그램 버킷 데이터

#### 4) 다중 어노테이션 스택 중첩 결합 (Combining Multiple Annotations)
단일 자바 비즈니스 처리 엔드포인트 메소드 위에 카운터(@Counted)와 타이머(@Timed) 어노테이션 장비를 한꺼번에 중첩 체인화하여, 호출 빈도 통계와 미세 응답 지연 속도 프로파일링을 동시에 입체적으로 덤프 수집할 수 있습니다:

```java
@GET
@Path("/invoice")
@Counted(value = "invoice_creation_requested", description = "count of invoice creation requested")
@Timed(value = "invoice_process_time", description = "A measure of how long it takes to process an invoice")
public String createInvoice() {
    // 인보이스 비즈니스 처리 로직
    return "Invoice created";
}
```

---

## 4. 메트릭스 수집 수신 자산: ServiceMonitor 와 PodMonitor

오픈시프트 사용자 워크로드 프로메테우스가 클러스터 내에 가동 중인 수많은 파드들의 원격 유출 경로를 periodic 순환 탐험하여 데이터를 안전하게 스크래핑해 갈 수 있도록 지시 가이딩하는 **양대 모니터 수신 자산의 역할과 차이점**을 정밀 식별 학습합니다:

* **ServiceMonitor (서비스 모니터):**
  쿠버네티스 기성 서비스(`Service(서비스)`) 리소스의 레이벨 셀렉터 명세와 매칭 결합하여, **해당 서비스 배후 하단에 속해 구동 중인 사용자 애플리케이션 파드 컨테이너의 커스텀 수집 통로(예: `/metrics`, `/q/metrics` 엔드포인트)를 타깃 방문**하여 스크래핑하도록 프로메테우스에게 경로 가이드를 제공합니다.
* **PodMonitor (파드 모니터):**
  쿠버네티스 서비스 리소스를 거치지 않고, **개별 파드 인스턴스를 다이렉트로 추적 방문**하여 스크래핑을 실행합니다. 이스티오 서비스 메시 환경 하에서 각 파드 옆에 결합 주입된 **Envoy 프록시 전용 통계 통로(각 파드 내부의 고유 경로 `/stats/prometheus`!)를 다이렉트 주기 스캐닝**하여 메시 전역 텔레메트리 데이터(istio_requests_total 등)를 수집하는 데 주로 전담 활용됩니다.

오픈시프트 서비스 메시 모니터링 환경에서는 보통 이 양대 장비를 유기적으로 혼합 연대 배포하여 완벽한 입체 관제를 구축합니다:
* **PodMonitor:** Envoy 사이드카 프록시가 내뿜는 서비스 메시 통신 메트릭 수집을 전담.
* **ServiceMonitor:** 여러분이 소스 코드 속에 각인해 넣은 비즈니스용 커스텀 메트릭 수집을 전담.

다음 PodMonitor 예제 명세서는 이스티오 프록시들로부터 메시 전역 텔레메트리 데이터를 주기 획득하는 정식 실무 규격을 도해합니다:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-proxies-monitor
spec:
  selector:
    matchExpressions:
    - key: istio-prometheus-ignore
      operator: DoesNotExist
  podMetricsEndpoints:
  - path: /stats/prometheus
    interval: 30s
    relabelings:
    - action: keep
      sourceLabels: [meta_kubernetes_pod_container_name]
      regex: "istio-proxy"
...output omitted...
```

이 파드 모니터 자산은 **서비스 메시에 가입 가동 중인 모든 개별 네임스페이스 프로젝트 하위에 무조건 각각 복제 전개 배포**되어 있어야만 해당 테넌트의 트래픽 흐름 가시성이 보장됩니다.

다음은 비즈니스 애플리케이션 파드의 커스텀 경로를 서비스 셀렉터 매치 조건과 체인하여 30초마다 긁어가도록 유도 결합하는 정식 서비스 모니터 YAML 명세서입니다:

```yaml
apiVersion: monitoring.coreos.com/v1 ❶
kind: ServiceMonitor
metadata:
  name: invoices-monitor
  namespace: my-project
spec:
  endpoints:
  - interval: 30s ❷
    path: /metrics ❸
    scheme: http ❹
    targetPort: 8080 ❺
  selector:
    matchLabels:
      app: invoices ❻
```

❶ 만일 클러스터 어드민이 플랫폼 기본 스택이 아닌 커스텀 오퍼레이터 독립형 모니터링을 구동 중인 시나리오 환경이라면, 본 API 주소를 `monitoring.observability.openshift.io/v1alpha1` 규격으로 정교하게 튜닝 선언해야 합니다.
❷ 메트릭 지표를 스크래핑해 갈 수집 주기 간격을 명시 선언합니다 (보통 **30초** 간격 설정이 가장 널리 배포 쓰입니다).
❸ 스크래핑을 위해 노크할 타깃 URI 경로를 셋업 합니다 (자바 쿼커스의 경우에는 이 경로를 `/q/metrics`로 변경 이식합니다).
❹ 보안 SSL 암호화 협상이 개입되지 않은 일반 HTTP 평문 텔레메트리 덤프 전송 규격을 수립합니다.
❺ 비즈니스 파드가 실제 귀를 열고 대기 구동 중인 비즈니스 수신용 컨테이너 포트 번호를 지정해 줍니다 (Envoy 프록시 전용 포트 주소가 아님에 정밀 주의!).
❻ 매칭 결착할 쿠버네티스 기성 서비스의 레이벨 셀렉터 식별키 주소를 각인합니다.

---

### 오픈시프트 웹 관제 대시보드를 통한 PromQL 쿼리 가동 요령

오픈시프트 개발자 콘솔의 **`Observe(관찰)` ➔ `Metrics(메트릭)`** 메뉴창을 노크하여, 프로메테우스가 엄격하게 실시간 수집 축적 보관 중인 시계열 원장들을 PromQL 쿼리를 동원해 차트로 뽑아 감상할 수 있습니다.

<img src="images/lab4.3-fig-026.png" width="100%" alt="Figure 1.26: The metrics tab in the Observe(관찰) menu" />

오픈시프트 웹 관제 대시보드가 선사하는 **5대 관제 필터 기능**:
* **Expression Query Interface:** PromQL 수식을 수동 입력하고 `Run queries` 버튼을 눌러 즉석 실시간 그래프 렌더링.
* **Time Range Controls:** 분석하고자 하는 과거 윈도우 시간대 영역(예: 30분, 1시간, 12시간 등)을 자유롭게 조율.
* **Graph & Table Views:** 차트 그래프 선 시각화 뷰와 순수 텍스트 테이블 로우 데이터를 단 한 번의 탭 스위칭으로 교차 대조.
* **Multiple Query Series:** 단일 그래프 차트 화면 위에 서로 다른 이기종 서비스 수식 쿼리들을 다단으로 중첩 추가(`Add Query` 단추 활용)하여 상호 변동 추이를 완벽 비교 분석.
* **Resolution Controls:** 쿼리 수집의 데이터 해상도 간격을 상황에 맞춰 조율.

실무 운영 전선에서 상시 격발되어 가동 중인 **6대 핵심 PromQL 관제 가이드 수식**:

#### ① 1순위: 특정 메트릭의 가용 파드 전역 단순 누적 수치 획득
* 누적 카운터 지표의 현재 집계 총합 상태를 단순히 검수할 때 사용합니다.
```sql
invoices_svc:invoices_count
```

#### ② 2순위: 특정 레이벨 속성을 지닌 마이크로서비스 호출 건수 필터링 스캐닝
* 중괄호`{}` 조건식을 매립하여, 특정 백엔드 목적지(`destination_workload="stock"`)로 향한 통신 횟수만 한정 필터링 조회합니다.
```sql
istio_requests_total{destination_workload="stock"}
```

#### ③ 3순위: 카운터 지표의 시간 범위 변동량(RPS: 초당 처리 횟수) 정밀 계산
* 카운터는 숫자가 계속 불어나므로 반드시 **`rate()`** 함수와 시간 범위 벡터 필터(`[5m]`)를 주입하여, 최근 5분 평균 초당 트래픽 처리 변화량을 실착 산출해야만 올바른 RPS 관제가 가능해집니다.
```sql
rate(istio_requests_total{reporter="source"}[5m])
```

#### ④ 4순위: 자바 애플리케이션의 커스텀 청구서 발행 속도(RPS) 동적 계산
* 마이크로미터 SDK에 의해 자동 꼬리 딱지 접미사(`_total`)가 각인된 커스텀 메트릭의 초당 처리 속도를 정교하게 유도 산출합니다.
```sql
rate(invoices_created_total[5m])
```

#### ⑤ 5순위: 분산 파드들의 개별 처리량을 목적지 워크로드별 그룹 단위로 전사 합산
* 여러 개별 파드 인스턴스로 분산되어 노크하는 트래픽 유동을 `destination_workload` 그룹 단위로 깔끔하게 전체 합산(`sum` 및 `by` 수식 결합)하여 차트에 영롱한 결합 실선으로 렌더링합니다.
```sql
sum(rate(istio_requests_total{reporter="source"}[5m])) by (destination_workload)
```

#### ⑥ 6순위: 타임아웃 레이턴시의 분위 분포 "95% 분위수 지연 속도" 정밀 계산
* 평균 지연 속도 렌더링 방식의 함정에 빠져 병목 참상을 망치지 않도록, 전체 유저 중 최악의 95% 장벽 선상에 노출된 응답 레이턴시 한계값(95th Percentile)을 정확히 산출해 냅니다.
```sql
histogram_quantile(0.95, sum by (le, destination_workload) (rate(istio_request_duration_milliseconds_bucket{reporter="source"}[5m])))
```

---

### 연관 기술 참고 자료 (REFERENCES)

* [OpenShift Container Platform: Monitoring documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html-single/monitoring/index) <i class="fas fa-external-link-alt"></i>
* [OpenShift Container Platform: Granting users permissions for monitoring for user-defined projects](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html-single/monitoring/index#granting-users-permission-to-monitor-user-defined-projects_preparing-to-configure-the-monitoring-stack-uwm) <i class="fas fa-external-link-alt"></i>
* [OpenShift Service Mesh: Metrics(메트릭) and Service Mesh chapter](https://docs.redhat.com/en/documentation/red_hat_openshift_service_mesh/3.1/html-single/observability/index#metrics-and-service-mesh) <i class="fas fa-external-link-alt"></i>
* [prom-client: Prometheus client for Node.js](https://github.com/siimon/prom-client) <i class="fas fa-external-link-alt"></i>
* [Micrometer Metrics(메트릭): Quarkus Guide](https://quarkus.io/guides/micrometer) <i class="fas fa-external-link-alt"></i>
* [OpenTelemetry: Quarkus Guide](https://quarkus.io/guides/opentelemetry) <i class="fas fa-external-link-alt"></i>
* [Red Hat Developers: How Quarkus works with OpenTelemetry on OpenShift](https://developers.redhat.com/articles/2025/07/07/how-quarkus-works-opentelemetry-openshift) <i class="fas fa-external-link-alt"></i>
* [Red Hat Customer Portal: How to use Prometheus Query Language (PromQL) in OpenShift](https://access.redhat.com/articles/7067755) <i class="fas fa-external-link-alt"></i>
