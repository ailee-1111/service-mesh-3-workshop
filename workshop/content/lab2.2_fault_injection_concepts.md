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

# 모듈 2.2: 장애 주입(Fault Injection) 개념 (Fault Injection with OpenShift Service Mesh)

오픈시프트 서비스 메시 환경 하에서 소스 코드 수정 없이 인위적 장애 지연(Delay) 및 즉각적 오류 회신(Abort)을 주입해 보는 카오스 엔지니어링(Chaos Engineering) 기법을 학습합니다. 이를 통해 분산 마이크로서비스 아키텍처 상의 잠재적 취약성과 연쇄 실패(Cascading Failures) 지점을 사전에 스캐닝하여 회복력을 한계까지 끌어올립니다.

## 학습 목표 (Objectives)
* 서비스 메시 하위에서 장애 주입(Fault Injection)을 가동하는 실무 목적과 아키텍처적 가치를 명확히 규명합니다.
* 느린 백엔드 및 타임아웃 레이턴시를 시뮬레이션하기 위한 지연 장애(Delay Faults) 구성 방안을 체득합니다.
* 특정 HTTP/gRPC 에러 코드를 동반 수반하여 종료시키는 중단 장애(Abort Faults) 구성 방안을 설계합니다.
* 실 운영 유저에게 악영향을 주지 않고 안전하고 효과적으로 장애 주입 테스트를 감당하기 위한 모범 참조 사례(Best Practices)를 습득합니다.

---

## 1. 장애 주입(Fault Injection)과 카오스 엔지니어링

분산 시스템에서는 네트워크 지연, 서버 노후화, 가부하 등 통제 불가능한 요인으로 인해 수많은 네트워크 에러와 레이턴시 급증 현상이 예측할 수 없이 상시 발생합니다. 이에 대응하는 완벽한 자가 치유 애플리케이션을 구축하려면, 우리 서비스가 실제 장애 유발 상황에서 어떻게 대응하고 견디는지 실전 자극 테스트를 선행해야만 합니다.

* **카오스 엔지니어링 (Chaos Engineering):**
  운영 환경의 불확실한 네트워크 레이턴시 및 돌발적 전산 지연을 인위적으로 모사하여, 아키텍처 배후의 약점과 단절선들을 유저에게 도달하기 전에 선제적으로 찾아내어 치유하는 최선진 엔지니어링 실무입니다.
* Red Hat OpenShift Service Mesh는 **애플리케이션 비즈니스 코드를 단 한 줄도 고치거나 파드를 무단 리부팅하는 비용 소모 없이**, 오직 이스티오 가상 서비스(`VirtualService`) 설정의 `HTTPFaultInjection` 구성 셋업만으로 매우 안전하고 통제된 카오스 엔지니어링 장애 테스트를 동적 개시할 수 있게 해줍니다.

오픈시프트 서비스 메시는 가상 서비스 API 하위에 다음과 같은 대표적인 장애 주입 유형 2종을 정식 배포 지원합니다:

### ① 지연 장애 (Delays)
네트워크 레이턴시 증가 현상이나 특정 마이크로서비스 노드의 백엔드 DB 가부하 현상을 모사하기 위해, 요청 패킷 전달 중간 선로에 인위적 딜레이(Delay)를 강제 주입합니다. 이를 통해 타임아웃(Timeout) 및 재시도(Retry) 설계 임계 한계선이 실제로 잘 개입하여 작동하는지 스트레스 검증을 완수할 수 있습니다.

### ② 중단 장애 (Aborts)
지정된 HTTP 상태 코드(예: 503 Service Unavailable)나 gRPC 에러 코드를 클라이언트에 즉각 반사 회신하여 통신을 중단(Abort)시킵니다. 이를 통해 서비스 내부의 에러 핸들링 모듈, 대비 백업 로직(Fallback), 그리고 서킷 브레이커(Circuit Breaker)가 완벽하게 개입하여 연쇄 하위 무력화를 막아내는지 물리 검증할 수 있습니다.

---

## 2. 지연 장애(Delay Faults)의 정밀 구성 방안

특정 하위 디펜던시 서비스 지연을 시뮬레이션하기 위해, 가상 서비스 내부의 `fault.delay` 설정 블록을 설계 매립합니다.

주요 가용 매개변수 속성은 다음과 같습니다:
* **percentage (백분율 비율):** 지연 장애 효과를 적용받을 요청의 누적 확률 비율(%)을 규정합니다. 각 진입 요청은 독립적인 수학 확률에 근거하여 이 장애 효과를 개입 적용받게 됩니다. (예: `value: 10.0` 선언 시 총 유입 트래픽의 10% 비율에만 지연 주입 개입)
* **fixedDelay (고정 지연 시간):** 강제 딜레이 처리시킬 대기 소요 임계치를 정의합니다 (예: 5초 지체 유발 시 `fixedDelay: 5s`).

다음 가상 서비스 예제 명세서는 `example-svc`로 유입되는 총량 중 **`10%`**의 요청에 대해 인위적으로 무려 **`5초`**의 통신 지체 레이턴시 장벽을 강제 이식하여 레이아웃을 튜닝하는 설계서입니다:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: example-vs
spec:
  hosts:
  - example-svc
  http:
  - route:
    - destination:
        host: example-svc
        subset: v1
      fault: ❶
        delay: ❷
          percentage: ❸
            value: 10.0
          fixedDelay: 5s ❹
