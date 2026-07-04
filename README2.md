# ☸️ OpenShift Service Mesh 3.0 Workshop 신규 클러스터 전개 및 프로비저닝 가이드 (README2)

본 문서는 신규 오픈시프트 클러스터 상에 **Red Hat OpenShift Service Mesh 3.0 (OSSM v3 / Sail Operator)** 기반의 다중 사용자 격리(Multi-tenant, isolated) 실습 환경 및 가이드북 대시보드(Homeroom)를 처음부터 끝까지 완전 무결하게 자동 배포하고 제공하기 위한 **최종 관리자 운영 매뉴얼**입니다.

이 가이드를 준수하면, 신규 클러스터가 프로비저닝된 직후 **지정된 유저 수(예: 20명)**에 맞추어 모든 필요한 서비스 메시 제어 평면, 분산 추적(Tempo Stack / OTel), Kiali 관제판 및 학생 실습용 웹 터미널 환경을 단 몇 번의 스크립트 실행만으로 완벽하게 전개하여 실전 핸즈온 랩 서비스를 즉시 개시할 수 있습니다.

---

## 🚀 전체 전개 시퀀스 요약 (Workflow)

```
[1단계: 불필요한 기존 자원 삭제] ➔ [2단계: 핵심 오퍼레이터 4종 설치] ➔ [3단계: 다중 유저 격리 메시 인프라 빌드] ➔ [4단계: 워크숍 대시보드(Homeroom) 배포]
```

---

## 🧹 1단계: 불필요한 기존 실습 자원 일괄 정리 (ArgoCD 등 삭제)

새로운 서비스 메시 3.0 실습 환경을 깨끗하게 적용하기 위해, 기존 클러스터에 기본 내장되어 있거나 잔류하고 있을 수 있는 ArgoCD(OpenShift GitOps) 오퍼레이터 및 관련 임시 showroom 사용자별 네임스페이스 장벽들을 완벽하게 소멸 정리하는 단계입니다.

### 1. 전역 오픈시프트 클러스터 관리자 로그인
먼저 워크스테이션 터미널에서 신규 클러스터 2의 **클러스터 관리자(kubeadmin 또는 admin)** 권한 토큰을 사용하여 정상 로그인을 단행합니다.

```bash
# 예시: README.md에 기재된 클러스터 2 관리자 계정 정보로 로그인
oc login -u admin -p MjcwMjI3 https://api.cluster-pgx9x.pgx9x.sandbox3385.opentlc.com:6443 --insecure-skip-tls-verify
```

### 2. 청소 스크립트 실행 및 걸림(Terminating) 대비 강제 삭제(Force Delete) 기능 기동
`ServiceMesh3` 최상위 폴더 하위에 마련된 다음 자동 정리 스크립트를 기동합니다. 이 스크립트 또한 **고정된 5인 방식이 아닌, 관리자가 선언한 `USER_COUNT` 환경변수를 상속받아 동적으로 작동**하므로, 클러스터 규모에 맞게 실시간 동적 대입 처리가 성료됩니다:

```bash
export USER_COUNT=20 # 동적으로 정리할 대상 사용자 정수를 기입 선언합니다.
cd ~/gemini/ServiceMesh3/common-setup
chmod +x cleanup_unused_resources.sh
./cleanup_unused_resources.sh
```

