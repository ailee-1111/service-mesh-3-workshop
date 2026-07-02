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

# 모듈 2.1: 트래픽 라우팅 및 분할 (Traffic Routing and Splitting)

가중치 기반, 헤더 기반 및 경로 기반 라우팅을 구현하여 서비스 버전 간의 트래픽 분배를 제어합니다. 트래픽 비율을 점진적으로 전환하여 점진적 카나리 배포(progressive canary deployment)를 실행합니다.

## 결과 (Outcomes)
* 가중치 라우팅, HTTP 헤더 및 URI 경로 매칭을 기반으로 Red Hat OpenShift Service Mesh (OSSM) 내의 서비스로 트래픽을 라우팅합니다.
* 트래픽 시프팅을 통해 점진적 카나리 배포를 구현합니다.

워크스테이션 머신의 사용자 터미널에서 아래의 `lab` 명령어를 실행하여 본 실습을 위한 환경을 준비하고, 모든 필요한 리소스들이 가용하게 전개되었는지 검증 및 보장합니다:

```execute
lab start meshtraffic-routing
```

또한, 다음 명령어를 실행하여 `$PATH` 변수를 업데이트하고 `traffic_gen.py` 명령어를 즉시 사용할 수 있도록 설정합니다. 새 환경을 생성한 후 한 번만 실행하면 됩니다.

```execute
source ~/.bashrc
```

`lab start` 명령어는 다음과 같은 작업을 수행합니다:
* `%username%-meshtraffic-routing` 네임스페이스를 생성합니다.
* `%username%-meshtraffic-routing` 네임스페이스를 서비스 메시에 추가합니다.
* `%username%-meshtraffic-routing` 네임스페이스에 `ratings`와 세 가지 버전의 `reviews` 애플리케이션을 배포합니다.
* 인그레스 트래픽을 위한 기본 게이트웨이 및 가상 서비스(VirtualService) 리소스를 생성합니다.
* `traffic_gen.py` 스크립트가 트래픽을 생성하도록 구성합니다.

---

## 지침 (Instructions)

### 1. 서비스 메시의 초기 상태를 확인합니다.

