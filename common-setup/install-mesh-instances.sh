#!/bin/bash
# ==============================================================================
# OpenShift Service Mesh 3.0 Workshop - 다중 유저별 격리 인스턴스 자동화 배포 스크립트
# ==============================================================================
set -eo pipefail

echo "=========================================================="
echo "☸️  오픈시프트 서비스 메시 3.0 다중 사용자 격리 인프라 구성 시작"
echo "=========================================================="

# 1. 오픈시프트 접속 여부 점검 및 API 서버 주소 자동 추출
if ! oc whoami &> /dev/null; then
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

# Global CNI 인스턴스 적용
echo "   ➡️ [CNI] 글로벌 IstioCNI 인스턴스 기동..."
oc apply -f "$SCRIPT_DIR/01_operators/istio-cni-instance.yaml"

# Global Tracing-System 적용
echo "   ➡️ [Tracing] MinIO 및 TempoStack 백엔드 기동..."
oc apply -f "$SCRIPT_DIR/03_tracing/minio-and-tempo.yaml"

# 5. 다중 사용자별 개별 격리 인스턴스 생성 루프
echo "📦 4. 사용자별($USER_COUNT명) 격리 서비스 메시 및 인그레스 게이트웨이 전개..."
TEMPLATE_DIR="$SCRIPT_DIR/03_instances/user-template"
RENDER_DIR="/tmp/rendered-mesh-instances"
rm -rf "$RENDER_DIR" && mkdir -p "$RENDER_DIR"

for ((i=1; i<=USER_COUNT; i++)); do
    USER_NAME="user$i"
    echo "   👉 [사용자 $USER_NAME] 전용 격리 환경 조립 중..."
    
    USER_RENDER_DIR="$RENDER_DIR/$USER_NAME"
    mkdir -p "$USER_RENDER_DIR"
    
    # 템플릿 파일을 읽어 플레이스홀더를 사용자에 맞게 치환
    for f in "$TEMPLATE_DIR"/*.yaml; do
        filename=$(basename "$f")
        cp "$f" "$USER_RENDER_DIR/$filename"
        
        # 플레이스홀더 변경
        perl -pi -e "s/USER_NAME_PLACEHOLDER/${USER_NAME}/g" "$USER_RENDER_DIR/$filename"
        perl -pi -e "s/YOUR_NEW_CLUSTER_SUBDOMAIN/${NEW_SUBDOMAIN}/g" "$USER_RENDER_DIR/$filename"
    done
    
    # 해당 사용자의 네임스페이스 기동 및 레이블 설정
    echo "      📂 네임스페이스 및 레이블 셋업..."
    oc apply -f "$USER_RENDER_DIR/namespace-istio-system.yaml"
    oc apply -f "$USER_RENDER_DIR/namespace-istio-ingress.yaml"
    
    # Istio 및 Kiali, OTel Collector CR 배포
    echo "      🏗️  Istio, Kiali, OpenTelemetry 인스턴스 전개..."
    oc apply -f "$USER_RENDER_DIR/istio-cr.yaml"
    oc apply -f "$USER_RENDER_DIR/otel-collector-cr.yaml"
    oc apply -f "$USER_RENDER_DIR/kiali-cr.yaml"
    oc apply -f "$USER_RENDER_DIR/kiali-viewer-crb.yaml"
    
    # Ingress Gateway 배포
    echo "      🌐 Ingress Gateway, Service, Route 전개..."
    oc apply -f "$USER_RENDER_DIR/ingress-gateway-deployment.yaml"
    oc apply -f "$USER_RENDER_DIR/ingress-gateway-service-route.yaml"

    # 사용자 서비스 계정에 격리된 네임스페이스별 권한 주입 (Cluster 1 developer 수준 + 격리 보장)
    echo "      🔑 네임스페이스 권한 주입..."
    oc adm policy add-role-to-user admin "system:serviceaccount:homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-system" 2>/dev/null || true
    oc adm policy add-role-to-user admin "system:serviceaccount:homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-ingress" 2>/dev/null || true
    oc adm policy add-role-to-user admin "system:serviceaccount:homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-meshintro-bookinfo" 2>/dev/null || true

    oc create rolebinding "workshop-${USER_NAME}-istio-extended" --clusterrole=kiali-istio-extended-permissions --serviceaccount="homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-system" 2>/dev/null || true
    oc create rolebinding "workshop-${USER_NAME}-istio-extended" --clusterrole=kiali-istio-extended-permissions --serviceaccount="homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-istio-ingress" 2>/dev/null || true
    oc create rolebinding "workshop-${USER_NAME}-istio-extended" --clusterrole=kiali-istio-extended-permissions --serviceaccount="homeroom:workshop-${USER_NAME}" -n "${USER_NAME}-meshintro-bookinfo" 2>/dev/null || true
done

# 6. OpenShift Web Console 'Service Mesh' 통합 플러그인 연동 및 기동
echo "🔌 5. OpenShift Web Console 'Service Mesh' 메뉴 활성화 및 플러그인 등록..."
if oc get project user1-istio-system &>/dev/null; then
    echo "   ➡️  user1-istio-system 기준 OSSMConsole 생성..."
    cat <<EOF | oc apply -f -
apiVersion: kiali.io/v1alpha1
kind: OSSMConsole
metadata:
  name: ossmconsole
  namespace: user1-istio-system
EOF

    echo "   ➡️  OpenShift Console 클러스터 명세에 ossmconsole 플러그인 활성화..."
    oc patch console.operator.openshift.io cluster --type=merge -p '{"spec":{"plugins":["networking-console-plugin","monitoring-plugin","ossmconsole"]}}' || true
fi

echo "=========================================================="
echo "🎉 서비스 메시 3.0 다중 유저 격리 인스턴스 구성이 성료되었습니다!"
echo "   (사용자 $USER_COUNT명 격리 제어평면 및 게이트웨이 기동 중)"
echo "=========================================================="
