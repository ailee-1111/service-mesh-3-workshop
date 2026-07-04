#!/bin/bash
# ==============================================================================
# OpenShift Service Mesh 3.0 Workshop - 다중 유저별 격리 인프라 자동화 배포 스크립트 (Kiali 공유 모델)
# ==============================================================================
set -eo pipefail

echo "=========================================================="
echo "☸️  오픈시프트 서비스 메시 3.0 다중 사용자 격리 인프라 구성 시작"
echo "=========================================================="

# 1. 오픈시프트 접속 여부 점검 및 API 서버 주소 자동 추출
if ! oc whoami &>/dev/null; then
    echo "❌ [Error] 오픈시프트 세션이 없습니다. 먼저 'oc login'을 실행해 주세요."
    exit 1
fi

API_SERVER=$(oc whoami --show-server 2>/dev/null || true)
if [ -z "$API_SERVER" ]; then
    echo "❌ [Error] 오픈시프트 서버 주소를 가져올 수 없습니다. 'oc login' 세션을 점검해 주세요."
    exit 1
fi

echo "🎯 1. OCP 연결 성공: $(oc whoami) (API: $API_SERVER)"

# 2. Apps 서브도메인 자동 파싱
CLEAN_SERVER=$(echo "$API_SERVER" | sed -e 's|https://||' -e 's|:[0-9]*$||' -e 's|^api\.||')
NEW_SUBDOMAIN="apps.$CLEAN_SERVER"
echo "   🌐 클러스터 앱 서브도메인: $NEW_SUBDOMAIN"

# 3. 클러스터 내의 userX 사용자 정원 동적 감지 (환경 변수 오버라이드 지원)
echo "🔍 2. 클러스터 상의 사용자(userX) 구성 상태 감지 중..."
DETECTED_USERS=$(oc get projects --no-headers 2>/dev/null | grep -E -o "user[0-9]+" | sort -u | wc -l | tr -d ' ' || echo "0")
USER_COUNT="${USER_COUNT:-$DETECTED_USERS}"

if [ "$USER_COUNT" -eq 0 ] || [ -z "$USER_COUNT" ]; then
    # [수정필요] 클러스터에 사용자가 아직 로그인하지 않았을 때 적용할 기본 가상 사용자 수를 조절하려면 아래 USER_COUNT=5 값을 10, 20 등으로 직접 수정하세요.
    echo "   ⚠️  userX 형태의 프로젝트가 감지되지 않았습니다. 기본값인 5명으로 격리 환경을 전개합니다."
    USER_COUNT=5
else
    echo "   👥 감지된 고유 사용자 수(userX): $USER_COUNT 명"
fi

# 4. 글로벌 공통 인프라(CNI, MinIO, TempoStack) 배포
echo "📦 3. 글로벌 공통 서비스 메시 인프라 및 추적 백엔드 배포..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# [UWM 활성화] Kiali 트래픽 토폴로지 감지 및 OTel 수집의 100% 정상 작동을 위한 사용자 워크로드 모니터링 개방
echo "   ➡️ [UWM] 오픈시프트 전역 사용자 워크로드 모니터링(User Workload Monitoring) 기동 활성화..."
cat <<EOF | oc apply -f - 2>/dev/null || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF

# Global CNI 인스턴스 적용 전, IstioCNI CRD가 API 서버 상에 활성화될 때까지 검수 대기 (최대 60초)
echo "🔍 CNI 인스턴스 생성 전, IstioCNI CRD의 정식 등록 여부를 검수 대기합니다..."
crd_try=1
while [ "$crd_try" -le 12 ]; do
    if oc get crd istiocnis.sailoperator.io &>/dev/null; then
        echo "   ✅ IstioCNI CRD가 정상적으로 클러스터 상에 안착 활성화되었습니다!"
        break
    fi
    echo "   ⏳ CRD 등록 대기 중 ($crd_try/12)... 5초 후 재시도"
    sleep 5
    crd_try=$((crd_try + 1))
done

# Global CNI 인스턴스 적용
echo "   ➡️ [CNI] 글로벌 IstioCNI 인스턴스 기동..."
oc apply -f "$SCRIPT_DIR/01_operators/istio-cni-instance.yaml"