```

❶ 장애 주입 구성을 전담 제어하는 `HTTPFaultInjection` API 제어 블록을 활성화합니다.
❷ 인위 지연(Delay) 장애를 기동하기 위한 세부 명세 장부를 개설합니다.
❸ 지연 장애를 적용할 타깃 트래픽 비중을 정확히 누적 **10%** 확률 비율로 한정 통제합니다.
❹ 유입 트래픽에 가해질 순수 인위 대기 지연 시간을 물리 **5초(5s)**로 강제 잠정 적용시킵니다.

---

## 3. 중단 장애(Abort Faults)의 정밀 구성 방안

백엔드 마이크로서비스의 치명적 시스템 크래시 및 에러 덤프 반응을 시뮬레이션하기 위해 가상 서비스 내부에 `fault.abort` 설정 블록을 매립 장착합니다.

주요 가용 매개변수 속성은 다음과 같습니다:
* **percentage (백분율 비율):** 중단 장애 효과를 기습 적용받아 통신이 터미네이션 강제 단절될 요청의 수학적 누적 비중(%)을 정의합니다. (예: `value: 20.0` 선언 시 유입 트래픽의 20%를 기습 에러 탈락 처리)
* **httpStatus (HTTP 상태 코드):** 클라이언트에 회신하여 반사할 L7 HTTP 상태 코드를 매핑합니다 (예: `httpStatus: 503` 지정 시 즉각 503 Service Unavailable 오류 반사).
* **grpcStatus (gRPC 상태 코드):** 타깃 마이크로서비스가 고성능 gRPC 프로토콜 통신 장비일 경우 활용하며, 회신할 에러 명세를 기입합니다 (예: `UNAVAILABLE`). HTTP 통신 규격일 때에는 본 매개변수를 완전히 공백 생략합니다.

다음 가상 서비스 예제 명세서는 `example-svc`로 유입되는 전체 요청 수량 중 무려 **`20%`**의 요청에 대해, 물리적으로 파드를 끄거나 건들지 않고 이스티오 프록시 단에서 즉시 **`HTTP 503 Service Unavailable`** 가상 에러 코드를 클라이언트에 인앱 반사하여 통신을 즉시 폭파 중단(abort)시키는 설계 원안을 수립 정의합니다:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: example-vs
spec:
  hosts:
  - example-svc
  http:
  - route:
    - destination:
        host: example-svc
        subset: v1
      fault: ❶
        abort: ❷
          percentage: ❸
            value: 20.0
          httpStatus: 503 ❹
```

❶ 장애 주입 구성을 제어하는 `HTTPFaultInjection` 제어 필터를 적용합니다.
❷ 통신 즉각 단절 및 에러 반사용 중단(Abort) 장애 제어 장부를 개설합니다.
❸ 중단 폭파 처리를 가할 유입 비중을 전착 트래픽의 정확히 **20%** 비율로 규정 한정합니다.
❹ 클라이언트 브라우저로 뿜어내어 반사시킬 가상 에러 코드로 표준 **HTTP 503** 번을 주입 각인합니다.

---

## 4. 장애 주입(Fault Injection)의 안전하고 효과적인 4대 가이드라인

운영 중인 서비스 환경 하에서 시스템의 견고함을 극대화하고 무결하게 카오스 엔지니어링 자극 테스트를 소화하기 위해 반드시 견지해야 할 **4대 핵심 안전 가이딩 규칙**을 정독 이해합니다.

1. **지상 과제: 소규모의 미세한 자극부터 개시 (Start Small):**
   - 최초 장애 주입 설계 시부터 100% 비율로 장애를 이식하는 무리수를 범할 경우 소중한 서비스 전체가 즉각 차단되는 낭패를 봅니다. 반드시 카나리 배포와 마찬가지로 아주 작고 미세한 비중(예: 1~5% 가량의 트래픽 주입)에서만 선행 가동하거나, 내부 QA 소속 전용 계정 헤더(`exact: testuser`) 매칭 조건문 하단에만 장애 설정을 격리 이식하여 철저하게 격리 검증하십시오.
2. **가시성의 투명화: 모니터링 경보 수립 철저 (Monitor Everything):**
   - 장애 주입이 기동되는 순간 `Kiali` 실시간 트폴로지 차트에 노출되는 커넥션 에러 비율 선로와 `Prometheus/Grafana` 지표 변동 레이턴시 곡선 추이를 정밀 매칭 검수하십시오. 장애 주입 상황에서도 자가 치유 경보(Alerting) 장벽이 설정 수치에 맞춰 제각각 울려주는지 철저한 연동 알람 검수를 필히 수행해야 합니다.
3. **가속화: 즉각적 규칙 제거 자동화 (Automate Cleanup):**
   - 카오스 검수 테스트 사이클이 정식 종료되는 즉시, 배포했던 가상 서비스 장애 주입 YAML 명세를 즉각 삭제 및 기본 무장애 통제 버전으로 리스타트 롤아웃하는 스크립트화 자동화 시스템을 필히 내장하십시오. 검수가 끝났음에도 깜빡 잊고 방치해 두는 인재는 실 사용자의 대량 이탈을 수반하는 참극을 낳게 됩니다.
4. **스테이징 환경 완벽 분리 활용 (Test in Representative Environment):**
   - 가중치 및 회복력 테스트는 실제 프로덕션 환경과 최대한 기하학적 아키텍처 토폴로지 구조가 일치 수렴하는 격리된 검증 스테이징(Staging) 환경 하에서 안전한 위임 권한 하에 단행해야만 불필요한 인재와 규제 컴플라이언스 이탈 위험을 완전히 제거해 낼 수 있습니다.