> [!IMPORTANT]
> **💡 Terminating 네임스페이스 강제 소거(Force Delete Finalizers) 완수 솔루션 내장**
> 오픈시프트 환경 상에서 `userX-argocd` 네임스페이스를 삭제할 때, ArgoCD의 리소스 관리용 파이널라이저(Finalizers) 장벽이 잔류하여 네임스페이스 상태가 **`Terminating` (삭제 중 걸림)** 단계에 걸려 영구히 지워지지 않는 고질적인 쿠버네티스 버그 현상이 발생하곤 합니다.
> 
> 본 패키지에 제공되는 `cleanup_unused_resources.sh` 스크립트는 이 걸림 현상을 정밀 실시간 자동 감지하여, **12초 이상 삭제 지체가 감지될 경우 해당 네임스페이스의 `spec.finalizers`를 파이썬 파싱 장치로 즉석 소거한 뒤 로컬 API를 통해 강제 파괴 삭제(Force-delete finalized API replacement) 처리**하여 1초 만에 완전 소멸 완료시키는 막강한 지능형 자동화가 내장 장착되어 있습니다!
> 
> * 만일 수동으로 특정 프로젝트 네임스페이스(예: `user1-argocd`)를 직접 즉석 강제 삭제하고 싶다면 다음 원라인 치환 커맨드를 터미널에 단독 복사 실행하셔도 즉각 완전 청소 처리됩니다:
>   ```bash
>   oc get namespace user1-argocd -o json | python3 -c "import sys, json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; json.dump(d, sys.stdout)" > /tmp/force-delete.json && oc replace --raw "/api/v1/namespaces/user1-argocd/finalize" -f "/tmp/force-delete.json" && rm -f /tmp/force-delete.json
>   ```

**수행 결과 예시:**
```text
==========================================================
🧹 불필요한 ArgoCD 실습 관련 자원 및 네임스페이스 정리 시작
==========================================================
🎯 로그인 확인 완료. 불필요한 네임스페이스 및 오퍼레이터 정리를 개시합니다...
📂 1. 불필요한 실습 네임스페이스 일괄 삭제 대상 식별 중...
🗑️  openshift-gitops-operator Subscription 제거 중...
⏱️  네임스페이스들이 클러스터에서 완전히 청소될 때까지 대기합니다...
   ✅ 네임스페이스 'user1-argocd' 제거 완료!
==========================================================
🎉 불필요한 자원 및 오퍼레이터 일괄 청소가 완료되었습니다!
==========================================================
```

---

## 🧩 2단계: 핵심 서비스 메시 3.0 연동 오퍼레이터 4종 일괄 설치

서비스 메시 3.0(Sail Operator) 구동 및 distributed tracing 텔레메트리 관제를 위해 필요한 **4대 핵심 공용 오퍼레이터** 서브스크립션을 한 번에 정격 주입 설치하고, 정상 완료(Succeeded) 상태에 도달할 때까지 실시간 모니터링 대기해 주는 단계입니다.

* **설치 대상 오퍼레이터 4종:**
  1. **Red Hat OpenShift Service Mesh 3.0** (Sail Operator 기반)
  2. **Kiali Operator** (서비스 메시 L7 시각화 관제탑)
  3. **Red Hat build of OpenTelemetry** (원격 텔레메트리 스팬 가공 및 전송기)
  4. **Red Hat build of distributed Tempo** (고성능 distributed tracing 시계열 저장소)

### 1. 오퍼레이터 자동 빌드 및 감시 스크립트 가동

```bash
cd ~/gemini/ServiceMesh3/common-setup
chmod +x install-operators.sh
./install-operators.sh
```

* 이 스크립트는 `01_operators/` 디렉토리에 정의된 각 오퍼레이터의 Subscription YAML을 선제 대입 적용하고, 최대 5분간 10초 간격으로 이들 4종 장비가 성공적으로 설치 완료(`status.phase == Succeeded`) 처리가 되는지 동적 루프 검증합니다.

**수행 결과 예시:**
```text
======================================================================
☸️  OpenShift Service Mesh 3.0 공통 오퍼레이터 설치 자동화 시작
======================================================================
🚀 [Step 1/2] 서비스 메시 3.0 핵심 오퍼레이터 4종 배포를 시작합니다...
subscription.operators.coreos.com/kiali-subscription created
subscription.operators.coreos.com/opentelemetry-subscription created
subscription.operators.coreos.com/service-mesh-subscription created
subscription.operators.coreos.com/tempo-subscription created

⏱️  [Step 2/2] 오퍼레이터 기동 및 설치 완료(Succeeded) 상태를 대기합니다...
📊 설치 현황 (시도 1/30): 0/4 완료
   - servicemeshoperator3.v3.3.5 Pending
📊 설치 현황 (시도 2/30): 4/4 완료
   - servicemeshoperator3.v3.3.5 Succeeded
   - kiali-operator.v2.11.0 Succeeded
   - opentelemetry-operator.v0.152.0-1 Succeeded
   - tempo-operator.v0.21.0-2 Succeeded
🎉 [Success] 서비스 메시 3.0 핵심 오퍼레이터 4종의 설치가 완벽하게 완료되었습니다!
```

