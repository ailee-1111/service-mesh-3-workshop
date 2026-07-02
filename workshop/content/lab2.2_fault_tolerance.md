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

# 모듈 2.2: Istio 장애 허용 (Fault Injection)

오픈시프트 서비스 메시를 사용하여 인그레스 트래픽 및 서비스 간 통신에 지연(delay) 및 중단(abort) 장애를 주입하고, 장애 전파(fault propagation)와 계단식 효과(cascading effects)를 관찰합니다.

## 결과 (Outcomes)
* Red Hat OpenShift Service Mesh (OSSM)를 사용하여 네트워크 장애를 시뮬레이션합니다.
* 직접적인 서비스 요청에 네트워크 장애를 주입합니다.
* 서비스 간(service-to-service) 요청에 네트워크 장애를 주입합니다.
* 네트워크 장애 상황에서 OSSM의 기본 동작을 검증합니다.

워크스테이션 머신의 사용자 터미널에서 아래의 `lab` 명령어를 실행하여 본 실습을 위한 환경을 준비하고, 모든 필요한 리소스들이 가용하게 전개되었는지 검증 및 보장합니다:

```execute
lab start meshtraffic-chaos
```

또한, 다음 명령어를 실행하여 `$PATH` 변수를 업데이트하고 `traffic_gen.py` 명령어를 즉시 사용할 수 있도록 설정합니다. 새 환경을 생성한 후 한 번만 실행하면 됩니다.

```execute
source ~/.bashrc
```

`lab start` 명령어는 다음과 같은 작업을 수행합니다:
* `%username%-meshtraffic-chaos` 네임스페이스를 생성합니다.
* `%username%-meshtraffic-chaos` 네임스페이스를 서비스 메시에 추가합니다.
* `%username%-meshtraffic-chaos` 네임스페이스에 `ratings`와 세 가지 버전의 `reviews` 애플리케이션을 배포합니다.
* `traffic_gen.py` 스크립트가 트래픽을 생성하도록 구성합니다.
* `reviews` 서비스를 위한 초기 게이트웨이 및 가상 서비스(VirtualService) OSSM 리소스를 생성합니다.

---

## 지침 (Instructions)

### 1. 서비스 메시의 초기 상태를 확인합니다.

1.1. 새로운 터미널 창에서 `%username%` 사용자와 `openshift` 비밀번호를 사용하여 OpenShift 클러스터에 로그인한 다음, `%username%-meshtraffic-chaos` 프로젝트로 전환합니다:

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
oc project %username%-meshtraffic-chaos
```

* **프로젝트 이동 결과 로그:**
```bash
Now using project "%username%-meshtraffic-chaos" on server "https://api.%cluster_subdomain%:6443".
```

1.2. `%username%-meshtraffic-chaos` 네임스페이스에서 애플리케이션이 실행 중인지 확인합니다.

```execute
oc get pods
```

```bash
NAME READY STATUS RESTARTS AGE
ratings-v1-... 2/2 Running 0 5m
reviews-v1-... 2/2 Running 0 5m
reviews-v2-... 2/2 Running 0 5m
reviews-v3-... 2/2 Running 0 5m
```

모든 파드는 `2/2` 컨테이너가 준비된 것으로 표시되어야 하며, 이는 Istio가 Envoy 사이드카 프록시를 주입했음을 나타냅니다.

1.3. 프로젝트 내에 필요한 게이트웨이 및 가상 서비스 OSSM 리소스가 존재하는지 확인합니다.

```execute
oc get gateways.networking.istio.io,virtualservices.networking.istio.io
```

```bash
NAME AGE
gateway.networking.istio.io/reviews-gateway 2m

