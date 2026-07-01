#!/bin/bash
# ==============================================================================
# 🎯 OpenShift Service Mesh 3.0 (OSSM v3) 공통 오퍼레이터 배포 자동화 스크립트
# ==============================================================================
set -eo pipefail

echo "======================================================================"
echo "☸️  OpenShift Service Mesh 3.0 공통 오퍼레이터 설치 자동화 시작"
echo "======================================================================"

# 1. oc CLI 및 세션 로그인 확인
if ! oc whoami &> /dev/null; then
    echo "❌ [Error] OpenShift 세션이 만료되었거나 로그인되어 있지 않습니다."
    echo "   먼저 'oc login' 명령어로 클러스터에 정상적으로 로그인해 주세요."
    exit 1
fi

echo "✅ [OCP Session] 연결 성공: $(oc whoami) (API: $(oc whoami --show-server))"

# 2. 오퍼레이터 서브스크립션 선언 파일 일괄 적용
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATORS_DIR="$SCRIPT_DIR/01_operators"

echo ""
echo "🚀 [Step 1/2] 서비스 메시 3.0 핵심 오퍼레이터 4종 배포를 시작합니다..."
if [ -d "$OPERATORS_DIR" ]; then
    oc apply -f "$OPERATORS_DIR/"
else
    echo "❌ [Error] 오퍼레이터 선언 폴더를 찾을 수 없습니다: $OPERATORS_DIR"
    exit 1
fi

# 3. 설치 완료 대기 및 검증 루프
echo ""
echo "⏱️  [Step 2/2] 오퍼레이터 기동 및 설치 완료(Succeeded) 상태를 대기합니다..."
echo "    (대기 대상: Service Mesh 3.0, Kiali, OpenTelemetry, Tempo)"
echo "----------------------------------------------------------------------"

MAX_RETRIES=30
SLEEP_INTERVAL=10
SUCCESS_TARGET=4

for ((i=1; i<=MAX_RETRIES; i++)); do
    # openshift-operators 네임스페이스에 있는 각 CSV의 Phase를 조회하여 Succeeded 상태 개수를 셉니다.
    CSV_STATUS=$(oc get csv -n openshift-operators -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' | grep -E "servicemeshoperator3|kiali-operator|opentelemetry-operator|tempo-operator" || true)
    
    SUCCEEDED_COUNT=$(echo "$CSV_STATUS" | grep -c "Succeeded" || true)
    TOTAL_COUNT=$(echo "$CSV_STATUS" | wc -l || true)
    
    echo "📊 설치 현황 (시도 $i/$MAX_RETRIES): $SUCCEEDED_COUNT/$SUCCESS_TARGET 완료"
    if [ -n "$CSV_STATUS" ]; then
        echo "$CSV_STATUS" | sed 's/^/   - /'
    fi
    echo "----------------------------------------------------------------------"
    
    if [ "$SUCCEEDED_COUNT" -eq "$SUCCESS_TARGET" ]; then
        echo "🎉 [Success] 서비스 메시 3.0 핵심 오퍼레이터 4종의 설치가 완벽하게 완료되었습니다!"
        echo "======================================================================"
        exit 0
    fi
    
    sleep $SLEEP_INTERVAL
done

echo "❌ [Timeout] $MAX_RETRIES 회 동안 오퍼레이터 설치가 완료되지 않았습니다."
echo "    'oc get csv -n openshift-operators' 명령을 통해 에러 원인을 추적해 주세요."
exit 1
