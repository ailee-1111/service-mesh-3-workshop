# 가이드 실습: 서비스 메시 쇼룸 애플리케이션 (Guided Exercise: Service Mesh Showroom Application)

Bookinfo 애플리케이션이 트래픽 라우팅, 관찰 가능성, 보안을 포함하여 OpenShift Service Mesh 기능을 실증하기 위한 현실적인 시나리오를 어떻게 제공하는지 설명합니다.

## 실습 결과 (Outcomes)
* Bookinfo 애플리케이션을 사용하여 OpenShift Service Mesh(OSSM) 기능을 탐색합니다.
* OSSM 인그레스 게이트웨이를 통해 Bookinfo 애플리케이션에 접속합니다.
* OpenShift 웹 콘솔을 탐색하여 서비스 메시 토폴로지를 조회합니다.
* 서비스 버전 간의 로드 밸런싱을 관찰하기 위한 트래픽을 생성합니다.
* 서비스 메시 트래픽 그래프를 사용하여 마이크로서비스 간의 통신을 시각화합니다.
* 특정 서비스 버전으로 트래픽을 100% 라우팅하도록 트래픽 시프팅을 구성합니다.
* 애플리케이션 인터페이스에서 트래픽 라우팅 변경 사항을 검증합니다.

---

워크스테이션 머신에서 student 사용자로 로그인하여, lab 명령어를 사용하여 이 실습을 위한 환경을 준비하고 필요한 모든 리소스가 사용 가능한지 확인합니다.

```execute
lab start meshintro-bookinfo
```

또한, 다음 명령어를 실행하여 $PATH 변수를 업데이트하고 `traffic_gen.py` 명령어를 즉시 사용할 수 있도록 설정합니다. 새 환경을 생성한 후 한 번만 실행합니다.

```execute
source ~/.bashrc
```

`lab start` 명령어는 실습 환경의 OpenShift 클러스터에 OpenShift Service Mesh가 배포 및 구성되었는지 보장하며, Bookinfo 애플리케이션의 모든 구성 요소를 배포합니다.

---

## 지침 (Instructions)

### 1. 서비스 메시의 초기 상태를 검증합니다.

1.1. 워크스테이션 머신의 브라우저에서 OpenShift 웹 콘솔을 엽니다.
Go to `https://console-openshift-console.%cluster_subdomain%`, click `htpasswd_provider` and use `%username%` as the user and `openshift` as the password. 가이드 투어(guided tour)가 표시되면 Skip tour를 클릭합니다.

1.2. 측면 메뉴에서 **Developer** 메뉴 항목을 클릭하여 개발자 관점(Developer perspective)을 사용 중인지 확인합니다.

<img src="images/fig-002.svg" width="100%" alt="Figure 1.10: OpenShift Developer perspective navigation menu" />

1.3. **Topology** 메뉴 항목을 클릭하여 토폴로지 뷰를 열고 배포를 검사합니다. 프로젝트 목록 드롭다운에서 `%username%-meshintro-bookinfo` 프로젝트가 선택되어 있는지 확인합니다.

<img src="images/fig-003.svg" width="100%" alt="Figure 1.11: Bookinfo application topology view" />

프로젝트에 7개의 배포가 있지만 오른쪽 상단 모서리에 라우트(Route) 아이콘이 있는 것은 하나도 없음을 확인하십시오. 이는 모든 애플리케이션이 외부에서 오직 OSSM 인그레스 게이트웨이를 통해서만 접속 가능하기 때문입니다.

---

### 2. Bookinfo 애플리케이션을 탐색합니다.

2.1. 브라우저의 새 탭에서 Bookinfo productpage 페이지를 엽니다.
Go to `http://istio-ingressgateway-istio-ingress.%cluster_subdomain%/productpage`.

<img src="images/fig-004.svg" width="100%" alt="Figure 1.12: Bookinfo application homepage" />

Book Reviews 섹션 아래의 별표 평점을 관찰하십시오. 페이지를 여러 번 새로고침하면서 별표 평점이 대략 균등한 비율로 빨간색 별, 검은색 별, 별표 없음 사이에서 변경되는 것을 관찰하십시오. 이러한 변화는 reviews 서비스가 세 가지 버전으로 구성되어 있기 때문입니다:
* reviews v1: 별표 없음 (no stars)
* reviews v2: 검은색 별 (black stars)
* reviews v3: 빨간색 별 (red stars)

2.2. 새 터미널 창에서 %username% 사용자명과 openshift 비밀번호로 로그인하고, `%username%-meshintro-bookinfo` 프로젝트로 전환합니다:

```execute
oc login -u %username% -p openshift https://api.%cluster_subdomain%:6443
```
* **실행 결과 로그:**
```bash
The server uses a certificate signed by an unknown authority.
Use insecure connections? (y/n): y

WARNING: Using insecure TLS client config. Setting this option is not supported!

Logged into "https://api.%cluster_subdomain%:6443" as "%username%" using the password provided.

You have access to 78 projects.
Using project "default".
```

```execute
oc project %username%-meshintro-bookinfo
```
* **실행 결과 로그:**
```bash
Now using project "%username%-meshintro-bookinfo" on server "https://api.%cluster_subdomain%:6443".
```