1.1. 새로운 터미널 창에서 `%username%` 사용자와 `openshift` 비밀번호를 사용하여 OpenShift 클러스터에 로그인한 다음, `%username%-meshtraffic-routing` 프로젝트로 전환합니다:

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
oc project %username%-meshtraffic-routing
```

* **프로젝트 이동 결과 로그:**
```bash
Now using project "%username%-meshtraffic-routing" on server "https://api.%cluster_subdomain%:6443".
```

1.2. `%username%-meshtraffic-routing` 네임스페이스에서 애플리케이션이 실행 중인지 확인합니다.

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

1.3. 연습 디렉토리로 이동합니다.

```execute
cd ~/labs/meshtraffic-routing
```

1.4. `traffic_gen.py` 스크립트를 사용하여 서비스 메시로의 외부 접속을 확인합니다. 라우팅 규칙 없이 트래픽이 세 가지 버전에 걸쳐 무작위로 분산되는지 관찰합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/100] ✅ HTTP 200 -- red (49.9ms)
[2/100] ✅ HTTP 200 -- red (15.0ms)
[3/100] ✅ HTTP 200 -- red (15.5ms)
[4/100] ✅ HTTP 200 -- No stars (12.1ms)
[5/100] ✅ HTTP 200 -- No stars (8.7ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ No stars                    │ 42        │               42.0%  │
│ red                         │ 30        │               30.0%  │
│ black                       │ 28        │               28.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

결과값은 다를 수 있습니다.

Kubernetes가 세 가지 버전 모두에 트래픽을 무작위로 로드 밸런싱하여 대략적으로 균등한 분배를 유발한다는 점에 주목하십시오. OSSM 라우팅 규칙이 없으면 기본 Kubernetes 서비스 로드 밸런싱이 모든 파드 엔드포인트에 요청을 고르게 분배합니다. 다음 단계에서는 트래픽 분배에 대한 정밀한 제어를 얻기 위해 OSSM 리소스를 구성합니다.

> [!NOTE]
> **참고 (NOTE)**
> `source ~/.bashrc` 명령어를 실행하여 `$PATH` 변수를 업데이트하고 `traffic_gen.py` 스크립트를 사용할 수 있도록 하는 것을 잊지 마십시오.
> ```execute
> source ~/.bashrc
> ```

---

### 2. 트래픽 분배를 제어하기 위한 가중치 라우팅(weighted routing)을 구현합니다.

이 단계에서는 가중치 라우팅을 구현하여 트래픽의 몇 퍼센트가 `reviews` 서비스의 각 버전으로 이동할지 정밀하게 제어합니다. 단계 1에서 관찰한 무작위 로드 밸런싱과 달리 가중치 라우팅은 트래픽 분배에 대한 결정론적인(deterministic) 제어를 제공합니다.

다음과 같은 80/15/5 분할을 구성합니다:

| 가중치 (Weight) | 버전 (Version) | 응답 (Response) | 목적 (Purpose) |
|---|---|---|---|
| 80% | v1 | No stars | 안정적인 프로덕션 버전 (Stable production version) |
| 15% | v2 | black stars | 기존 사용자 기반을 갖춘 성숙한 버전 (Mature version with established user base) |
| 5% | v3 | red stars | 최소한의 노출로 테스트 중인 새 버전 (New version being tested with minimal exposure) |

2.1. `reviews-dr.yaml` 파일을 검토합니다. 이 파일은 다음과 같은 작업을 수행하는 대상 규칙(DestinationRule) OSSM 리소스를 생성합니다:
* `reviews` 서비스를 대상으로 정의합니다.
* 파드 버전 레이블을 기반으로 v1, v2 및 v3 서브셋(subsets)을 생성합니다.
* 특정 서비스 버전으로의 트래픽 라우팅을 활성화합니다.

```execute
cat reviews-dr.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews ❶
  subsets: ❷
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
```

❶ `reviews` 마이크로서비스를 위한 Kubernetes 서비스 이름입니다.
❷ `reviews` 서비스의 각 버전에 대한 서브셋(subsets)을 정의합니다.

2.2. 대상 규칙(DestinationRule) OSSM 리소스를 생성합니다.

```execute
oc create -f reviews-dr.yaml
```

```bash
destinationrule.networking.istio.io/reviews created
```

2.3. `reviews-weighted-vs.yaml` 파일을 검토합니다. 이 파일은 가중치 라우팅을 구현하기 위해 `reviews` 가상 서비스(VirtualService) OSSM 리소스를 업데이트하며, 다음과 같은 작업을 수행합니다:
* 트래픽의 80%를 `reviews-v1`로 라우팅합니다.
* 트래픽의 15%를 `reviews-v2`로 라우팅합니다.
* 트래픽의 5%를 `reviews-v3`로 라우팅합니다.

```execute
cat reviews-weighted-vs.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
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
    - destination: ❶
        host: reviews
        subset: v1
      weight: 80 ❷
    - destination:
        host: reviews
        subset: v2
      weight: 15
    - destination:
        host: reviews
        subset: v3
      weight: 5