NAME GATEWAYS HOSTS AGE
virtualservice.networking.istio.io/reviews-vs ["reviews-gateway"] ["*"] 2m
```

1.4. 연습 디렉토리로 이동합니다.

```execute
cd ~/labs/meshtraffic-chaos
```

1.5. `traffic_gen.py` 스크립트를 사용하여 서비스 메시로의 외부 접속을 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 20 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/20] ✅ HTTP 200 -- No stars (10.5ms)
[2/20] ✅ HTTP 200 -- No stars (7.4ms)
[3/20] ✅ HTTP 200 -- Ratings: ✅ black (20.6ms)
[4/20] ✅ HTTP 200 -- No stars (6.8ms)
[5/20] ✅ HTTP 200 -- No stars (23.6ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────┬──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────┼──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 20            │ 100.0% (20/20)       │ 18.4ms       │ 14.6ms       │ 93.5ms       │
└───────────────┴──────────────────────┴──────────────┴──────────────┴──────────────┘

   Response Distribution
================================================================================
┌─────────────────────────────────────┬──────────┬─────────────────┐
│ Response                            │ Count    │ Percentage      │
├─────────────────────────────────────┼──────────┼─────────────────┤
│ No stars                            │ 8        │          40.0%  │
│ Ratings: ✅ black                   │ 7        │          35.0%  │
│ Ratings: ✅ red                     │ 5        │          25.0%  │
└─────────────────────────────────────┴──────────┴─────────────────┘
```

결과값은 다를 수 있습니다.

균형 잡힌 트래픽 분배와 함께 모든 요청이 성공적으로 완료되는 것을 확인하십시오. 평균 응답 시간의 기준값(Baseline)은 약 18ms입니다. 이는 후속 단계에서 장애 주입의 영향을 관찰하기 위한 기준점 역할을 하게 됩니다.

> [!NOTE]
> **참고 (NOTE)**
> `source ~/.bashrc` 명령어를 실행하여 `$PATH` 변수를 업데이트하고 `traffic_gen.py` 스크립트를 사용할 수 있도록 하는 것을 잊지 마십시오.
> ```execute
> source ~/.bashrc
> ```

---

### 2. 직접적인 서비스 요청을 테스트하기 위해 `reviews-vs` 가상 서비스에 고정 지연 장애(fixed delay fault)를 주입합니다.

이 단계에서는 `reviews` 서비스 요청의 50%에 2초의 지연을 주입합니다. 이는 외부 클라이언트가 서비스에 액세스할 때 네트워크 대기 시간을 경험하는 상황을 시뮬레이션합니다.

직접 액세스 시의 지연 테스트를 통해 다음을 수행할 수 있습니다:
* 클라이언트 타임아웃 설정 및 재시도 로직 검증
* 외부 사용자가 느린 서비스 응답을 경험하는 양상을 확인
* 클라이언트가 지연을 정상적으로 처리하는지 또는 갑자기 실패하는지 파악
* 성능 저하 상태에서 SLA 준수 여부 검증

2.1. `reviews-vs-delay.yaml` 파일을 검토합니다. 이 파일은 다음과 같은 지연 장애를 구성합니다:
* 인그레스 게이트웨이에서 고정된 지연을 가진 장애 주입을 구성합니다.
* 유입되는 요청 중 50%에 대해 2초의 지연을 적용합니다.
* 세 개의 reviews 서비스 버전에 대한 표준 라우팅 상태는 그대로 유지합니다.

```execute
cat reviews-vs-delay.yaml
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
    fault: ❶
      delay: ❷
        percentage:
          value: 50 ❸
        fixedDelay: 2s ❹
    route:
    - destination:
        host: reviews
        port:
          number: 9080
```

❶ 카오스 엔지니어링을 위해 장애 주입(fault injection)을 구성합니다.
❷ 지연(latency) 주입을 명시적으로 지정합니다.
❸ 지연을 인입받을 전체 유입 요청의 비율을 50%로 제한 제어합니다.
❹ 고정 지연 지속 시간을 2초(2s)로 설정합니다.

2.2. 지연 구성을 `reviews` 가상 서비스에 적용합니다.

```execute
oc replace -f reviews-vs-delay.yaml
```

```bash
virtualservice.networking.istio.io/reviews-vs replaced
```

