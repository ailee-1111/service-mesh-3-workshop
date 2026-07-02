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

# 모듈 2.3: Istio 서비스 회복력 (Resilience)

오픈시프트 서비스 메시를 사용하여 일시적인 네트워크 장애 및 서비스 가동 지연 현상을 극복하기 위한 타임아웃(Timeout) 및 재시도(Retry) 정책을 제어합니다. 또한 동시 연결 한계를 제한하고 가부하로부터 서비스를 안전하게 보호하기 위해 커넥션 풀링(Connection Pooling) 및 서킷 브레이커(Circuit Breaker) 설정을 완벽하게 통합 수립합니다.

## 결과 (Outcomes)
* 일시적 실패 상황 하에서 서비스의 탄력적 복구 및 우회를 증명하기 위해 타임아웃 및 재시도 조건이 포함된 장애 주입을 적용합니다.
* 가부하 및 동시 요청 폭주 상황으로부터 백엔드 마이크로서비스 노드를 안전하게 보호하기 위한 커넥션 풀링을 구성합니다.
* 비정상 상태의 비정상 서비스 인스턴스를 격리하고 시스템 전체의 연쇄 중단을 차단하기 위한 서킷 브레이커를 구성합니다.

워크스테이션 머신의 사용자 터미널에서 아래의 `lab` 명령어를 실행하여 본 실습을 위한 환경을 준비하고, 모든 필요한 리소스들이 가용하게 전개되었는지 검증 및 보장합니다:

```execute
lab start meshtraffic-resilience
```

또한, 다음 명령어를 실행하여 `$PATH` 변수를 업데이트하고 `traffic_gen.py` 명령어를 즉시 사용할 수 있도록 설정합니다. 새 환경을 생성한 후 한 번만 실행하면 됩니다.

```execute
source ~/.bashrc
```

`lab start` 명령어는 다음과 같은 작업을 수행합니다:
* `%username%-meshtraffic-resilience` 네임스페이스를 생성합니다.
* `%username%-meshtraffic-resilience` 네임스페이스를 서비스 메시에 추가합니다.
* `%username%-meshtraffic-resilience` 네임스페이스에 `ratings`와 세 가지 버전의 `reviews` 애플리케이션을 배포합니다.
* `traffic_gen.py` 스크립트가 트래픽을 생성하도록 구성합니다.
* `reviews` 서비스를 위한 초기 게이트웨이 및 가상 서비스(VirtualService) OSSM 리소스를 생성합니다.

---

## 지침 (Instructions)

### 1. 서비스 메시의 초기 상태를 확인합니다.

1.1. 새로운 터미널 창에서 `%username%` 사용자와 `openshift` 비밀번호를 사용하여 OpenShift 클러스터에 로그인한 다음, `%username%-meshtraffic-resilience` 프로젝트로 전환합니다:

```execute
oc login -u %username% -p openshift https://api.%cluster_subdomain%:6443
```

* **로그인 수행 완료 로그:**
```bash
The server uses a certificate signed by an unknown authority.
Use insecure connections? (y/n): y

WARNING: Using insecure TLS client config. Setting this option is not supported!

Logged into "https://api.%cluster_subdomain%:6443" as "%username%" using the password provided.

You have access to 78 projects.
Using project "default".
```

```execute
oc project %username%-meshtraffic-resilience
```

* **프로젝트 이동 결과 로그:**
```bash
Now using project "%username%-meshtraffic-resilience" on server "https://api.%cluster_subdomain%:6443".
```

1.2. `%username%-meshtraffic-resilience` 네임스페이스에서 애플리케이션이 실행 중인지 확인합니다.

```execute
oc get pods
```

```bash
NAME                               READY   STATUS    RESTARTS   AGE
ratings-v1-7fbfd9458-958xb         2/2     Running   0          5m
reviews-v1-7db5bd458-75tg4         2/2     Running   0          5m
reviews-v2-5bcb6d7dd-m8wdq         2/2     Running   0          5m
reviews-v3-cc8cb9b-l9lzd           2/2     Running   0          5m
```

모든 파드는 `2/2` 컨테이너가 준비된 것으로 표시되어야 하며, 이는 Istio가 Envoy 사이드카 프록시를 주입했음을 나타냅니다.

1.3. 연습 디렉토리로 이동합니다.

```execute
cd ~/labs/meshtraffic-resilience
```

1.4. 프로젝트 내에 필요한 게이트웨이 및 가상 서비스 OSSM 리소스가 존재하는지 확인합니다.