---

## 🏗️ 3단계: 다중 사용자 격리(Multi-tenant) 서비스 메시 및 트레이스 인프라 전개

오퍼레이터 설치가 완수되면, 이제 대망의 **지정된 사용자 정수(예: 20명)**에 부합하도록 공통 분산 추적 백엔드(MinIO & TempoStack)를 전착시키고, 유저별 개별 `userX-istio-system` 제어 평면 및 인그레스 게이트웨이, 메트릭 전용 수집기들을 동적 루프 조립하여 100% 무결 격리 전개하는 단계입니다.

### 1. 사용자 정수(USER_COUNT=20) 명시 후 빌드 기동
기본적으로 스크립트가 실행될 때 클러스터 상의 기존 userX 계정 도메인을 자동 검색하여 정수를 판독하지만, **신규 클러스터 전개 시점에는 우리가 원하는 사용자 정원 수치(예: 20명)를 환경 변수 `USER_COUNT` 상에 명시적으로 상속 주입**하여 기동해야만 무결한 20인 전용 샌드박스가 완성됩니다.

```bash
cd ~/gemini/ServiceMesh3/common-setup
chmod +x install-mesh-instances.sh

# 매우 중요: 20인 대상을 선포한 상태에서 인프라 구성 스크립트 실행!
export USER_COUNT=20
./install-mesh-instances.sh
```

### 2. 자동화 스크립트 내부 주요 조립 수순 (What it does behind the scenes):
1. **글로벌 IstioCNI 활성화:** 전체 노드의 L7 하이재킹 네트워크 흐름을 통제합니다.
2. **글로벌 분산추적 Tempo 셋업:** 공용 고성능 tracing-system을 가용화하기 위해 `minio` 스토리지 디플로이먼트, PVC, 서비스 및 전역 `TempoStack` 자산을 `user1-istio-system` 등과 연동합니다.
3. **글로벌 Kiali 공유 인스턴스 기동:** 개별 Kiali 리소스를 유저수만큼 20개 난무하여 띄우면 노드 메모리가 즉시 100% 고사하므로, 단 하나의 고가용성 **공유 Kiali 콘솔**을 `istio-system` 전역 네임스페이스 하위에 기동시켜 리소스 낭비를 막고, 각 userX 별로 자기 파드만 격리 관제해 보이도록 가시화 권한을 지능적으로 이식합니다.
4. **다중 유저 루프 셋업 (1~20):**
   - 유저당 독립 제어 평면(`userX-istio-system`) 프로젝트 개설 및 이스티오 전용 discovery 디렉토리 레이벨링 주입 성료.
   - 유저당 독립 입구 관문(`userX-istio-ingress`) 전용 프로젝트 개설 및 인그레스 게이트웨이(`istio-ingressgateway`) 배포 성료.
   - 유저당 독립 OTel Collector 및 분산 추적 Telemetry, 메트릭 수집용 PodMonitor/ServiceMonitor 자산이 1~20번 유저까지 단 한치의 흐트러짐 없이 정합 주입 완수됩니다!

---

## 🖥️ 4단계: 워크숍 가이드북 대시보드(Homeroom) 및 스포너 배포

모든 백엔드 격리 네트워크와 수집 엔진 장비 전개가 끝났으므로, 학생들이 브라우저로 들어와 교재를 보고 코딩하며 즉석 터미널 실습을 이행할 수 있는 **Homeroom 워크숍 대시보드 및 웹 콘솔 파드 스포너(Spawner)**를 전개 배포하는 마지막 단계입니다.