```

❶ 트래픽 분할을 위한 여러 목적지(destinations)를 정의합니다.
❷ 각 서브셋에 대한 트래픽 비율을 지정합니다.

2.4. 가상 서비스(VirtualService) OSSM 리소스를 업데이트합니다.

```execute
oc replace -f reviews-weighted-vs.yaml
```

```bash
virtualservice.networking.istio.io/reviews replaced
```

2.5. `traffic_gen.py` 스크립트를 실행하여 가중치 라우팅 구성을 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/100] ✅ HTTP 200 -- red (213.9ms)
[2/100] ✅ HTTP 200 -- No stars (56.5ms)
[3/100] ✅ HTTP 200 -- No stars (15.3ms)
[4/100] ✅ HTTP 200 -- No stars (10.4ms)
[5/100] ✅ HTTP 200 -- No stars (10.0ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ No stars                    │ 81        │               81.0%  │
│ black                       │ 15        │               15.0%  │
│ red                         │ 4         │                4.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

결과값은 다를 수 있습니다.

분배가 구성된 가중치(80/15/5)와 거의 일치하는지 확인하십시오. 이제 가상 서비스(VirtualService) OSSM 리소스가 Kubernetes의 무작위 로드 밸런싱에 의존하는 대신 트래픽 분배를 제어합니다. 이는 가중치 라우팅이 트래픽 비율에 대해 결정론적 제어를 제공함을 보여줍니다.

---

### 3. 사용자 세분화를 위한 헤더 기반 라우팅(header-based routing)을 구현합니다.

이 단계에서는 커스텀 HTTP 헤더를 기반으로 다른 사용자 유형을 다른 서비스 버전으로 지시하는 헤더 기반 라우팅을 구현합니다. 이 기술을 사용하면 애플리케이션 코드를 변경하지 않고도 기능 플래그(feature flagging) 및 사용자 세분화를 수행할 수 있습니다.

`x-user-type` HTTP 헤더를 검사하는 라우팅 규칙을 구성합니다:

| 헤더 값 (Header Value) | 목적지 (Routes To) | 응답 (Response) | 사용 사례 (Use Case) |
|---|---|---|---|
| `x-user-type: internal` | v3 | red stars | 내부 직원(Internal employees)이 최신 기능을 봅니다. |
| `x-user-type: beta` | v2 | black stars | 베타 테스터(Beta testers)가 조기 접근 권한을 얻습니다. |
| *(헤더 없음)* | v1 | No stars | 일반 대중(General public)은 안정적인 버전을 받습니다. |

3.1. `reviews-header-vs.yaml` 파일을 검토합니다. 이 파일은 HTTP 헤더를 기반으로 트래픽을 라우팅하도록 `reviews` 가상 서비스 OSSM 리소스를 업데이트하며, 다음과 같은 작업을 수행합니다:
* `x-user-type: internal` 헤더가 있는 요청을 `reviews-v3`로 라우팅합니다.
* `x-user-type: beta` 헤더가 있는 요청을 `reviews-v2`로 라우팅합니다.
* 다른 모든 요청은 기본적으로 `reviews-v1`로 라우팅합니다.

```execute
cat reviews-header-vs.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - "*"
  gateways:
  - reviews-gateway
  http:
  - match: ❶
    - uri:
        prefix: /reviews
      headers:
        x-user-type:
          exact: internal
    route:
    - destination:
        host: reviews
        subset: v3
  - match: ❷
    - uri:
        prefix: /reviews
      headers:
        x-user-type:
          exact: beta
    route:
    - destination:
        host: reviews
        subset: v2
  - match: ❸
    - uri:
        prefix: /reviews
    route:
    - destination:
        host: reviews
        subset: v1
```

❶ 내부 사용자(internal users)를 v3(최신 기능)로 라우팅합니다.
❷ 베타 테스터(beta testers)를 v2로 라우팅합니다.
❸ 다른 모든 사용자에 대한 기본 경로(default route)를 v1(안정 버전)으로 설정합니다.

3.2. 가상 서비스 OSSM 리소스를 업데이트합니다.

```execute
oc replace -f reviews-header-vs.yaml
```

```bash
virtualservice.networking.istio.io/reviews replaced
```

3.3. 모든 요청에 헤더가 없는 상태로 헤더 기반 라우팅을 테스트합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/100] ✅ HTTP 200 -- No stars (12.9ms)
[2/100] ✅ HTTP 200 -- No stars (7.9ms)
[3/100] ✅ HTTP 200 -- No stars (6.6ms)
[4/100] ✅ HTTP 200 -- No stars (6.6ms)
[5/100] ✅ HTTP 200 -- No stars (7.1ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ No stars                    │ 100       │              100.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

`x-user-type` 헤더가 없는 요청은 기본 라우팅 규칙과 일치하므로 모든 트래픽이 `reviews-v1` (No stars)로 라우팅됩니다. 이는 커스텀 헤더가 없는 요청에 대해 헤더 기반 라우팅이 올바르게 작동함을 확인합니다.

3.4. 헤더가 있는 요청과 헤더가 없는 요청을 혼합하여 보내도록 `mix.yaml` 트래픽 생성기 구성 파일을 확인합니다.

```execute
cat mix.yaml
```

```bash
traffic:
  mode: "mix"
