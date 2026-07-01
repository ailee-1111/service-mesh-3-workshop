# ☸️ OpenShift Service Mesh 3.0 (OSSM v3) 공통 오퍼레이터 구성 가이드

본 디렉토리는 새로운 오픈시프트 클러스터 상에 **Red Hat OpenShift Service Mesh 3.0 (OSSM v3 / Sail Operator)** 및 옵저버빌리티 관찰을 위한 핵심 연동 오퍼레이터 4종을 일관되고 반복적으로 배포할 수 있도록 구성한 자동화 패키지입니다.

---

## 🛠️ 오퍼레이터 구성 목록

이 패키지를 통해 `openshift-operators` 전역 네임스페이스 영역에 설치되는 오퍼레이터 정보는 다음과 같습니다:

1. **Red Hat OpenShift Service Mesh 3.0 Operator (`servicemeshoperator3`)**
   - 글로벌 업스트림 표준인 Sail Operator 및 이스티오(Istio) 엔진 기반의 차세대 제어 평면을 가동하는 본체입니다.
2. **Kiali Operator (`kiali-ossm`)**
   - 서비스 메시 전반의 트래픽 흐름, 실시간 호출 토폴로지, 인프라 헬스 체크 상태를 직관적인 UI로 제공하는 그래픽 콘솔입니다.
3. **Red Hat OpenShift distributed OpenTelemetry Operator (`opentelemetry-product`)**
   - W3C 분산 추적 표준(OpenTelemetry) 형식의 메트릭 및 스팬(Span) 데이터를 안전하게 통합 수집하는 콜렉터 오퍼레이터입니다.
4. **Red Hat OpenShift distributed Tempo Operator (`tempo-product`)**
   - 대규모 마이크로서비스 간에 복잡하게 얽힌 분산 트랜잭션 흐름을 대용량 저장소(Object Storage) 기반으로 고속 진단해 주는 추적 백엔드 오퍼레이터입니다.

---

## 🚀 기동 및 사용 방법 (How to Install)

이 패키지는 완전 무인(Automated) 기동이 가능하도록 설계된 검증 스크립트를 내장하고 있습니다.

### 1단계: OCP 클러스터 관리자 로그인
설치 대상 클러스터 2의 관리자(`cluster-admin` 권한을 가진 계정)로 터미널 세션을 먼저 로그인해 줍니다.
```bash
oc login --token=YOUR_CLUSTER_TOKEN --server=https://api.YOUR_CLUSTER_URL:6443
```

### 2단계 (선택): 이전 실습 불필요 자원 및 네임스페이스 정리 (ArgoCD 랩 청소)
새로운 서비스 메시 3.0 실습 환경을 쾌적하고 충돌 없이 이식하기 위해, 기존 ArgoCD 기반의 불필요한 네임스페이스와 오퍼레이터(GitOps Operator 등)를 일괄 제거하는 정리 스크립트를 기동합니다.

```bash
# 1. 정리 스크립트 권한 부여
chmod +x cleanup_unused_resources.sh

# 2. 스크립트 실행
./cleanup_unused_resources.sh
```

### 3단계: 자동 설치 스크립트 실행
본 디렉토리 하위의 `install-operators.sh` 스크립트를 기동합니다. 스크립트가 오퍼레이터 리소스를 반영한 뒤, 4종 오퍼레이터가 클러스터 내에 무사히 주입되어 최종 'Succeeded' 성공 단계를 얻을 때까지 실시간으로 추적하며 대기합니다.

```bash
# 1. 설치 스크립트 권한 부여
chmod +x install-operators.sh

# 2. 스크립트 실행
./install-operators.sh
```

### 4단계: 다중 사용자 격리 서비스 메시 및 추적(Tracing) 인스턴스 전개
오퍼레이터 설치가 완료되면, 서비스 메시 3.0 실습에 필요한 글로벌 자원(글로벌 CNI, MinIO 및 TempoStack 분산 추적 백엔드) 및 다중 사용자별(`user1`~`user5`) 격리된 제어 평면(`Istio`), 시각화 대시보드(`Kiali`), 수집기(`OpenTelemetryCollector`), 사용자 전용 인그레스 게이트웨이(`istio-ingressgateway`)를 일괄 생성하는 인스턴스 구성 자동화 스크립트를 기동합니다.

```bash
# 1. 인스턴스 구성 스크립트 권한 부여
chmod +x install-mesh-instances.sh

# 2. 스크립트 실행 (사용자 수 기본 5명 오토-스포닝, 오버라이드 원할 시 USER_COUNT=10 등으로 실행 가능)
./install-mesh-instances.sh
```

---

## 🔍 수동 검증 및 검사 방법 (How to Verify)

설치가 진행된 후, 아래의 명령들을 활용해 정상 배포 상태를 직접 확인하실 수 있습니다.

### 1. Subscription 상태 검사
각 오퍼레이터가 카탈로그 소스로부터 맞게 구독 신청을 완료했는지 조회합니다.
```bash
oc get subscription -n openshift-operators
```

### 2. CSV(ClusterServiceVersion) 상태 검사
각 오퍼레이터의 컨테이너 기동 및 롤바인딩 권한 생성이 완벽히 성공하여 `Succeeded` 단계에 도달했는지 확인합니다.
```bash
oc get csv -n openshift-operators
```
* **성공 기준 예시:**
  ```
  NAME                              DISPLAY                                       VERSION     PHASE
  kiali-operator.v2.22.6            Kiali Operator                                2.22.6      Succeeded
  opentelemetry-operator.v0.152.0-1 Red Hat OpenShift distributed OpenTelemetry  0.152.0-1   Succeeded
  servicemeshoperator3.v3.3.5       Red Hat OpenShift Service Mesh                3.3.5       Succeeded
  tempo-operator.v0.21.0-2          Red Hat OpenShift distributed Tempo          0.21.0-2    Succeeded
  ```