### 1. Homeroom 배포 스크립트 기동
```bash
cd ~/gemini/ServiceMesh3/common-setup/02_homeroom
chmod +x deploy-homeroom.sh
./deploy-homeroom.sh
```

* 이 스크립트는 `homeroom` 전용 네임스페이스를 생성하고, 학생들이 Kiali 관제와 OTel 수집, 빌드 파드를 통제할 수 있도록 강력한 정식 RBAC 롤 바인딩(`podmonitor-rbac.yaml`, `homeroom-console-rbac.yaml`)을 부여한 뒤, `workshop-spawner` 컨트롤러를 정격 전개 수립 완료시킵니다.

### 2. 가이드북 마스터 콘텐츠 빌드 (build 1 기동)
배포가 성료 되면, 깃허브에서 PDFs 가 완벽히 배제 차단 처리된 `.dockerignore` 가이드 필터를 탑재한 마스터 리소스를 최초로 가속 빌드 롤아웃 시켜주어야만 대시보드가 정상 개화됩니다.

```bash
# 72차 base 빌드 이후 신규 최초 빌드(build 1 등) 전격 개시!
oc start-build workshop-content -n homeroom --wait=false
```

---

## 🛠️ 5단계: 학생들에게 실습 제공 및 사후 운영 체크리스트 (Verification)

위의 4대 전개 시퀀스가 에러 없이 정상 완료되고 빌드가 안착되고 나면, 마침내 학생들에게 주소를 개방하여 핸즈온 교육을 선사할 수 있습니다.

### 1. 학생 접속 및 대시보드 로그인 URL 배포
* **대시보드 콘솔 주소 확인:**
  ```bash
  oc get route workshop-spawner -n homeroom -o jsonpath='{.spec.host}'
  ```
  - 위의 터미널 출력 결과로 나오는 고유 FQDN 주소(예: `https://workshop-spawner-homeroom.apps.cluster...`)를 학생들에게 배포합니다.
* **접속 방법:** 
  학생들은 브라우저를 열고 해당 주소로 접속한 뒤, 각자 부여받은 계정 정보(예: `user1`~`user20` 및 공용 암호 `openshift` 또는 각자 부여된 비밀번호)를 타이핑하여 개인 웹 터미널을 개설합니다.

### 2. 가동 상태 점검을 위한 관리자 체크리스트 (Admin Checksheet)
인프라 전개 수립 이후, Kiali 및 OTel 추적 선로의 무결성을 원격 검수하기 위해 다음 사항들을 점검하십시오:

* **TempoStack 및 OTel 전역 흡입 상태 검수:**
  ```bash
  oc get pods -n tracing-system
  ```
  - `minio-` 및 `tempo-product-` 파드 복제본들이 모두 차질 없이 `Running` 상태를 유지하고 있는지 조회합니다.
* **공유 Kiali 콘솔 가용성 검수:**
  ```bash
  oc get pods -n istio-system
  ```
  - `kiali-` 관제 파드가 정상 구동 중인지 검수합니다.
* **학생 제어평면(istiod) 및 게이트웨이 구동 검수:**
  ```bash
  oc get pods -n user4-istio-system
  oc get pods -n user4-istio-ingress
  ```
  - 각 유저별 격리 파드들이 `2/2` 가용 상태(Envoy 동반 완료) 및 `Running` 상태로 정상 안착되어 인입 트래픽을 대기 중인지 최종 점검 완료합니다!

---

**축하합니다! 이로써 신규 배포된 클러스터 상에 단 한 장의 불필요한 PDF 노출이나 리소스 꼬임 현상이 완벽히 차단 격리된 가장 가볍고 미려한 차세대 오픈시프트 서비스 메시 3.0 명품 실습 교육장 인프라 구성이 완수되었습니다!**