# Global 모니터링 관리자 권한 집계 적용 (학생들이 PodMonitor를 생성할 수 있도록 허용)
echo "   ➡️ [RBAC] 전역 PodMonitor 권한 집계 주입..."
oc apply -f "$SCRIPT_DIR/02_homeroom/podmonitor-rbac.yaml"

# Global Tracing-System 적용
echo "   ➡️ [Tracing] MinIO 및 TempoStack 백엔드 기동..."
oc apply -f "$SCRIPT_DIR/03_tracing/minio-and-tempo.yaml"
oc apply -f "$SCRIPT_DIR/03_tracing/tempo-rbac.yaml"

# Global Kiali 공유 인스턴스 전개 (오픈시프트 콘솔 메뉴 완벽 노출 및 자원 낭비 최소화)
echo "   ➡️ [Kiali] 글로벌 공유 Kiali 및 모니터링 연동 기동..."
cp "$SCRIPT_DIR/03_tracing/kiali-shared.yaml" /tmp/kiali-shared-temp.yaml
perl -pi -e "s/YOUR_NEW_CLUSTER_SUBDOMAIN/${NEW_SUBDOMAIN}/g" /tmp/kiali-shared-temp.yaml
oc apply -f /tmp/kiali-shared-temp.yaml

# 5. 다중 사용자별 개별 격리 인스턴스 생성 루프 (학생 실습지 프로젝트 생성 단계는 배제하고 제어평면만 배포)
echo "📦 4. 사용자별($USER_COUNT명) 격리 서비스 메시 및 인그레스 게이트웨이 전개..."
TEMPLATE_DIR="$SCRIPT_DIR/03_instances/user-template"
RENDER_DIR="/tmp/rendered-mesh-instances"
rm -rf "$RENDER_DIR" && mkdir -p "$RENDER_DIR"