...output omitted...
  items:
    - name: "reviews-v1" ❶
      endpoint: "/reviews/1"
      # No headers for v1 (default route)

    - name: "reviews-v2" ❷
      endpoint: "/reviews/1"
      headers:
        default: {"x-user-type": "beta"}

    - name: "reviews-v3" ❸
      endpoint: "/reviews/1"
      headers:
        default: {"x-user-type": "internal"}
...output omitted...
```

❶ 헤더가 없는 `reviews-v1`에 대한 항목, 기본 버전으로 라우팅됩니다.
❷ `x-user-type: beta` 헤더가 있는 `reviews-v2`에 대한 항목, 베타 버전으로 라우팅됩니다.
❸ `x-user-type: internal` 헤더가 있는 `reviews-v3`에 대한 항목, 내부 버전으로 라우팅됩니다.

3.5. 구성 파일로 `mix.yaml`을 사용하여 `traffic_gen.py` 스크립트를 다시 실행합니다.

```execute-2
traffic_gen.py mix.yaml
```

```bash
traffic_gen.py mix.yaml
   Mix mode: pattern=round-robin, items=3
   reviews-v1: curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   reviews-v2: curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1 -H 'x-user-type: beta'
   reviews-v3: curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1 -H 'x-user-type: internal'
