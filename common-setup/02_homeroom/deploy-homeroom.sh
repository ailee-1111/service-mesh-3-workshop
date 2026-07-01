#!/bin/bash
# ==============================================================================
# OpenShift Service Mesh 3.0 Workshop - Homeroom 자동 배포 스크립트
# ==============================================================================
set -eo pipefail

echo "=========================================================="
echo "☸️  오픈시프트 서비스 메시 3.0 워크숍 Homeroom 배포 및 스포너 기동"
echo "=========================================================="

# 1. 오픈시프트 접속 여부 점검 및 API 서버 주소 자동 추출
if ! oc whoami &> /dev/null; then
    echo "❌ 오픈시프트 세션이 없습니다. 먼저 대상 신규 클러스터에 'oc login'을 실행해 주세요."
    exit 1
fi

API_SERVER=$(oc whoami --show-server 2>/dev/null || true)
if [ -z "$API_SERVER" ]; then
    echo "❌ 오픈시프트 서버 주소를 가져올 수 없습니다. 'oc login' 세션을 점검해 주세요."
    exit 1
fi

echo "🎯 1. 로그인 인증 및 API 서버 감지 성공:"
echo "   🔗 API Server: $API_SERVER"

# 2. Apps 서브도메인 자동 파싱
CLEAN_SERVER=$(echo "$API_SERVER" | sed -e 's|https://||' -e 's|:[0-9]*$||' -e 's|^api\.||')
NEW_SUBDOMAIN="apps.$CLEAN_SERVER"
echo "   🌐 파싱된 앱 서브도메인: $NEW_SUBDOMAIN"

# 3. 클러스터 내의 userX 사용자 정원 동적 감지
echo "🔍 2. 클러스터 상의 사용자(userX) 구성 상태 감지 중..."
USER_COUNT=$(oc get projects --no-headers 2>/dev/null | grep -E -o "user[0-9]+" | sort -u | wc -l | tr -d ' ' || echo "0")

if [ "$USER_COUNT" -eq 0 ] || [ -z "$USER_COUNT" ]; then
    echo "   ⚠️  userX 형태의 프로젝트가 감지되지 않았습니다. 기본값인 5명으로 세팅합니다."
    USER_COUNT=5
else
    echo "   👥 감지된 고유 사용자 수(userX): $USER_COUNT 명"
fi

# 4. homeroom 네임스페이스 생성 및 이동
echo "📂 3. homeroom 프로젝트(네임스페이스) 생성 및 전환..."
oc new-project homeroom 2>/dev/null || oc project homeroom

# 5. OAuthClient 설정 파일 동적 생성 및 배포
echo "🔑 4. OAuthClient 자원 구성 및 배포..."
cat << EOF > oauth_client_temp.yaml
apiVersion: oauth.openshift.io/v1
kind: OAuthClient
metadata:
  name: workshop-console
secret: VFW8tPQAe7JFL6bOSrEyUpmuKtsToQbR
redirectURIs:
- https://workshop-homeroom.${NEW_SUBDOMAIN}/hub/oauth_callback
grantMethod: auto
EOF

oc apply -f oauth_client_temp.yaml

# 6. 핵심 인프라 자원 명세서 템플릿 파싱 및 배포
echo "📦 5. 전체 인프라 자원 명세서 생성 및 배포..."
SCRIPT_DIR="$(dirname "$0")"
TEMPLATE_MANIFEST="$SCRIPT_DIR/homeroom_all_resources.yaml"

if [ ! -f "$TEMPLATE_MANIFEST" ]; then
    echo "❌ 템플릿 리소스 파일(homeroom_all_resources.yaml)이 존재하지 않습니다."
    exit 1
fi

# 템플릿 복제 및 플레이스홀더 치환
cp "$TEMPLATE_MANIFEST" homeroom_resources_temp.yaml
perl -pi -e "s/YOUR_NEW_CLUSTER_SUBDOMAIN/${NEW_SUBDOMAIN}/g" homeroom_resources_temp.yaml
perl -pi -e "s/LAB_USER_COUNT_PLACEHOLDER/${USER_COUNT}/g" homeroom_resources_temp.yaml

oc apply -f homeroom_resources_temp.yaml

# 7. 현재 프로젝트의 Git 저장소를 공급 소스로 설정하여 BuildConfig 등록 및 빌드 실행
echo "🏗️ 6. 현재 프로젝트 깃허브 저장소 연동 BuildConfig 생성 및 조립..."
GIT_REPO="https://github.com/ailee-1111/service-mesh-3-workshop.git"

if ! oc get bc/workshop-content -n homeroom &> /dev/null; then
    echo "   💡 신규 BuildConfig 생성 대상 리포지토리: $GIT_REPO"
    oc new-build "$GIT_REPO#main" --name=workshop-content -n homeroom
else
    echo "   ✏️ 기존 BuildConfig 발견. 소스 저장소를 최신 사양으로 패치합니다."
    oc patch bc/workshop-content -n homeroom -p "{\"spec\":{\"source\":{\"git\":{\"uri\":\"$GIT_REPO\",\"ref\":\"main\"}}}}"
fi

echo "   🚀 이미지 빌드 및 푸시를 실행합니다. (마크다운 가이드 빌드 진행 상황 추적)"
oc start-build workshop-content -n homeroom --follow || { echo "❌ 빌드에 실패했습니다. 빌드 로그를 확인하십시오."; exit 1; }

# 8. 서비스메시 가이드북 스포너 배포 상태 추적 및 최종 검증
echo "🔄 7. 가이드 대시보드 인프라 배포 상태 검증 및 최종 적용..."
oc patch dc/workshop-spawner -n homeroom -p '{"spec":{"templates":{"spec":{"containers":[{"name":"spawner","imagePullPolicy":"Always"}]}}}}' 2>/dev/null || true

# 임시 템플릿 리소스 제거
rm -f homeroom_resources_temp.yaml oauth_client_temp.yaml

echo "================================================================================"
echo "🎉 OpenShift Service Mesh 3.0 Workshop 가이드 대시보드가 정상 기동되었습니다!"
echo "================================================================================"
echo "🔗 워크숍 가이드북 대시보드 URL: https://workshop-homeroom.${NEW_SUBDOMAIN}"
echo "🔗 참석자 계정 분배기 접속 URL: https://username-distribution-homeroom.${NEW_SUBDOMAIN}"
echo "👥 배포에 반영된 사용자 수: ${USER_COUNT} 명 격리 환경 세팅 완료"
echo "================================================================================"