```execute
oc get gateways.networking.istio.io,virtualservices.networking.istio.io
```

```bash
NAME                                          AGE
gateway.networking.istio.io/reviews-gateway   36m

NAME                                          GATEWAYS              HOSTS   AGE
virtualservice.networking.istio.io/reviews-vs   ["reviews-gateway"]   ["*"]   36m
```

1.5. `traffic_gen.py` 스크립트를 사용하여 서비스 메시로의 외부 접속을 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 10 requests to http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
   curl -s http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
[1/10] ✅ HTTP 200 -- No stars (11.0ms)
[2/10] ✅ HTTP 200 -- black (22.8ms)
[3/10] ✅ HTTP 200 -- No stars (9.5ms)
[4/10] ✅ HTTP 200 -- red (22.4ms)
[5/10] ✅ HTTP 200 -- black (20.4ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────┬──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────┼──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 10            │ 100.0% (10/10)       │ 16.5ms       │ 17.4ms       │ 22.8ms       │
└───────────────┴──────────────────────┴──────────────┴──────────────┴──────────────┘

   Response Distribution
================================================================================
┌─────────────────────────────────────┬──────────┬─────────────────┐
│ Response                            │ Count    │ Percentage      │
├─────────────────────────────────────┼──────────┼─────────────────┤
│ black                               │ 4        │          40.0%  │
│ No stars                            │ 3        │          30.0%  │
│ red                                 │ 3        │          30.0%  │
└─────────────────────────────────────┴──────────┴─────────────────┘
```

결과값은 다를 수 있습니다.

균형 잡힌 트래픽 분배와 함께 모든 요청이 성공적으로 완료되는 것을 확인하십시오. 평균 응답 시간의 기준값(Baseline)은 약 17ms입니다. 이는 후속 단계에서 서비스 메시 회복력 구성의 영향을 관찰하기 위한 기준점 역할을 하게 됩니다.

> [!NOTE]
> **참고 (NOTE)**
> `source ~/.bashrc` 명령어를 실행하여 `$PATH` 변수를 업데이트하고 `traffic_gen.py` 스크립트를 사용할 수 있도록 하는 것을 잊지 마십시오.
> ```execute
> source ~/.bashrc
> ```

---

### 2. 지연 장애(delay fault)를 주입하여 타임아웃(timeout) 동작을 테스트합니다.

이 단계에서는 `ratings` 서비스 요청의 50%에 2초의 지연을 주입합니다. 이는 네트워크 레이턴시나 일시적인 응답 성능 저하 상황을 시뮬레이션합니다.

지연 테스트를 통해 다음을 수행할 수 있습니다:
* 타임아웃 구성이 올바르게 작동하는지 확인합니다.
* 서비스 의존 관계를 통해 지연이 전파되는 현상을 관찰합니다.
* 지연 레이턴시 상황 하에서의 재시도(Retry) 매커니즘을 점검합니다.
* 다운스트림 지연에 민감한 서비스를 식별합니다.

2.1. `ratings` 서비스에 대한 고정 지연 장애를 구성하는 `ratings-vs-delay.yaml` 파일을 검토합니다:
* 지연을 동반한 장애 주입을 구성합니다.
* 유입되는 요청 중 50%에 대해 2초의 지연을 적용합니다.

```execute
cat ratings-vs-delay.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ratings-vs
spec:
  hosts:
  - ratings.USER_NAME_PLACEHOLDER-meshtraffic-resilience.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /ratings
    fault: ❶
      delay: ❷
        percentage:
          value: 50 ❸
        fixedDelay: 2s ❹
    route:
    - destination:
        host: ratings
        port:
          number: 9080
```

❶ 테스트를 위해 장애 주입(fault injection)을 구성합니다.
❷ 지연(delay) 장애 주입 사양을 선언합니다.
❸ 지연을 인입받을 전체 유입 요청의 비율을 50%로 한정 제어합니다.
❹ 고정 지연 지속 시간을 2초(2s)로 설정합니다.

2.2. `ratings-vs` 가상 서비스 OSSM 리소스를 생성합니다.

```execute
oc create -f ratings-vs-delay.yaml
```

```bash
virtualservice.networking.istio.io/ratings-vs created
```

2.3. `traffic_gen.py` 스크립트를 실행하여 지연 장애가 전체 요청에 어떻게 영향을 주는지 점검합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 10 requests to http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
   curl -s http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
[1/10] ✅ HTTP 200 -- black (28.8ms)
[2/10] ✅ HTTP 200 -- red (18.0ms)
[3/10] ✅ HTTP 200 -- No stars (15.9ms)
[4/10] ✅ HTTP 200 -- black (19.6ms)
[5/10] ✅ HTTP 200 -- black (2017.1ms)
[6/10] ✅ HTTP 200 -- black (24.9ms)
[7/10] ✅ HTTP 200 -- black (2016.4ms)
[8/10] ✅ HTTP 200 -- No stars (10.5ms)
[9/10] ✅ HTTP 200 -- red (17.0ms)
[10/10] ✅ HTTP 200 -- red (2026.8ms)

   Traffic Statistics
================================================================================
┌───────────────+──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 10            │ 100.0% (10/10)       │ 619.5ms      │ 24.9ms       │ 2026.8ms     │
└───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┘
```

결과값은 다를 수 있습니다.

`ratings` 서비스에 간접적으로 의존하는 `reviews` 서비스 버전(`v2/black` 및 `v3/red`)의 요청 중 약 50%에서 정확히 2초가량의 응답 지연 현상이 뚜렷하게 관찰되는 것을 똑똑히 확인할 수 있습니다.

---

### 3. `reviews-vs` 가상 서비스에 1초의 타임아웃(Timeout)을 주입합니다.

이 단계에서는 `reviews-vs` 가상 서비스에 1초의 타임아웃을 지정합니다. 이 설정이 적용되면 `reviews` 서비스가 `ratings` 서비스를 호출할 때 대기 시간이 1초를 초과하는 즉시 요청을 차단하고 HTTP 504 (Gateway Timeout) 에러를 수립하게 됩니다.

이 타임아웃은 `reviews` 서비스가 내부 `ratings` 서비스의 2초 지연을 무한정 기다리지 않도록 방지해 주며, 시스템 전체 자원을 신속히 반환하고 계단식 응답 지연이 클라이언트 전반에 무차별적으로 전파되는 일을 완벽히 차단하여 내부 자원을 건강하게 보존해 줍니다.

3.1. `reviews` 가상 서비스에 1초 타임아웃을 추가 적용하는 `reviews-vs-timeout.yaml` 파일을 검토합니다:
* 모든 reviews 서비스 요청에 대해 1초 타임아웃(timeout)을 추가 적용합니다.

```execute
cat reviews-vs-timeout.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews-vs
spec:
  hosts:
  - "*"
  gateways:
  - reviews-gateway
  http:
  - match:
    - uri:
        prefix: /reviews
    route:
    - destination:
        host: reviews
        port:
          number: 9080
    timeout: 1s ❶
```

❶ `reviews` 서비스로 전달되는 모든 인입 요청에 대해 1초(1s)의 타임아웃 조건을 강제 부여합니다.

3.2. 타임아웃 구성을 `reviews-vs` 가상 서비스에 적용합니다.

```execute
oc replace -f reviews-vs-timeout.yaml
```

```bash
virtualservice.networking.istio.io/reviews-vs replaced
```

3.3. 트래픽을 다시 주입하여, 허용된 1초 임계 한계를 초과하는 일부 요청들이 정상 차단 실패(HTTP 504)로 종료되는지 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 10 requests to http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
   curl -s http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
[1/10] ✅ HTTP 200 -- No stars (86.4ms)
[2/10] ✅ HTTP 200 -- red (98.1ms)
[3/10] ✅ HTTP 200 -- red (17.3ms)
[4/10] ✅ HTTP 200 -- black (15.8ms)
[5/10] ❌ HTTP 504 -- (bad-json) (1004.3ms)
[6/10] ❌ HTTP 504 -- (bad-json) (1005.0ms)
[7/10] ❌ HTTP 504 -- (bad-json) (1003.3ms)
[8/10] ✅ HTTP 200 -- No stars (8.1ms)
[9/10] ✅ HTTP 200 -- red (16.1ms)
[10/10] ❌ HTTP 504 -- (bad-json) (1003.3ms)

   Traffic Statistics
================================================================================
┌───────────────+──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 10            │ 60.0% (6/10)         │ 425.8ms      │ 98.1ms       │ 1005.0ms     │
└───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┘
```

결과값은 다를 수 있습니다.

설정된 1초 타임아웃을 강제로 초과하는 요청들은 무한정 가용 지체 상태로 대기하지 않고, 정확히 1초(1003.3ms+) 시점에 신속하게 HTTP 504 Gateway Timeout 오류로 통제 차단되어 종료됩니다. 반면 1초 내에 정상 회신된 행위들은 그대로 정상 응답을 보장받습니다.

---

### 4. `reviews-vs` 가상 서비스에 자동 재시도(Retry) 정책을 부여합니다.

이 단계에서는 일시적인 네트워크 순제 장애 및 서비스 단기 가동 중단 상황을 극복하기 위해 자동화된 재시도(Retry) 통제 규칙을 추가 배포합니다.

이 재시도 통제 규칙을 적용하면 다음을 수행할 수 있습니다:
* 일시적인 인프라 네트워크 단절 상황에서 서비스를 원활히 자가 복구합니다.
* 수동 개입 조치나 서비스 파드 리스타트 없이 백엔드의 일시적인 가부하 및 부하 폭주를 안전하게 우회 처리합니다.
* 개발자의 추가 애플리케이션 비즈니스 코드 수정 비용 없이 전체 시스템 가용성을 즉각 개선합니다.
* 짧은 간섭 수준의 장애 구간 내에서도 유저 브라우저 경험(UX) 수준을 탄탄하게 고수해 줍니다.

4.1. `reviews` 가상 서비스에 재시도 정책을 부여하는 `reviews-vs-retries.yaml` 명세서를 검토합니다:
* 실패한 요청에 대해 최대 10회의 재시도(attempts) 규칙을 부과합니다.
* 각 개별 시도 회수당 허용 제한 시간(perTryTimeout)을 극도로 짧은 100밀리초(0.1s)로 타이트하게 선언합니다.
* HTTP 상태 코드 기준 5xx 계열 에러가 검출되었을 때에만 재시도를 전격 수립하도록 선언합니다.

```execute
cat reviews-vs-retries.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews-vs
spec:
  gateways:
  - reviews-gateway
  hosts:
  - '*'
  http:
  - match:
    - uri:
        prefix: /reviews
    retries: ❶
      attempts: 10 ❷
      perTryTimeout: 0.1s ❸
      retryOn: 5xx ❹
    route:
    - destination:
        host: reviews
        port:
          number: 9080
    timeout: 1s
```

❶ 가상 서비스에 대한 재시도(Retry) 메커니즘을 상세 선언합니다.
❷ 최대 시도 가능 횟수를 10회로 고정 지정합니다 (최초 1회 요청 실패 시 + 최대 10회 재수립 보장).
❸ 각 개별 트라이(Try) 회당 대기 제한 시간을 타이트하게 0.1초(100ms)로 축소 통제합니다.
❹ 오직 5xx 계열의 HTTP 응답 오류가 터져 나왔을 때에만 본 재시도를 동적으로 가동합니다.

4.2. 재시도가 주입된 새 설정을 `reviews-vs` 가상 서비스에 적용합니다.

```execute
oc replace -f reviews-vs-retries.yaml
```

```bash
virtualservice.networking.istio.io/reviews-vs replaced
```

4.3. 트래픽을 주입하여, 이전에 발생했던 504 타임아웃 오류들이 재시도 정책 덕분에 감쪽같이 자가 복구되어 100% 성공률로 돌아오는지 검증합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 10 requests to http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
   curl -s http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
[1/10] ✅ HTTP 200 -- red (49.4ms)
[2/10] ✅ HTTP 200 -- No stars (85.5ms)
[3/10] ✅ HTTP 200 -- No stars (8.1ms)
[4/10] ✅ HTTP 200 -- red (19.0ms)
[5/10] ✅ HTTP 200 -- black (46.5ms)
[6/10] ✅ HTTP 200 -- red (14.7ms)
[7/10] ✅ HTTP 200 -- red (161.3ms)
[8/10] ✅ HTTP 200 -- black (19.7ms)
[9/10] ✅ HTTP 200 -- No stars (7.6ms)
[10/10] ✅ HTTP 200 -- No stars (131.9ms)

   Traffic Statistics
================================================================================
┌───────────────+──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 10            │ 100.0% (10/10)       │ 54.4ms       │ 46.5ms       │ 161.3ms      │
└───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┘
```

결과값은 다를 수 있습니다.

모든 요청이 **성공율 100.0%**로 정상 수복 성료되었음을 직접 목격해 보십시오! 
내부 `ratings` 서비스가 지연을 겪으며 504 오류를 뿜더라도, 똑똑한 이스티오 프록시가 비즈니스 어플리케이션 모르게 배후에서 극도로 신속하게 재차 백엔드를 재시도 타격(0.1s 간격)함으로써, 유저는 지연이 거의 체감되지 않는 수십 밀리초(최대 161.3ms) 수준 내외로 안전하게 100% 성공 응답만을 교부받게 되는 마법 같은 서비스 자가 치유 능력을 목격할 수 있습니다!

---

### 5. `reviews` 서비스 노드 보호를 위해 서킷 브레이커(Circuit Breaker)를 이식합니다.

이 단계에서는 대상 규칙(DestinationRule)을 동원해 동시성 한계치 및 대기 연결 큐를 강제 한정하여 백엔드 파드가 과부하 폭주 상태로 고꾸라지거나 행이 걸리는 일을 원천 보호하는 서킷 브레이커(Circuit Breaker) 설정을 주입해 봅니다.

서킷 브레이커 가동 테스트를 통해 다음을 수행할 수 있습니다:
* 커넥션 풀링(Connection Pooling) 제한 조건이 과부하 폭주로부터 백엔드를 엄호하는 실제 작동 기작을 검증합니다.
* 허용한 임계 물리 임계 한계를 한 치라도 초과하는 트래픽이 발생했을 때 지체 없이 인입 거부(HTTP 503 즉시 반환)되는 안전 장치를 확인합니다.
* 대량의 고동시성(High Concurrency) 유입 스트레스 상황 하에서 시스템이 비정상 응답 지체 및 교사 상태에 빠지지 않고 어떻게 일정 수준 방어선을 유지하는지 관찰합니다.
* 동시성 리미트 장벽이 시스템 전체의 연쇄 계단식 가동 다운(Cascading Failures)을 어떻게 깔끔히 방어하는지 입증합니다.

5.1. 서킷 브레이커 트래픽 보정 정책을 적용해 reviews 서비스를 감싸는 `reviews-dr.yaml` 대상 규칙을 검토합니다:
* 파드 복제본(Replica)당 수립될 수 있는 TCP 최대 가용 연결 수(maxConnections)를 오직 1개로 극단 통제합니다.
* 파드 복제본당 동시 대기 가능한 HTTP 펜딩 큐 크기(http1MaxPendingRequests)를 오직 1개로 완전 봉쇄합니다.
* 각 개별 커넥션당 누적 수립 가능한 누적 요청 임계치(maxRequestsPerConnection)를 단 1개로 엄벌 한정합니다.

```execute
cat reviews-dr.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: reviews-dr
spec:
  host: reviews
  trafficPolicy: ❶
    connectionPool: ❷
      tcp:
        maxConnections: 1 ❸
      http:
        http1MaxPendingRequests: 1 ❹
        maxRequestsPerConnection: 1 ❺
```

❶ 서킷 브레이커 제어를 위한 트래픽 정책 정의 시작부를 선언합니다.
❷ 병렬 통신 제한을 제어하기 위한 커넥션 풀(Connection Pool) 세부 항목을 선언합니다.
❸ 복제본당 물리 TCP 허용 연결 한계를 단 1개로 봉착 한정합니다.
❹ 복제본당 누적 가능한 HTTP 대기 펜딩 큐 깊이를 단 1개로 통제 차단합니다.
❺ 커넥션 수립 이후 즉시 클로즈를 유도하기 위해 단일 커넥션당 누적 허용 요청 수를 1개로 지정합니다.

5.2. `reviews-dr` 대상 규칙 OSSM 리소스를 생성 적용합니다.

```execute
oc create -f reviews-dr.yaml
```

```bash
destinationrule.networking.istio.io/reviews-dr created
```

5.3. 백엔드 보호 장벽(1개 허용한계)의 방어 기작을 보기 위해, `traffic_gen.py` 스크립트를 **고병렬 병렬 동시 타격(parallel.yaml) 모드**로 가동하여 과부하 트래픽을 주입해 봅니다.

```execute-2
traffic_gen.py parallel.yaml
```

```bash
   Continuous mode: 5s to http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
   curl -s http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
[1] ✅ HTTP 200 -- red (444.3ms)
[2] ❌ HTTP 503 -- (bad-json) (384.8ms)
[3] ✅ HTTP 200 -- black (625.5ms)
[4] ❌ HTTP 503 -- (bad-json) (383.8ms)
[5] ❌ HTTP 504 -- (bad-json) (1315.1ms)
[6] ✅ HTTP 200 -- red (425.2ms)
[7] ❌ HTTP 503 -- (bad-json) (380.9ms)
[8] ✅ HTTP 200 -- black (815.5ms)
[9] ✅ HTTP 200 -- black (377.4ms)
[10] ✅ HTTP 200 -- red (1042.7ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────+──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 160           │ 29.4% (47/160)       │ 59.9ms       │ 4.3ms        │ 383.8ms      │
└───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┘
```

결과값은 다를 수 있습니다.

동시 커넥션 한계를 극단적으로 1개로 조여두었기 때문에, 백엔드 파드가 과부하되어 가동 불능이 되거나 뻗기 전에 이스티오 프록시가 가볍게 방어 장벽을 가동하여 **초과 수립된 병렬 요청들을 즉각적으로 인입 차단(HTTP 503 및 504 즉시 차단 처분)해 버리는 완벽한 서킷 개방 수립 상태**를 눈앞에서 확인할 수 있습니다. 결과적으로 성공율이 약 29.4% 내외로 통제 수렴됩니다.

5.4. 서킷 브레이커 방어 임계 수준을 여유 있게 늘려주기 위해, 동시 연결 한도를 4개 수준으로 안전하게 확장 보정하는 `reviews-dr-2.yaml` 파일을 검토합니다:
* 파드 복제본당 TCP 최대 가용 연결 수(maxConnections)를 4개로 확대합니다.
* 파드 복제본당 HTTP 대기 펜딩 큐(http1MaxPendingRequests)를 4개로 증폭합니다.
* 커넥션당 누적 허용 요청 수(maxRequestsPerConnection)를 4개로 여유 있게 늘려줍니다.

```execute
cat reviews-dr-2.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: reviews-dr
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 4 ❶
      http:
        http1MaxPendingRequests: 4 ❷
        maxRequestsPerConnection: 4 ❸
```

❶ 동시 허용 TCP 커넥션 개수를 복제본당 4개로 대폭 확장합니다.
❷ 동시 허용 HTTP 대기 큐 크기를 4개로 늘려 병목 저항력을 증강합니다.
❸ 각 커넥션당 처리 가능 요청 제한 한계를 4회로 늘려 세션 활용률을 보정합니다.

5.5. 대상 규칙 구성을 확장된 서킷 브레이커 4개 한계 사양 파일로 갱신 적용합니다.

```execute
oc replace -f reviews-dr-2.yaml
```

```bash
destinationrule.networking.istio.io/reviews-dr replaced
```

5.6. 고동시성 병렬 트래픽(`parallel.yaml`)을 다시 가동하여, 방어막 확장 이후 얼마나 더 많은 병렬 트래픽 요청들이 정상 성공 수용되는지 확인합니다.

```execute-2
traffic_gen.py parallel.yaml
```

```bash
   Continuous mode: 5s to http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
   curl -s http://istio-ingressgateway-%username%-istio-ingress.apps.%cluster_subdomain%/reviews/1
[1] ✅ HTTP 200 -- red (31.3ms)
[2] ✅ HTTP 200 -- black (88.9ms)
[3] ✅ HTTP 200 -- red (28.6ms)
[4] ✅ HTTP 200 -- No stars (122.7ms)
[5] ✅ HTTP 200 -- No stars (15.8ms)
[6] ✅ HTTP 200 -- red (26.6ms)
[7] ❌ HTTP 503 -- (bad-json) (3.0ms)
[8] ✅ HTTP 200 -- red (126.0ms)
[9] ✅ HTTP 200 -- red (26.4ms)
[10] ❌ HTTP 503 -- (bad-json) (2.2ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────+──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────+──────────────────────┼──────────────┼──────────────┼──────────────┘
│ 120           │ 95.0% (114/120)      │ 130.1ms      │ 119.4ms      │ 334.3ms      │
└───────────────+──────────────────────┼──────────────┼──────────────┴──────────────┘
```

결과값은 다를 수 있습니다.

동시 커넥션 한도 장벽을 4개로 편안하게 확대해 주었기 때문에, **성공률이 기존 29.4%에서 95.0% 수준으로 비약적으로 급상승**하여 대량의 고병렬 통신도 안전하고 대량으로 무결하게 받아내는 놀라운 부하 탄력성(Load Resilience) 개선 효과를 입증하고 직접 감상할 수 있습니다!

---

## 실습 완료 (Finish)

워크스테이션 머신에서 다음 명령어를 실행하여 실습을 완전히 정돈하고 종료합니다. 이 정돈 단계는 이전 실습에서 남은 리소스들이 다음 단원에 진행될 실습 환경 구성에 지장을 주거나 간섭하는 일을 미연에 방지하기 위해 매우 중요합니다.

```execute
lab finish meshtraffic-resilience
```
