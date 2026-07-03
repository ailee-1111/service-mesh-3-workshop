<style>
  h1 { font-size: 24px !important; }
  h2 { font-size: 20px !important; }
  h3 { font-size: 16px !important; }
</style>

# Red Hat OpenShift Service Mesh 3.0 Workshop (한국어)

본 실습 교육 과정은 **Red Hat OpenShift Service Mesh 3.0 (OSSM v3)** 환경 상에서 마이크로서비스 간의 트래픽 라우팅, 복원력 제어, 옵저버빌리티 관찰 및 강력한 mTLS 보안 제어 등을 자율적으로 학습할 수 있도록 설계된 차세대 실습 교육 가이드라인입니다.

---

## 서비스 메시 3 (OSSM v3) 아키텍처 개요
오픈시프트 서비스 메시 3.0은 독자 엔진 기반에서 탈피하여, 글로벌 업스트림 표준인 **Istio(이스트오) 및 Sail Operator** 아키텍처로 완전히 통합 및 전환되었습니다. 

본 교육 과정에서는 다음과 같은 최신의 서비스 메시 표준 실습을 다룹니다:
1. **표준 컨트롤 플레인 구성:** Sail Operator를 이용한 `Istio` 제어부 배포 및 가동
2. **Kubernetes Gateway API 기반 라우팅:** 가상 게이트웨이 및 HTTPRoute 자원을 통한 차세대 트래픽 흐름 제어
3. **옵저버빌리티의 현대화:** Kiali 시각화 대시보드 연동과 Tempo / OpenTelemetry를 활용한 세련된 분산 추적 수집
4. **표준 이스티오 보안 통신:** PeerAuthentication 및 AuthorizationPolicy를 이용한 무점검 mTLS 인가 정책 제어

---

##  앞으로 함께 작성해 나갈 실습 모듈
본 대시보드는 뼈대 구성이 정상 가동 중이며, 아래 모듈들에 따른 세부 실습 가이드는 새로운 교육 시나리오 구성에 맞춰 이 디렉토리 하위에 순차적으로 채워 나갈 예정입니다.

* **Module 1:** OSSM v3 Architecture 확인 및 애플리케이션 배포
* **Module 2:** Kiali 기반 트래픽 시각화 및 관리, 장애관리, 복원력 
* **Module 3:** mTLS 보안 설정
* **Module 4:** OpenTelemetry 및 Tempo 분산 트래픽 추적 수집
