#!/bin/bash
# ==============================================================================
# OpenShift Service Mesh 3.0 Workshop - Homeroom 일괄 제거 스크립트
# ==============================================================================
set -eo pipefail

echo "=========================================================="
echo "📂 homeroom 프로젝트(네임스페이스) 및 OAuthClient 자원 일괄 삭제 시작"
echo "=========================================================="

# 1. OAuthClient 자원 삭제
echo "🔑 1. OAuthClient(workshop-console) 제거 중..."
oc delete oauthclient workshop-console 2>/dev/null || true

# 2. homeroom 프로젝트 삭제
echo "📂 2. homeroom 프로젝트(네임스페이스) 삭제 중..."
if oc get project homeroom &>/dev/null; then
    oc delete project homeroom
    
    # 완전히 삭제될 때까지 주기적으로 검사하며 대기 (Block)
    while oc get project homeroom &>/dev/null; do
        echo "⏱️  homeroom 프로젝트가 삭제 완료되기를 대기 중입니다 (몇 초 소요)..."
        sleep 3
    done
else
    echo "   ℹ️ homeroom 프로젝트가 존재하지 않아 삭제를 건너뜁니다."
fi

echo "=========================================================="
echo "✅ homeroom 가이드북 대시보드 인프라가 정상적으로 일괄 제거되었습니다."
echo "=========================================================="