[1] reviews-v1 ✅ HTTP 200 -- No stars (870.2ms)
[2] reviews-v2 ✅ HTTP 200 -- black (1078.6ms)
[3] reviews-v3 ✅ HTTP 200 -- red (1686.7ms)
[4] reviews-v1 ✅ HTTP 200 -- No stars (866.6ms)
[5] reviews-v2 ✅ HTTP 200 -- black (1076.8ms)
[6] reviews-v3 ✅ HTTP 200 -- red (1684.3ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ No stars                    │ 10        │               33.3%  │
│ black                       │ 10        │               33.3%  │
│ red                         │ 10        │               33.3%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

트래픽 생성기의 `mix` 모드는 총 30개의 요청을 보냅니다. 각 항목은 정확히 10개의 요청을 받습니다(33.3% 분포). 스크립트가 각 결과 앞에 항목 이름(`reviews-v1`, `reviews-v2`, `reviews-v3`)을 표시하여 어떤 라우팅 규칙이 테스트되고 있는지 추적하기 쉽게 만듭니다. 응답 분포는 헤더 기반 라우팅이 올바르게 작동함을 확인합니다.

---

### 4. API 버전 관리를 위한 URI 경로 기반 라우팅(URI path-based routing)을 구현합니다.

이 단계에서는 서비스 메시 수준에서 API 버전 관리를 관리하기 위해 경로 기반 라우팅을 구현합니다. 이를 통해 URI 경로를 기반으로 요청을 적절한 백엔드 버전으로 라우팅하면서 여러 버전의 API를 동시에 노출할 수 있습니다.

요청 URI를 검사하는 라우팅 규칙을 구성합니다:

| 요청 경로 (Request Path) | 목적지 (Routes To) | 응답 (Response) | API 버전 (API Version) |
|---|---|---|---|
| `/api/v3/reviews/*` | v3 | red stars | 최신 API 버전 (Latest API version) |
| `/api/v2/reviews/*` | v2 | black stars | 이전 API 버전 (Previous API version) |
| `/reviews/*` | v1 | No stars | 레거시/기본 엔드포인트 (Legacy/default endpoint) |

이 구성의 중요한 측면은 *URI 재작성(URI rewriting)*입니다. 백엔드 `reviews` 서비스는 `/reviews` 엔드포인트만 허용하며 `/api/v3/reviews`와 같은 버전 관리 경로는 허용하지 않습니다. OSSM은 수신 URI를 백엔드로 전달하기 전에 자동으로 재작성하여 `/api/v3/reviews/1`을 `/reviews/1`로 변환합니다.

4.1. URI 경로를 기반으로 트래픽을 라우팅하도록 `reviews` 가상 서비스 OSSM 리소스를 업데이트하는 `reviews-path-vs.yaml` 파일을 검토합니다:
* `/api/v3/*` 경로를 `reviews-v3`로 라우팅합니다.
* `/api/v2/*` 경로를 `reviews-v2`로 라우팅합니다.
* `/api/v1/*` 또는 기본 경로를 `reviews-v1`로 라우팅합니다.

```execute
cat reviews-path-vs.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - "*"
  gateways:
  - reviews-gateway
  http:
  - match: ❶
    - uri:
        prefix: /api/v3/reviews
    rewrite: ❷
      uri: /reviews
    route:
    - destination:
        host: reviews
        subset: v3
  - match:
    - uri:
        prefix: /api/v2/reviews
    rewrite: ❸
      uri: /reviews
    route:
    - destination:
        host: reviews
        subset: v2
  - match: ❹
    - uri:
        prefix: /reviews
    route:
    - destination:
        host: reviews
        subset: v1
```

❶ `/api/v3/reviews` URI 접두사가 있는 요청을 버전 3으로 라우팅하도록 매칭합니다.
❷ 백엔드로 전달하기 전에 URI를 `/api/v3/reviews/*`에서 `/reviews/*`로 재작성합니다.
❸ 버전 2 요청에 대해 URI를 `/api/v2/reviews/*`에서 `/reviews/*`로 재작성합니다.
❹ 안정적인 버전 v1으로 향하는 표준 `/reviews` 경로에 대한 기본 라우팅입니다.

4.2. 가상 서비스 OSSM 리소스를 업데이트합니다.

```execute
oc replace -f reviews-path-vs.yaml
```

```bash
virtualservice.networking.istio.io/reviews replaced
```

4.3. `finite.yaml` 구성 파일이 `/reviews` 엔드포인트로 요청을 보내고 있는지 확인합니다.

```execute
cat finite.yaml
```

```bash
traffic:
  mode: "finite"
  endpoint: "/reviews/1"
...output omitted...
```

4.4. `/reviews`에 대한 요청이 `reviews-v1` (No stars)로 라우팅되는지 확인합니다. `finite.yaml`을 구성 파일로 사용하여 `traffic_gen.py` 스크립트를 실행합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
...
   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ No stars                    │ 100       │              100.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

요청 경로 `/reviews`가 기본 라우팅 규칙과 일치하기 때문에 모든 트래픽이 `reviews-v1` (No stars)로 라우팅됩니다. 이는 경로 기반 라우팅이 레거시 엔드포인트를 올바르게 처리함을 확인합니다.

4.5. `finite-api-v2.yaml` 구성 파일이 `/api/v2/reviews` 엔드포인트로 요청을 보내고 있는지 확인합니다.

```execute
cat finite-api-v2.yaml
```

```bash
traffic:
  mode: "finite"
  endpoint: "/api/v2/reviews/1"
...output omitted...
```

4.6. `/api/v2/reviews`에 대한 요청이 `reviews-v2` (black stars)로 라우팅되는지 확인합니다. `finite-api-v2.yaml`을 구성 파일로 사용하여 `traffic_gen.py` 스크립트를 실행합니다.

```execute-2
traffic_gen.py finite-api-v2.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/api/v2/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/api/v2/reviews/1
[1/100] ✅ HTTP 200 -- black (226.0ms)
[2/100] ✅ HTTP 200 -- black (34.0ms)
[3/100] ✅ HTTP 200 -- black (30.7ms)
[4/100] ✅ HTTP 200 -- black (19.5ms)
[5/100] ✅ HTTP 200 -- black (26.6ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ black                       │ 100       │              100.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

요청 경로 `/api/v2/reviews`가 두 번째 라우팅 규칙과 일치하기 때문에 모든 트래픽이 `reviews-v2` (black stars)로 라우팅됩니다. 가상 서비스는 백엔드로 전달하기 전에 `/api/v2/reviews/1`을 `/reviews/1`로 자동 재작성했습니다. 이는 백엔드 수정 없이 URI 재작성이 API 버전 관리를 가능하게 함을 보여줍니다.

4.7. `finite-api-v3.yaml` 구성 파일이 `/api/v3/reviews` 엔드포인트로 요청을 보내고 있는지 확인합니다.

```execute
cat finite-api-v3.yaml
```

```bash
traffic:
  mode: "finite"
  endpoint: "/api/v3/reviews/1"
...output omitted...
```

4.8. `/api/v3/reviews`에 대한 요청이 `reviews-v3` (red stars)로 라우팅되는지 확인합니다. `finite-api-v3.yaml`을 구성 파일로 사용하여 `traffic_gen.py` 스크립트를 실행합니다.

```execute-2
traffic_gen.py finite-api-v3.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/api/v3/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/api/v3/reviews/1
[1/100] ✅ HTTP 200 -- red (126.0ms)
[2/100] ✅ HTTP 200 -- red (23.7ms)
[3/100] ✅ HTTP 200 -- red (25.0ms)
[4/100] ✅ HTTP 200 -- red (20.2ms)
[5/100] ✅ HTTP 200 -- red (22.4ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ red                         │ 100       │              100.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

요청 경로 `/api/v3/reviews`가 첫 번째 라우팅 규칙과 일치하기 때문에 모든 트래픽이 `reviews-v3` (red stars)로 라우팅됩니다. OSSM이 URI를 재작성하고 요청을 v3로 라우팅하여 세 가지 API 버전 모두에 대한 경로 기반 라우팅 데모를 완료했습니다.

---

### 5. 트래픽 시프팅을 통한 점진적 카나리 배포(progressive canary deployment)를 구현합니다.

이 단계에서는 `reviews` 서비스의 새 버전을 점진적으로 배포하는 실제 카나리 배포 시나리오를 시뮬레이션합니다. 위험을 최소화하기 위해 트래픽의 5%만 새 버전(v3)으로 지시하는 것으로 시작한 다음, 새 버전의 안정성에 대한 확신을 얻음에 따라 25%, 마지막으로 50%로 점차 늘려갑니다.

이 접근 방식은 다음을 가능하게 합니다:
* 최소한의 사용자 영향으로 초기 문제 감지
* 각 단계에서 성능 및 오류율 모니터링
* 문제 발생 시 신속한 롤백
* 전체 배포 전 신뢰성 구축

5.1. v3에 트래픽의 5%를 할당하는 보수적인 카나리 출시를 구현하는 `reviews-canary-5pct-vs.yaml` 파일을 검토합니다.

```execute
cat reviews-canary-5pct-vs.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
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
        subset: v1
      weight: 90 ❶
    - destination:
        host: reviews
        subset: v2
      weight: 5
    - destination:
        host: reviews
        subset: v3
      weight: 5 ❷
```

❶ 안정 버전(stable version)에 대부분의 트래픽을 유지합니다.
❷ 새로운 카나리 버전(v3)에는 트래픽의 5%만 전달하기 시작합니다.

5.2. 가상 서비스 OSSM 리소스를 업데이트합니다.

```execute
oc replace -f reviews-canary-5pct-vs.yaml
```

```bash
virtualservice.networking.istio.io/reviews replaced
```

5.3. 초기 카나리 배포를 확인하여 분배를 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/100] ✅ HTTP 200 -- red (60.2ms)
[2/100] ✅ HTTP 200 -- No stars (42.3ms)
[3/100] ✅ HTTP 200 -- No stars (11.9ms)
[4/100] ✅ HTTP 200 -- No stars (8.3ms)
[5/100] ✅ HTTP 200 -- No stars (7.7ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ No stars                    │ 91        │               91.0%  │
│ red                         │ 5         │                5.0%  │
│ black                       │ 4         │                4.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

결과값은 다를 수 있습니다.

카나리 버전(red/v3)이 구성된 대로 트래픽의 약 5%를 받습니다. 이 최소한의 노출은 새 버전에 문제가 포함된 경우 그 영향을 제한합니다. 프로덕션 시나리오에서는 다음 단계로 진행하기 전에 오류율, 대기 시간 및 비즈니스 메트릭을 모니터링합니다.

5.4. 트래픽을 점진적으로 25%까지 증가시킵니다. `reviews-canary-25pct-vs.yaml` 파일을 검토합니다.

```execute
cat reviews-canary-25pct-vs.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
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
        subset: v1
      weight: 70
    - destination:
        host: reviews
        subset: v2
      weight: 5
    - destination:
        host: reviews
        subset: v3
      weight: 25 ❶
```

❶ 카나리 트래픽을 25%로 증가시킵니다.

5.5. 가상 서비스 OSSM 리소스를 업데이트합니다.

```execute
oc replace -f reviews-canary-25pct-vs.yaml
```

```bash
virtualservice.networking.istio.io/reviews replaced
```

5.6. 증가된 카나리 트래픽을 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/100] ✅ HTTP 200 -- No stars (31.5ms)
[2/100] ✅ HTTP 200 -- red (57.5ms)
[3/100] ✅ HTTP 200 -- No stars (8.9ms)
[4/100] ✅ HTTP 200 -- No stars (9.3ms)
[5/100] ✅ HTTP 200 -- No stars (7.2ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ No stars                    │ 72        │               72.0%  │
│ red                         │ 23        │               23.0%  │
│ black                       │ 5         │                5.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

결과값은 다를 수 있습니다.

카나리 버전(red/v3)이 약 25%의 트래픽을 받아 점진적 출시의 두 번째 단계를 보여줍니다. 이 수준에서 카나리 버전이 원활하게 작동함을 모니터링을 통해 확인한 후, 확신을 가지고 노출을 50%로 늘릴 수 있습니다.

5.7. 트래픽의 50%를 v3로 전환하여 카나리 출시를 완료합니다. 안정 버전과 카나리 버전 간에 트래픽 균형을 맞추는 `reviews-canary-50pct-vs.yaml` 파일을 검토합니다.

```execute
cat reviews-canary-50pct-vs.yaml
```

```bash
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
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
        subset: v1
      weight: 45
    - destination:
        host: reviews
        subset: v2
      weight: 5
    - destination:
        host: reviews
        subset: v3
      weight: 50 ❶
```

❶ 이제 카나리 버전이 트래픽의 절반을 받습니다.

5.8. 가상 서비스 OSSM 리소스를 업데이트합니다.

```execute
oc replace -f reviews-canary-50pct-vs.yaml
```

```bash
virtualservice.networking.istio.io/reviews replaced
```

5.9. 최종 트래픽 분배를 확인합니다.

```execute-2
traffic_gen.py finite.yaml
```

```bash
   Finite mode: 100 requests to http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
   curl -s http://istio-ingressgateway-istio-ingress.apps.ocp4.example.com/reviews/1
[1/100] ✅ HTTP 200 -- No stars (12.8ms)
[2/100] ✅ HTTP 200 -- No stars (7.7ms)
[3/100] ✅ HTTP 200 -- No stars (7.2ms)
[4/100] ✅ HTTP 200 -- red (33.5ms)
[5/100] ✅ HTTP 200 -- red (15.7ms)

...output omitted...

   Response Distribution
================================================================================
┌─────────────────────────────┬───────────┬──────────────────────┐
│ Response                    │ Count     │ Percentage           │
├─────────────────────────────┼───────────┼──────────────────────┤
│ red                         │ 51        │               51.0%  │
│ No stars                    │ 40        │               40.0%  │
│ black                       │ 9         │                9.0%  │
└─────────────────────────────┴───────────┴──────────────────────┘
```

결과값은 다를 수 있습니다.

이제 카나리 버전(red/v3)은 안정 버전과 거의 동일한 약 50%의 트래픽을 받습니다. 이 마지막 단계에서는 새 버전을 완전히 승격하기 전에 프로덕션 수준의 부하를 감당할 수 있는지 검증합니다. 5%에서 25%, 그리고 50%로 이어지는 점진적 카나리 배포 전략을 성공적으로 완료했습니다. 이는 OSSM이 점진적인 트래픽 전환을 통해 위험을 제어하는 롤아웃을 어떻게 가능하게 하는지 보여줍니다.

---

## 실습 완료 (Finish)

워크스테이션 머신에서 `lab` 명령어를 사용하여 이 연습을 완료합니다. 이 단계는 이전 연습의 리소스가 향후 진행될 연습에 영향을 미치지 않도록 하기 위해 중요합니다.

```execute
lab finish meshtraffic-routing
```