i=1
while [ "$i" -le "$USER_COUNT" ]; do
    USER_NAME="user$i"
    echo "   👉 [사용자 $USER_NAME] 전용 격리 환경 조립 중..."
    
    USER_RENDER_DIR="$RENDER_DIR/$USER_NAME"
    mkdir -p "$USER_RENDER_DIR"
    
    # 템플릿 파일을 읽어 플레이스홀더를 사용자에 맞게 치환 (Kiali CR은 전역 기동이므로 템플릿 처리 시 제외)
    for f in "$TEMPLATE_DIR"/*.yaml; do
        filename=$(basename "$f")
        if [ "$filename" != "kiali-cr.yaml" ] && [ "$filename" != "kiali-viewer-crb.yaml" ] && [ "$filename" != "kiali-monitoring-crb.yaml" ]; then
            cp "$f" "$USER_RENDER_DIR/$filename"
            perl -pi -e "s/USER_NAME_PLACEHOLDER/${USER_NAME}/g" "$USER_RENDER_DIR/$filename"
            perl -pi -e "s/YOUR_NEW_CLUSTER_SUBDOMAIN/${NEW_SUBDOMAIN}/g" "$USER_RENDER_DIR/$filename"
        fi
    done
    
    # 해당 사용자의 네임스페이스 기동 및 레이블 설정
    echo "      📂 네임스페이스 및 레이블 셋업..."
    oc apply -f "$USER_RENDER_DIR/namespace-istio-system.yaml"
    oc apply -f "$USER_RENDER_DIR/namespace-istio-ingress.yaml"
    oc label namespace "${USER_NAME}-istio-system" istio-discovery="${USER_NAME}" istio.io/rev="${USER_NAME}" --overwrite 2>/dev/null || true
    
    # Istio 및 OTel Collector, Telemetry CR 배포
    echo "      🏗️  Istio, OpenTelemetry, Telemetry 인스턴스 전개..."
    oc apply -f "$USER_RENDER_DIR/istio-cr.yaml"
    oc apply -f "$USER_RENDER_DIR/otel-collector-cr.yaml"
    oc apply -f "$USER_RENDER_DIR/telemetry-cr.yaml" -n "${USER_NAME}-istio-system"
    
    # OTel Collector가 Tempo Stack에 Traces를 정상 업로드(Ingest)할 수 있도록 전역 Writer 권한 허용 (401 PermissionDenied 완파 솔루션)
    echo "      🔑 OTel Collector Tempo Ingestion 권한 부여..."
    oc adm policy add-cluster-role-to-user tempostack-traces-writer "system:serviceaccount:${USER_NAME}-istio-system:otel-collector" 2>/dev/null || true
    
    # 메트릭 수집을 위한 ServiceMonitor 및 PodMonitor 전개 (cannot load the graph 완파 솔루션)
    echo "      📊 메트릭 수집용 ServiceMonitor 및 PodMonitor 배포..."
    oc apply -f "$USER_RENDER_DIR/istiod-servicemonitor.yaml" -n "${USER_NAME}-istio-system"
    oc apply -f "$USER_RENDER_DIR/istio-proxies-podmonitor.yaml" -n "${USER_NAME}-istio-system"
    oc apply -f "$USER_RENDER_DIR/istio-proxies-podmonitor.yaml" -n "${USER_NAME}-istio-ingress"
    
    # Ingress Gateway 배포
    echo "      🌐 Ingress Gateway, Service, Route 전개..."
    oc apply -f "$USER_RENDER_DIR/ingress-gateway-deployment.yaml"
    oc apply -f "$USER_RENDER_DIR/ingress-gateway-service-route.yaml"

    # 사용자 서비스 계정에 격리된 네임스페이스별 권한 주입 (Cluster 1 developer 수준 + 격리 보장)
    echo "      🔑 네임스페이스 권한 주입 (ServiceAccount)..."
    oc adm policy add-role-to-user admin "system:serviceaccount:homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-system" 2>/dev/null || true
    oc adm policy add-role-to-user admin "system:serviceaccount:homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-ingress" 2>/dev/null || true

    # 사용자 계정(User) 자체에도 네임스페이스별 권한 주입 (웹 콘솔 로그인 세션용!)
    echo "      🔑 네임스페이스 권한 주입 (User)..."
    oc adm policy add-role-to-user admin "${USER_NAME}" -n "${USER_NAME}-istio-system" 2>/dev/null || true
    oc adm policy add-role-to-user admin "${USER_NAME}" -n "${USER_NAME}-istio-ingress" 2>/dev/null || true

    # Istio Extended Permissions ClusterRole을 각 네임스페이스의 RoleBinding으로 연계 바인딩
    oc create rolebinding "workshop-${USER_NAME}-istio-extended-sa" --clusterrole=kiali-istio-extended-permissions --serviceaccount="homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-system" 2>/dev/null || true
    oc create rolebinding "workshop-${USER_NAME}-istio-extended-sa" --clusterrole=kiali-istio-extended-permissions --serviceaccount="homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-ingress" 2>/dev/null || true

    oc create rolebinding "workshop-${USER_NAME}-istio-extended-user" --clusterrole=kiali-istio-extended-permissions --user="${USER_NAME}" -n "${USER_NAME}-istio-system" 2>/dev/null || true
    oc create rolebinding "workshop-${USER_NAME}-istio-extended-user" --clusterrole=kiali-istio-extended-permissions --user="${USER_NAME}" -n "${USER_NAME}-istio-ingress" 2>/dev/null || true
    
    i=$((i + 1))
done

# 6. OpenShift Web Console 'Service Mesh' 통합 플러그인 연동 및 기동 (전역 공유 Kiali 기준 단 1회 등록)
echo "🔌 5. OpenShift Web Console 'Service Mesh' 메뉴 활성화 및 플러그인 등록..."
if oc get project istio-system &>/dev/null; then
    echo "   ➡️  istio-system 기준 OSSMConsole 생성..."
    cat <<EOF | oc apply -f -
apiVersion: kiali.io/v1alpha1
kind: OSSMConsole
metadata:
  name: ossmconsole
  namespace: istio-system
EOF

    echo "   ➡️  OpenShift Console 클러스터 명세에 ossmconsole 플러그인 활성화..."
    oc patch console.operator.openshift.io cluster --type=merge -p '{"spec":{"plugins":["networking-console-plugin","monitoring-plugin","ossmconsole"]}}' || true
fi

echo "=========================================================="
echo "🎉 서비스 메시 3.0 다중 유저 격리 인프라 구성이 성료되었습니다!"
echo "   (글로벌 공유 Kiali 및 사용자별 격리 메시 가동 중)"
echo "=========================================================="