2.3. 트래픽을 생성하여 지연을 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 20 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/20] ✅ HTTP 200 -- No stars (2047.7ms)
[2/20] ✅ HTTP 200 -- No stars (6.9ms)
[3/20] ✅ HTTP 200 -- No stars (2013.7ms)
[4/20] ✅ HTTP 200 -- No stars (6.9ms)
[5/20] ✅ HTTP 200 -- Ratings: ✅ red (2173.2ms)
[6/20] ✅ HTTP 200 -- Ratings: ✅ red (2040.1ms)
[7/20] ✅ HTTP 200 -- No stars (8.0ms)
[8/20] ✅ HTTP 200 -- Ratings: ✅ red (17.3ms)
[9/20] ✅ HTTP 200 -- No stars (6.5ms)
[10/20] ✅ HTTP 200 -- Ratings: ✅ black (200.2ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────┬──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────┼──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 20            │ 100.0% (20/20)       │ 837.6ms      │ 81.5ms       │ 2173.2ms     │
└───────────────┴──────────────────────┴──────────────┴──────────────┴──────────────┘
```

결과값은 다를 수 있습니다.

요청의 약 50%가 2초 내외의 응답 시간을 보여주는 반면, 나머지 50%는 수 밀리초 내로 정상 응답하는 것을 확인하십시오. 모든 요청은 여전히 성공적으로 완료됩니다. 약 1초의 평균 응답 시간은 정확히 50/50 비율 분배 상태를 반영합니다.

---

### 3. 직접적인 서비스 요청을 테스트하기 위해 `reviews-vs` 가상 서비스에 중단 장애(abort fault)를 주입합니다.

이 단계에서는 요청의 50%에 HTTP 503 오류를 주입합니다. 이는 외부 클라이언트가 경험할 수 있는 실제 서비스 중단 및 가동 불능 오류 상황을 시뮬레이션합니다.

직접 액세스 시의 중단 테스트를 통해 다음을 수행할 수 있습니다:
* 클라이언트의 에러 처리 및 폴백(fallback) 메커니즘을 검증합니다.
* 외부 사용자가 서비스 정지 사태를 경험하는 양상을 확인합니다.
* 클라이언트가 실패한 요청을 원만하게 재시도하는지 확인합니다.
* 장애 상황 하에서 서킷 브레이커(Circuit Breaker) 동작을 수립합니다.

3.1. `reviews-vs-abort.yaml` 파일을 검토합니다. 이 파일은 `reviews` 서비스에 대한 중단 장애를 구성하며, 다음과 같은 작업을 수행합니다:
* `reviews-vs` 가상 서비스에서 HTTP 중단 에러가 발생하도록 장애 주입을 구성합니다.
* 유입되는 요청 중 50%에 대해 HTTP 503(Service Unavailable) 에러를 대입합니다.
* 세 개의 reviews 서비스 버전에 대한 표준 라우팅 경로 상태는 그대로 유지합니다.

```execute
cat reviews-vs-abort.yaml
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
    fault:
      abort: ❶
        percentage:
          value: 50.0
        httpStatus: 503 ❷
    route:
    - destination:
        host: reviews
        port:
          number: 9080
```

❶ 중단(오류) 장애 주입 사양을 선언합니다.
❷ 반환할 HTTP 상태 코드를 503(Service Unavailable)으로 강제 매핑합니다.

3.2. 중단 구성을 `reviews-vs` 가상 서비스에 적용합니다.

```execute
oc replace -f reviews-vs-abort.yaml
```

```bash
virtualservice.networking.istio.io/reviews-vs replaced
```

3.3. 트래픽을 주입하여 요청의 50%에 대해 HTTP 503 에러가 반환되는지 검증합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 20 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/20] ✅ HTTP 200 -- Ratings: ✅ black (171.2ms)
[2/20] ❌ HTTP 503 -- (invalid-json) (3.7ms)
[3/20] ✅ HTTP 200 -- Ratings: ✅ black (15.0ms)
[4/20] ❌ HTTP 503 -- (invalid-json) (3.7ms)
[5/20] ✅ HTTP 200 -- Ratings: ✅ red (204.5ms)
[6/20] ❌ HTTP 503 -- (invalid-json) (2.8ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────┬──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────┼──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 20            │ 55.0% (11/20)        │ 28.8ms       │ 8.4ms        │ 204.5ms      │
└───────────────┴──────────────────────┴──────────────┴──────────────┴──────────────┘
```

결과값은 다를 수 있습니다.

요청의 약 50%는 HTTP 503 에러로 실패하는 반면, 나머지 50%는 평소대로 원활하게 성공함을 관찰해 주십시오. 실패한 요청들은 게이트웨이 루프에 의해 즉시 차단되므로, 몇 밀리초(3.7ms 내외) 안에 대단히 신속하게 응답이 끊어져 버립니다.

3.4. 오픈시프트 웹 콘솔 상에서 서비스 메시의 토폴로지 변화를 관찰합니다.
*(참고: 터미널 탭 옆의 Console 탭을 활용해 간단한 가동 상태를 살필 수 있지만, 플러그인 메뉴가 완전히 작동하려면 본 주소 링크 <a href="https://console-openshift-console.%cluster_subdomain%" target="_blank">https://console-openshift-console.%cluster_subdomain%</a> 를 클릭해 브라우저 새 탭으로 접속해 활용하시는 것을 적극 권장합니다.)*

3.5. 오픈시프트 콘솔의 관리자 관점(Administrator perspective)에서 **Service Mesh > Traffic Graph**를 클릭합니다.

3.6. **Select Namespaces**에서 `%username%-meshtraffic-chaos` 네임스페이스를 선택하여 그래프에 추가합니다. 트래픽 그래프에서 장애 주입 동작을 관찰하십시오:
* 빨간색 화살표가 `istio-ingressgateway`를 `reviews` 서비스에 연결하여 HTTP 오류를 나타냅니다.
* 오른쪽의 **Current graph summary** 패널에는 약 50%의 HTTP 5xx 에러가 표시됩니다.
* 오류율은 가상 서비스에 구성된 50% 중단 설정과 일치합니다.
* 세 개의 reviews 서비스 버전 모두 트래픽을 수신하지만, 요청의 50%는 애플리케이션 코드에 도달하기 전에 실패합니다.

<img src="images/fig-006.svg" width="100%" alt="Figure 1.7: Traffic graph showing 50% HTTP 503 errors from abort fault injection" />

그래픽 페이지를 열어 두십시오. 연습 전체에서 이 그래프로 돌아와 장애 주입이 네트워크 활동에 어떻게 영향을 미치는지 관찰할 수 있습니다.

> [!NOTE]
> **참고 (NOTE)**
> 그래프 모양이 다를 수 있습니다. 새로 고침 당 트래픽 메트릭, 새로 고침 간격, 그래프 확대/축소 수준 등 필요에 따라 그래프 매개변수를 조정하십시오. 브라우저 페이지를 새로 고치거나 `traffic_gen.py` 스크립트를 재실행하여 더 많은 트래픽을 생성하십시오.

---

### 4. 서비스 간(service-to-service) 요청을 테스트하기 위해 `ratings` 가상 서비스에 지연 장애를 주입합니다.

이전 단계에서는 직접적인 요청의 장애를 테스트했습니다. 이제는 서비스 간 장애를 테스트합니다.
이 단계에서는 `ratings` 서비스 요청의 50%에 지연을 주입합니다. 이 지연은 `reviews`가 `ratings`를 호출할 때 발생하며, 장애가 서비스 종속성을 통해 어떻게 전파되는지 보여줍니다.

서비스 간 통신에서의 지연 테스트를 통해 다음을 수행할 수 있습니다:
* 지연이 서비스 종속성을 통해 어떻게 전파되는지 관찰
* 내부 서비스 간의 타임아웃 구성 테스트
* 마이크로서비스 아키텍처에서의 계단식 대기 시간(cascading latency) 파악
* 종속 서비스가 느린 업스트림 서비스를 어떻게 처리하는지 검증

4.1. 장애가 없는 상태로 `reviews-vs` 가상 서비스를 다시 수립합니다.

```execute
oc replace -f reviews-vs.yaml
```

```bash
virtualservice.networking.istio.io/reviews-vs replaced
```

4.2. `ratings` 서비스에 지연을 추가하는 `ratings-vs-delay.yaml` 파일을 검토합니다:
* 지연이 포함된 장애 주입을 구성합니다.
* 유입되는 요청 중 50%에 대해 지연을 적용합니다.

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
  - ratings
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

❶ 카오스 엔지니어링을 위해 장애 주입(fault injection)을 구성합니다.
❷ 지연(delay) 주입을 명시합니다.
❸ 요청이 지연을 수신하는 비율을 50%로 통제합니다.
❹ 고정 지연 지속 시간을 2초(2s)로 설정합니다.

4.3. 지연을 추가하기 위해 `ratings` 서비스를 위한 `ratings-vs` 가상 서비스를 생성합니다.

```execute
oc create -f ratings-vs-delay.yaml
```

```bash
virtualservice.networking.istio.io/ratings-vs created
```

4.4. `traffic_gen.py` 스크립트를 사용하여 지연을 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 20 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/20] ✅ HTTP 200 -- Ratings: ✅ red (2099.4ms)
[2/20] ✅ HTTP 200 -- Ratings: ✅ black (124.9ms)
[3/20] ✅ HTTP 200 -- No stars (44.3ms)
[4/20] ✅ HTTP 200 -- Ratings: ✅ red (2015.0ms)
[5/20] ✅ HTTP 200 -- Ratings: ✅ red (16.2ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────┬──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────┼──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 20            │ 100.0% (20/20)       │ 526.7ms      │ 16.7ms       │ 2099.4ms     │
└───────────────┴──────────────────────┴──────────────┴──────────────┴──────────────┘
```

결과값은 다를 수 있습니다.

지연이 서비스 종속성을 통해 어떻게 전파되는지 관찰하십시오:
* `reviews-v1` (No stars): `reviews-v1`은 `ratings` 서비스를 호출하지 않기 때문에 항상 일정하게 빠릅니다(~10-60ms).
* `reviews-v2` (black stars) 및 `reviews-v3` (red stars): `ratings` 서비스가 정상적으로 응답할 때는 빠르고(~17-19ms), `ratings` 서비스에 지연 장애가 주입될 때는 느린(~2000ms+) 복합적인 응답 시간을 보여줍니다.
* 모든 요청이 성공(100%)하여, 지연이 응답 시간을 증가시키지만 서비스 실패를 유발하지는 않음을 보여줍니다.

4.5. 오픈시프트 웹 콘솔 상에서 **Service Mesh > Traffic Graph** 메뉴로 이동합니다.

4.6. **Select Namespaces**에서 `%username%-meshtraffic-chaos` 네임스페이스를 선택하여 그래프에 추가했는지 확인합니다.

4.7. **Display** 콤보 박스에서 **Response Time > 95th Percentile**을 선택합니다. 트래픽 그래프에서 지연 전파를 관찰하십시오:
* `ratings` 서비스에 종속된 서비스 버전들만 응답 지연 시간의 증가를 보여줍니다.
* `reviews-v1`은 `ratings` 서비스에 연결되어 있지 않으므로 정상 응답 대기 시간을 고수합니다.

<img src="images/fig-007.svg" width="100%" alt="Figure 1.8: Traffic graph showing response time delays in service-to-service communication" />

---

### 5. 서비스 간(service-to-service) 요청을 테스트하기 위해 `ratings` 가상 서비스에 중단 장애(abort fault)를 주입합니다.

이 단계에서는 `reviews`가 요청할 때 `ratings` 서비스 요청의 50%에 HTTP 500 에러를 주입합니다.
서비스 간 통신에서의 중단 테스트를 통해 다음을 수행할 수 있습니다:
* 실패가 마이크로서비스 아키텍처를 통해 계단식으로 어떻게 확산되는지 관찰
* 종속 서비스 간의 오류 처리 로직 검증
* 실제 백엔드에 영향을 미치지 않고 서비스 실패 상황 시뮬레이션

5.1. `ratings` 서비스에 대한 중단 장애를 구성하는 `ratings-vs-error.yaml` 파일을 검토합니다:
* HTTP 중단 장애를 동반한 장애 주입을 구성합니다.
* 요청의 50%에 대해 HTTP 500 (Internal Server Error)을 반환합니다.
* 실제 백엔드에 전혀 손을 대거나 영향을 주지 않은 상태로 서비스 실패를 시뮬레이션합니다.

```execute
cat ratings-vs-error.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ratings-vs
spec:
  hosts:
  - ratings
  http:
  - match:
    - uri:
        prefix: /ratings
    fault:
      abort: ❶
        httpStatus: 500 ❷
        percentage:
          value: 50.0
    route:
    - destination:
        host: ratings
        port:
          number: 9080
```

❶ HTTP 오류(중단) 장애 주입 사양을 명시합니다.
❷ 반환할 HTTP 상태 코드를 500(Internal Server Error)으로 지정합니다.

5.2. `ratings` 가상 서비스를 업데이트합니다.

```execute
oc replace -f ratings-vs-error.yaml
```

```bash
virtualservice.networking.istio.io/ratings-vs replaced
```

5.3. `traffic_gen.py` 스크립트를 사용하여 `reviews` 서비스가 간헐적인 `ratings` HTTP 500 에러를 어떻게 완만하게 처리하는지 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 20 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/20] ✅ HTTP 200 -- Ratings: ✅ black (17.2ms)
[2/20] ✅ HTTP 200 -- Ratings: ✅ black (13.4ms)
[3/20] ✅ HTTP 200 -- Ratings: ✅ red (13.3ms)
[4/20] ✅ HTTP 200 -- Ratings: ❌ Ratings service is currently unavailable (12.5ms)
[5/20] ✅ HTTP 200 -- Ratings: ✅ red (13.4ms)
[6/20] ✅ HTTP 200 -- Ratings: ✅ black (22.4ms)
[7/20] ✅ HTTP 200 -- No stars (7.4ms)
[8/20] ✅ HTTP 200 -- Ratings: ❌ Ratings service is currently unavailable (12.3ms)
[9/20] ✅ HTTP 200 -- Ratings: ❌ Ratings service is currently unavailable (15.9ms)
[10/20] ✅ HTTP 200 -- No stars (7.8ms)

...output omitted...

   Traffic Statistics
================================================================================
┌───────────────┬──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Total Request │ Success Rate         │ Average      │ P50          │ P95          │
├───────────────┼──────────────────────┼──────────────┼──────────────┼──────────────┤
│ 20            │ 100.0% (20/20)       │ 13.2ms       │ 13.1ms       │ 23.3ms       │
└───────────────┴──────────────────────┴──────────────┴──────────────┴──────────────┘

   Response Distribution
================================================================================
┌─────────────────────────────────────┬──────────┬─────────────────┐
│ Response                            │ Count    │ Percentage      │
├─────────────────────────────────────┼──────────┼─────────────────┤
│ Ratings: ❌ Ratings service is c... │ 6        │          30.0%  │
│ No stars                            │ 6        │          30.0%  │
│ Ratings: ✅ black                   │ 4        │          20.0%  │
│ Ratings: ✅ red                     │ 4        │          20.0%  │
└─────────────────────────────────────┴──────────┴─────────────────┘
```

결과값은 다를 수 있습니다.

`ratings` 서비스가 HTTP 500 에러를 반환함에도 불구하고, `reviews` 서비스는 이 실패를 원만하게 처리(우회 폴백)하여 클라이언트에게 성공적으로 HTTP 200 응답을 반환한다는 점에 주목하십시오.

5.4. 오픈시프트 웹 콘솔 상에서 **Service Mesh > Traffic Graph** 메뉴로 이동합니다.

5.5. **Select Namespaces**에서 `%username%-meshtraffic-chaos` 네임스페이스를 선택하여 그래프에 추가했는지 확인합니다. 트래픽 그래프에서 에러 전파 동작을 관찰하십시오:

<img src="images/fig-008.svg" width="100%" alt="Figure 1.9: Traffic graph showing errors in service-to-service communication" />

---

## 실습 완료 (Finish)

워크스테이션 머신에서 다음 명령어를 실행하여 실습을 완전히 정돈하고 종료합니다. 이 정돈 단계는 이전 실습에서 남은 리소스들이 다음 단원에 진행될 실습 환경 구성에 지장을 주거나 간섭하는 일을 미연에 방지하기 위해 매우 중요합니다.

```execute
lab finish meshtraffic-chaos
```