2.3. 실습 디렉토리로 이동하여 `traffic_gen.py` 스크립트를 실행해 reviews Bookinfo 서비스에 대한 트래픽을 생성합니다. 일부 요청이 처리된 후 스크립트를 중단하려면 **Ctrl+C**를 누릅니다.

```execute
cd ~/course/labs/meshintro-bookinfo
```
```execute
traffic_gen.py continuous.yaml
```

<img src="images/fig-005.svg" width="100%" alt="Traffic Output and Statistics" />

세 가지 버전의 reviews 서비스 모두가 균형 있게 응답하는지 관찰하십시오. 본인의 실제 값은 다를 수 있습니다.

```bash
# 참고 구문 (실행 환경에 맞게 path 변수 갱신 유지)
source ~/.bashrc
```

2.4. `traffic_gen.py` 스크립트를 재실행하여 reviews Bookinfo 서비스에 대한 트래픽을 생성합니다. 스크립트가 계속 실행되도록 놔둡니다.

```execute
traffic_gen.py continuous.yaml
```

---

### 3. 마이크로서비스 간의 트래픽 흐름을 탐색합니다.

3.1. 브라우저의 OpenShift 웹 콘솔로 이동하여 관리자(Administrator) 관점으로 전환합니다. 왼쪽 상단 모서리에서 Developer를 클릭하고 Administrator를 선택합니다.

3.2. **Service Mesh > Overview** 메뉴 항목을 클릭하여 OSSM 개요 섹션으로 이동합니다.

<img src="images/fig-005.svg" width="100%" alt="Figure 1.13: Service Mesh overview perspective" />

`%username%-meshintro-bookinfo` 프로젝트의 분당 평균 요청 수가 약 200건인 것을 확인하십시오. 본인의 값은 다르게 나타날 수 있습니다.

3.3. **Traffic Graph** 메뉴 항목을 클릭하고 상단의 **Select Namespaces** 콤보박스에서 `%username%-meshintro-bookinfo` 프로젝트만 선택합니다.
필터가 적용되려면 선택 메뉴 외부의 다른 곳을 한 번 클릭해 주어야 함을 잊지 마십시오.

<img src="images/fig-006.svg" width="100%" alt="Figure 1.14: Service Mesh traffic graph perspective" />

프로젝트의 트래픽 흐름 그래프를 관찰하십시오. 본인의 그래프는 확대/축소 레벨, 실시간 트래픽 밀도 등에 따라 약간 다르게 나타날 수 있습니다.

3.4. 마우스 포인터를 그래프 안의 삼각형들 위로 가져가 Bookinfo 서비스들을 확인합니다. 예를 들어, 왼쪽에서 첫 번째 삼각형 위로 마우스를 가져가면 `productpage` 서비스 정보가 표시됩니다.

<img src="images/fig-007.svg" width="100%" alt="Figure 1.15: productpage service details in traffic graph" />

3.5. 출력되는 외부 경로 화살표를 따라 마우스 포인터를 가장 위의 삼각형 위로 가져갑니다. 이는 도서 정보를 제공하는 `details` 서비스입니다.

<img src="images/fig-007.svg" width="100%" alt="Figure 1.16: details service information in traffic graph" />

3.6. 그 아래에서 `reviews` 서비스를 확인할 수 있습니다. `reviews` 삼각형에서 3개의 외부로 향하는 화살표가 나가는 것을 주목하십시오. 이것이 `reviews` 애플리케이션의 3가지 서로 다른 버전들입니다.

<img src="images/fig-007.svg" width="100%" alt="Figure 1.17: reviews service with three version variants in traffic graph" />

3.7. 둥근 사각형들 위로 마우스 포인터를 올려놓으면, `reviews` 서비스의 `v1`, `v2`, `v3` 버전을 볼 수 있습니다. `v1`은 오른쪽에 위치한 `ratings` 서비스를 전혀 호출하지 않는 반면, `v2`와 `v3`만 `ratings` 서비스를 호출하고 있음을 확인해 보십시오.

---

### 4. 트래픽 흐름을 reviews 마이크로서비스의 특정 고정 버전으로 변경합니다.

4.1. 그래프에서 `reviews` 서비스를 클릭하여 선택합니다. 오른쪽에 열리는 패널에서 삼점(⋮) 메뉴를 펼치고 **Traffic Shifting** 메뉴 항목을 클릭합니다.

<img src="images/fig-007.svg" width="100%" alt="Figure 1.18: Add traffic shifting configurations to the reviews service" />

<img src="images/fig-008.svg" width="100%" alt="Figure 1.19: reviews service traffic weight configuration form" />

4.2. Create Traffic Shifting 폼에서, `reviews-v3` Traffic Weight 값을 **100%**로 정의하고, `reviews-v1` 및 `reviews-v2` 값을 **0%**로 정의합니다. 그런 다음 Preview를 클릭하여 생성될 OSSM 리소스 명세를 시각적으로 검증합니다.

4.3. **VirtualService** 탭을 선택하고 화면을 아래로 스크롤하여, 트래픽의 100%가 서비스 서브셋 `v3`으로 이동하고 `v1` 및 `v2`로는 0% 이동하는 설정이 맞게 잡혔는지 최종 검사합니다. 확인이 완료되면 **Create** 버튼을 클릭합니다.

<img src="images/fig-008.svg" width="100%" alt="Figure 1.20: reviews VirtualService traffic routing configuration" />
