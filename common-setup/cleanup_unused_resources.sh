#!/bin/bash
# ==============================================================================
# OpenShift Service Mesh 3.0 Workshop - 불필요한 ArgoCD 실습 자원 및 연계 네임스페이스 제거 스크립트
# ==============================================================================
set -eo pipefail

echo "=========================================================="
echo "🧹 불필요한 ArgoCD 실습 관련 자원 및 네임스페이스 정리 시작"
echo "=========================================================="

# 1. 오픈시프트 접속 여부 점검
if ! oc whoami &> /dev/null; then
    echo "❌ 오픈시프트 세션이 없습니다. 먼저 'oc login'을 수행해 주세요."
    exit 1
fi

echo "🎯 로그인 확인 완료. 불필요한 네임스페이스 및 오퍼레이터 정리를 개시합니다..."
echo "----------------------------------------------------------"

# 2. 불필요한 사용자별 ArgoCD 실습 네임스페이스 삭제
# 대상: showroom-userX, userX-argocd, userX-bgd, userX-bgdh, userX-bgdk, userX-todo (X: 1~5)
NAMESPACES=()
for i in {1..5}; do
    NAMESPACES+=("showroom-user$i")
    NAMESPACES+=("user$i-argocd")
    NAMESPACES+=("user$i-bgd")
    NAMESPACES+=("user$i-bgdh")
    NAMESPACES+=("user$i-bgdk")
    NAMESPACES+=("user$i-todo")
done

echo "📂 1. 불필요한 실습 네임스페이스 일괄 삭제 대상 식별 중..."
ACTIVE_NAMESPACES=()
for ns in "${NAMESPACES[@]}"; do
    if oc get project "$ns" &>/dev/null; then
        echo "   - $ns"
        ACTIVE_NAMESPACES+=("$ns")
    fi
done

if [ ${#ACTIVE_NAMESPACES[@]} -eq 0 ]; then
    echo "   ℹ️ 삭제할 대상 네임스페이스가 이미 존재하지 않습니다."
else
    for ns in "${ACTIVE_NAMESPACES[@]}"; do
        echo "🗑️  네임스페이스 '$ns' 삭제 중..."
        oc delete project "$ns" --wait=false || true
    done
fi

# 3. 불필요한 OpenShift GitOps (ArgoCD) Operator 제거 (openshift-operators 네임스페이스)
echo "----------------------------------------------------------"
echo "🧩 2. 불필요한 OpenShift GitOps Operator 제거 중..."

# Subscription 삭제
if oc get subscription openshift-gitops-operator -n openshift-operators &>/dev/null; then
    echo "🗑️  openshift-gitops-operator Subscription 제거 중..."
    oc delete subscription openshift-gitops-operator -n openshift-operators
else
    echo "   ℹ️ openshift-gitops-operator Subscription이 존재하지 않습니다."
fi

# ClusterServiceVersion (CSV) 동적 검색 및 삭제
GITOPS_CSV=$(oc get csv -n openshift-operators -o custom-columns=NAME:.metadata.name --no-headers | grep "openshift-gitops-operator" || true)
if [ -n "$GITOPS_CSV" ]; then
    for csv in $GITOPS_CSV; do
        echo "🗑️  GitOps CSV '$csv' 제거 중..."
        oc delete csv "$csv" -n openshift-operators || true
    done
else
    echo "   ℹ️ 관련 GitOps CSV가 존재하지 않습니다."
fi

# 4. 삭제 완료 대기 (비동기로 백그라운드 삭제 시작되었으므로 주기적 확인)
if [ ${#ACTIVE_NAMESPACES[@]} -gt 0 ]; then
    echo "----------------------------------------------------------"
    echo "⏱️  네임스페이스들이 클러스터에서 완전히 청소될 때까지 대기합니다..."
    for ns in "${ACTIVE_NAMESPACES[@]}"; do
        while oc get project "$ns" &>/dev/null; do
            echo "   ⏳ 네임스페이스 '$ns'가 여전히 삭제(Terminating) 중입니다. 5초 후 재검사..."
            sleep 5
        done
        echo "   ✅ 네임스페이스 '$ns' 제거 완료!"
    done
fi

echo "=========================================================="
echo "🎉 불필요한 자원 및 오퍼레이터 일괄 청소가 완료되었습니다!"
echo "   이제 서비스 메시 3.0 실습 환경을 깨끗하게 적용할 수 있습니다."
echo "=========================================================="
