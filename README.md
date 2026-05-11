# Application Base Helm Chart PRD

## 1. Overview

이 프로젝트는 Kubernetes 환경에서 application을 배포하기 위한 범용 Helm chart를 제공한다.

이 chart는 여러 애플리케이션에서 공통으로 재사용할 수 있는 generic base chart를 목표로 하며, 대부분의 배포 설정은 `values.yaml`을 통해 제어한다. chart 사용자는 애플리케이션별로 필요한 workload, network, access control, config 설정만 선언하고, 공통 Kubernetes manifest 구조는 chart가 일관되게 생성하도록 한다.

## 2. Chart Name

chart 이름은 `application-base`로 확정한다.

선정 이유:

- 특정 프레임워크, 런타임, 애플리케이션 유형에 종속되지 않는다.
- Helm chart 이름으로 사용하기 좋은 소문자 kebab-case 형식이다.
- "application을 배포하기 위한 base chart"라는 의도를 직접적으로 드러낸다.
- 향후 필요하다면 `application-base-web`, `application-base-worker`처럼 파생 chart를 만들기 쉽다.

## 3. Problem Statement

애플리케이션별 Helm chart를 매번 개별 작성하면 다음 문제가 반복된다.

- Workload, Service, HPA, PDB, ServiceAccount, ConfigMap 등 공통 리소스 템플릿이 중복된다.
- CNI, service mesh, Gateway API, progressive delivery controller 같은 플랫폼 표준이 서비스마다 다르게 적용될 수 있다.
- 배포 전략, 보안 컨텍스트, external secret 참조 방식, resource 정책, probe 정책이 일관되지 않다.
- chart 유지보수 비용이 서비스 수에 비례해 증가한다.
- 플랫폼팀과 애플리케이션팀 사이에서 "무엇을 values로 열고, 무엇을 표준으로 고정할지"가 불명확해진다.

이 프로젝트는 공통 배포 패턴을 하나의 base chart로 표준화하여, 애플리케이션별 chart 작성 비용을 줄이고 배포 품질을 일관되게 유지하는 것을 목표로 한다.

## 4. Goals

- 여러 애플리케이션에서 재사용 가능한 generic Helm chart를 제공한다.
- `values.yaml` 중심으로 workload, network, access control, config 설정을 제어한다.
- CNI, service mesh, Gateway API 기반 트래픽 라우팅 환경을 전제로 설계한다.
- rolling update, canary, blue-green 배포 전략을 안정적으로 표현한다.
- values 구조는 특정 service mesh 또는 progressive delivery 구현체에 직접 종속되지 않도록 설계한다.
- chart 사용자에게는 단순한 설정 경험을 제공하고, chart 유지보수자에게는 확장 가능한 템플릿 구조를 제공한다.
- 보안, 운영 안정성, 네트워크 표준을 chart 레벨에서 반복 가능하게 만든다.

## 5. Non-Goals

- 데이터베이스, Kafka, Redis 등 stateful dependency 자체를 설치하지 않는다.
- CNI, service mesh, progressive delivery controller, External Secrets Operator, Gateway API CRD를 chart 내부에서 설치하지 않는다.
- AWS EKS, VPC CNI chaining, EKS Custom Networking, ENIConfig 같은 클러스터 네트워크 인프라를 chart에서 구성하지 않는다.
- 애플리케이션 빌드, 이미지 생성, CI/CD pipeline 자체를 책임지지 않는다.
- 모든 Kubernetes 리소스를 무제한 생성하는 범용 manifest generator가 되는 것을 목표로 하지 않는다.
- Secret 값을 chart values에 직접 넣는 방식을 지원하지 않는다. Secret은 external secret 참조를 기본 원칙으로 한다.
- Kubernetes Ingress 리소스는 지원하지 않는다. HTTP/gRPC 라우팅은 Gateway API를 사용한다.

## 6. Target Users

주요 사용자는 다음과 같다.

- 플랫폼 엔지니어: 공통 배포 표준을 chart로 관리하고 싶은 사용자
- 백엔드 엔지니어: 애플리케이션별 최소 values만 작성해 서비스를 배포하고 싶은 사용자
- SRE/운영자: autoscaling, PDB, probes, resources, rollout strategy 같은 운영 정책을 일관되게 관리하고 싶은 사용자

## 7. Target Environment

기본 대상은 Kubernetes 클러스터이다.

전제 조건:

- Kubernetes: 추후 확정
- Helm: 추후 확정
- CNI
- Service mesh
- Gateway API
- Progressive delivery controller
- External Secrets Operator

환경 설계 메모:

- Kubernetes 클러스터 공급자는 chart 설계의 핵심 전제가 아니다.
- EKS, VPC CNI chaining, EKS Custom Networking, ENIConfig, CGNAT 대역 사용 여부는 chart manifest 구조에 직접 영향을 주지 않는 클러스터 인프라 영역으로 본다.
- 현재 목표 인프라는 Cilium CNI와 Istio ambient mode를 사용하지만, `values.yaml`에는 이 구현체 이름이 드러나지 않아야 한다.
- chart 내부 템플릿 구현을 교체하면 Linkerd 등 다른 service mesh 기반 인프라에도 동일한 values 구조로 배포할 수 있어야 한다.
- Ingress는 사용하지 않는다.
- HTTP 트래픽은 Gateway API `HTTPRoute`를 사용한다.
- gRPC 트래픽은 Gateway API `GRPCRoute`를 사용한다.
- GatewayClass와 Gateway 자체는 chart 외부에서 관리한다고 가정한다.
- canary와 blue-green 배포 전략은 유지하되, 특정 구현체를 values contract에 고정하지 않는다.

## 8. Core Use Case

사용자는 application을 배포하기 위해 `application-base` chart를 사용한다.

chart는 다음을 지원해야 한다.

- workload 생성
- container image 설정
- replica 설정
- autoscaling 설정
- PDB 설정
- rolling update, canary, blue-green 배포 전략 선택
- Service 및 headless Service 생성
- HTTPRoute 및 GRPCRoute 생성
- readiness/liveness/startup probe 설정
- resource requests/limits 설정
- ConfigMap 및 external secret 참조
- service account 및 RBAC 설정
- security context 설정
- node scheduling 설정
- volume 및 volumeMount 설정
- pod/service label 및 annotation 확장

## 9. Values Sections

`values.yaml`은 크게 다음 네 개의 섹션으로 나눈다.

- `workload`
- `network`
- `accessControl`
- `config`

초기 설계에서는 섹션 수를 의도적으로 제한한다. 새로운 top-level 섹션은 해당 설정이 네 섹션 중 어느 곳에도 자연스럽게 속하지 않거나, 여러 섹션에 걸친 독립적인 lifecycle을 가질 때만 추가한다.

## 10. Workload

`workload`는 Pod를 생성하고 운영하는 데 필요한 설정을 담당한다.

포함 범위:

- workload type
- image
- replicas
- command/args
- container ports
- resources
- probes
- lifecycle
- autoscaling
- PDB
- deployment strategy
- node scheduling
- pod labels
- pod annotations
- pod security context
- container security context
- volumes
- volumeMounts
- stateless workload options
- stateful workload options

지원 workload:

- stateless application
- stateful application

참고:

- values에서는 Kubernetes `Deployment`, `ReplicaSet`, Argo Rollouts `Rollout` 같은 구현체 이름보다 `stateless`와 `stateful` 같은 application 실행 형태를 우선 표현한다.
- stateless application은 현재 chart 내부 구현에서 Argo Rollouts `Rollout` 리소스로 렌더링한다.
- stateful application은 내부 구현에서 Kubernetes `StatefulSet` 중심으로 렌더링된다.
- Kubernetes `Deployment`는 기본 구현 대상으로 보지 않는다.
- Kubernetes `ReplicaSet`은 보통 `Deployment` 또는 다른 controller가 관리하는 하위 리소스이므로, chart 사용자-facing workload type으로 직접 노출하지 않는다.
- rolling update, canary, blue-green은 `workload.stateless.strategy.type`으로 표현하고, 실제 구현체는 chart 내부 템플릿이 결정한다.

### 10.1 Autoscaling

`workload.autoscaling`은 HPA 생성을 담당한다.

지원 항목:

- enabled
- minReplicas
- maxReplicas
- targetCpuUtilization
- targetMemoryUtilization
- custom metrics 확장 가능 구조
- behavior scaleUp/scaleDown 정책

초기 기본 autoscaling metric은 CPU와 memory utilization을 values에서 입력받는 방식으로 제공한다. custom metric은 values 구조는 확장 가능하게 두되, 표준화 여부는 추후 결정한다.

### 10.2 Pod Disruption Budget

`workload.pdb`는 PDB 생성을 담당한다.

지원 항목:

- enabled
- minAvailable
- maxUnavailable

### 10.3 Stateless Deployment Strategy

`workload.stateless.strategy`는 stateless workload의 배포 전략을 담당한다.

지원 전략:

- rolling update
- canary
- blue-green

예상 설정:

- strategy type
- rollingUpdate 설정
- canary steps
- canary traffic routing 사용 여부
- analysis template 참조
- blue-green active service
- blue-green preview service
- auto promotion 여부
- scale down delay

### 10.4 Workload Type Naming

초기 values에서는 `Rollout`을 기본 workload type 이름으로 사용하지 않는다.

권장 구조:

```yaml
workload:
  type: stateless
  stateless:
    strategy:
      type: rollingUpdate
```

이유:

- `Rollout`은 Argo Rollouts의 CRD 이름이므로 values contract가 특정 구현체에 묶인다.
- Kubernetes 기본 컴포넌트 관점에서 `Deployment`는 `ReplicaSet`을 관리하고, `StatefulSet`은 자체 controller가 Pod를 관리한다.
- chart 사용자가 선택해야 하는 것은 내부 controller 이름보다 application 실행 형태와 배포 전략이다.
- 따라서 `workload.type`은 `stateless` 또는 `stateful`로 두고, 실제 manifest는 chart 내부 구현에서 선택한다.

내부 구현:

- 현재 progressive delivery 구현체는 Argo Rollouts를 사용한다.
- values contract는 Argo Rollouts에 직접 종속되지 않도록 유지한다.
- canary/blue-green 전략을 선택한 경우 chart 내부에서는 Argo Rollouts 리소스로 렌더링한다.

### 10.5 Stateless Options

`workload.stateless`는 `workload.type: stateless`일 때 stateless workload 전용 설정을 담당한다.

지원 항목:

- `strategy.type`: `rollingUpdate`, `canary`, `blueGreen`
- `strategy.rollingUpdate`
- `strategy.canary`
- `strategy.blueGreen`

예상 구조:

```yaml
workload:
  type: stateless
  stateless:
    strategy:
      type: rollingUpdate
      rollingUpdate:
        maxSurge: 25%
        maxUnavailable: 25%
      canary:
        stableService: ""
        canaryService: ""
        trafficRouting: {}
        steps: []
        analysis: {}
      blueGreen:
        activeService: ""
        previewService: ""
        autoPromotionEnabled: true
        scaleDownDelaySeconds: 30
```

### 10.6 Stateful Options

`workload.stateful`은 `workload.type: stateful`일 때 StatefulSet 전용 설정을 담당한다.

지원 항목:

- `podManagementPolicy`: `OrderedReady` 또는 `Parallel`
- `updateStrategy.type`: `RollingUpdate` 또는 `OnDelete`
- `updateStrategy.rollingUpdate`
- `volumeClaimTemplates`

예상 구조:

```yaml
workload:
  type: stateful
  stateful:
    podManagementPolicy: OrderedReady
    updateStrategy:
      type: RollingUpdate
      rollingUpdate: {}
    volumeClaimTemplates: []
```

### 10.7 Security Context Placement

security context는 초기 설계에서 별도 top-level 섹션으로 분리하지 않고 `workload` 안에 둔다.

이유:

- `podSecurityContext`와 `securityContext`는 실제 Kubernetes Pod spec의 일부이다.
- `accessControl`은 ServiceAccount/RBAC처럼 "누구의 권한으로 실행되는가"를 담당하고, security context는 "Pod와 container가 어떻게 실행되는가"를 담당한다.
- top-level 섹션을 늘리지 않고도 workload 설정 안에서 자연스럽게 표현할 수 있다.

예상 구조:

```yaml
workload:
  podSecurityContext: {}
  securityContext: {}
```

기본값은 빈 값으로 둔다. 대부분의 Spring Boot 프로젝트가 Jib 기반 이미지로 빌드되는 경우 별도 security context 없이도 동작할 수 있으므로, chart가 초기부터 강한 기본값을 주입하지 않는다.

추후 Pod Security Admission, policy engine, 표준 security profile 같은 요구가 커지면 `security` top-level 섹션 분리를 재검토한다.

### 10.8 Volume Placement

volume과 volumeMount는 초기 설계에서 별도 top-level 섹션으로 분리하지 않고 `workload` 안에 둔다.

이유:

- `volumes`와 `volumeMounts`는 Pod spec의 일부이다.
- PVC, configMap, secret, emptyDir, projected volume 등은 결국 workload에 mount되어 사용된다.
- `config` 섹션은 ConfigMap/external secret의 생성 또는 참조 정책을 담당하고, workload 섹션은 해당 config를 Pod에 어떻게 주입할지 담당한다.

예상 구조:

```yaml
workload:
  volumes: []
  volumeMounts: []
  stateful:
    volumeClaimTemplates: []
```

StatefulSet의 `volumeClaimTemplates`는 `workload.stateful.volumeClaimTemplates`에서 관리한다.

## 11. Network

`network`는 application으로 들어오거나 application을 식별하기 위한 네트워크 리소스를 담당한다.

포함 범위:

- Service
- headless Service
- HTTPRoute
- GRPCRoute
- inbound authorization policy
- service labels
- service annotations
- route labels
- route annotations

지원 리소스:

- `Service`
- headless `Service`
- Gateway API `HTTPRoute`
- Gateway API `GRPCRoute`
- implementation-specific authorization policy

Service 지원 항목:

- enabled
- type
- ports
- targetPorts
- annotations
- labels
- headless mode
- sessionAffinity

HTTPRoute/GRPCRoute 지원 항목:

- enabled
- internal/external 구분
- parentRefs
- hostnames
- additionalHostnames
- dns auto registration
- rules
- matches
- filters
- backendRefs
- annotations
- labels

Route parentRef 입력 항목:

- gateway name
- gateway namespace

기본 convention:

- external gateway name: `external-gateway`
- internal gateway name: `internal-gateway`
- gateway namespace: `istio-gateway`

단, 이 값들은 templates 내부에 고정하지 않고 values에서 입력받는다.

Inbound authorization policy 지원 항목:

- authorization action
- authorization rules
- path/method 조건
- principal/claim/header 조건
- dry-run 또는 audit mode 가능성

기본 방향:

- Ingress는 지원하지 않는다.
- internal route와 external route는 독립적으로 켜고 끌 수 있어야 한다.
- GatewayClass/Gateway 자체는 chart 외부에서 관리한다.
- canary/blue-green 전략에서 필요한 service 참조와 route backend 조정이 가능해야 한다.
- values에서는 Istio `AuthorizationPolicy` 같은 구현체 이름을 직접 노출하지 않는다.
- 현재 인프라에서는 inbound authorization policy가 Istio 리소스로 렌더링될 수 있다.
- 다른 인프라에서는 같은 values contract를 Linkerd policy 또는 다른 L7 policy 리소스로 렌더링할 수 있어야 한다.

### 11.1 Application-Level L7 Policy

application은 JWT 검증 자체를 직접 수행하지 않는다.

목표 구조:

- JWT token validation은 service mesh 또는 L7 policy layer에서 처리한다.
- 검증된 claim은 request header로 application에 전달한다.
- application은 전달받은 header를 기반으로 비즈니스 인가만 수행한다.

JWT request authentication과 claim-to-header mapping은 gateway/platform layer에서 공통으로 관리한다. 이 chart는 request authentication 리소스를 생성하지 않는다.

application마다 route, method, claim 조건이 달라질 수 있으므로, 이 chart는 `network.authorizationPolicy`에서 application-level L7 authorization policy만 관리한다.

주의사항:

- 외부 클라이언트가 동일한 custom header를 임의로 주입하지 못하도록 gateway 또는 mesh layer에서 기존 inbound header를 제거하거나 overwrite해야 한다.
- claim-to-header mapping은 보안상 민감하므로 기본값보다 명시적 설정을 우선한다.
- request authentication policy는 application chart가 아니라 platform 공통 영역에서 관리한다.

## 12. Access Control

`accessControl`은 application의 Kubernetes identity와 권한을 담당한다.

포함 범위:

- ServiceAccount
- Role
- RoleBinding
- ClusterRole
- ClusterRoleBinding
- service account labels
- service account annotations

지원 항목:

- service account 생성 여부
- 기존 service account 사용
- service account annotations
- namespace-scoped RBAC rules
- cluster-scoped RBAC rules
- role binding subjects
- cloud provider workload identity annotation 확장 가능성

기본 방향:

- 기본값은 최소 권한 원칙을 따른다.
- ClusterRole/ClusterRoleBinding은 기본 비활성화한다.
- 애플리케이션이 Kubernetes API 접근이 필요할 때만 RBAC 생성을 활성화한다.
- security context는 access control에 포함하지 않고 workload에서 다룬다.

## 13. Config

`config`는 application에 주입되는 설정과 secret 참조를 담당한다.

포함 범위:

- ConfigMap
- external secret 참조
- env
- envFrom
- additional config
- OpenTelemetry auto-instrumentation 관련 env/annotation convention

ConfigMap 지원 항목:

- 생성 여부
- key/value data
- structured config 렌더링
- envFrom 참조 여부
- volume mount를 위한 참조 정보

Secret 정책:

- chart는 secret 값을 직접 생성하지 않는다.
- Kubernetes `Secret` manifest 생성은 기본 범위에서 제외한다.
- External Secrets Operator가 생성한 Secret을 참조하는 방식을 기본 지원한다.
- chart는 `ExternalSecret` 리소스를 생성한다.

Additional config:

- 애플리케이션별 추가 ConfigMap
- extra env
- extra envFrom
- external secret reference
- config file mount를 위한 workload volume 연결

## 14. Observability

초기 설계에서는 `observability`를 별도 top-level values 섹션으로 분리하지 않는다.

대신 observability와 관련된 설정은 실제로 영향을 주는 리소스 섹션에 둔다.

- Pod labels/annotations: `workload.podLabels`, `workload.podAnnotations`
- Service labels/annotations: `network.service.labels`, `network.service.annotations`
- Route labels/annotations: `network.routes.*.labels`, `network.routes.*.annotations`
- OpenTelemetry 관련 env/envFrom: `config.env`, `config.envFrom`

이유:

- Prometheus scrape, OpenTelemetry injection, logging convention은 대부분 Pod/Service annotation 또는 env 설정으로 표현된다.
- Prometheus Operator를 사용하더라도 `ServiceMonitor`/`PodMonitor` 생성은 별도 CRD 의존성을 만든다.
- OpenTelemetry Operator 기반 Java agent injection은 일반적으로 Pod annotation과 env 설정으로 제어할 수 있으므로 workload/config 섹션과 자연스럽게 연결된다.
- Spring Boot 프로젝트는 OpenTelemetry Java agent injection을 주된 observability 방식으로 사용하고, Node.js/Next.js/React 서비스는 JavaScript agent 주입 가능성을 고려한다.
- OpenTelemetry `Instrumentation` 리소스는 EKS 환경의 namespace 또는 platform 공통 리소스로 미리 생성해두는 방식을 기본으로 본다.
- application chart는 `Instrumentation` CR을 생성하지 않고, 필요한 Pod annotation/env를 통해 공통 `Instrumentation`을 참조하여 injection을 활성화한다.

추후 다음 요구가 명확해지면 `observability` top-level 섹션을 재검토한다.

- `ServiceMonitor`/`PodMonitor`를 chart가 직접 생성해야 하는 경우
- metrics, traces, logs 설정을 chart 레벨에서 표준화해야 하는 경우

## 15. Values Design Principles

values 설계 원칙:

- top-level 섹션은 `workload`, `network`, `accessControl`, `config`를 기본으로 한다.
- 기본값은 안전하고 작게 시작한다.
- 대부분의 리소스는 `enabled` 플래그를 가진다.
- Kubernetes 원본 spec과 너무 멀어지지 않는 구조를 유지한다.
- 자주 쓰는 설정은 간단한 구조로 제공한다.
- 고급 설정은 `extra*`, `annotations`, `labels`, `rawRules` 같은 확장 지점으로 열어둔다.
- chart가 모든 플랫폼 정책을 강제하기보다, 기본값과 override의 균형을 맞춘다.

예상 top-level values 구조:

```yaml
nameOverride: ""
fullnameOverride: ""

workload:
  enabled: true
  type: stateless
  replicas: 2
  image:
    repository: ""
    tag: ""
    pullPolicy: IfNotPresent
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 5
    targetCpuUtilization: null
    targetMemoryUtilization: null
  pdb:
    enabled: false
  podLabels: {}
  podAnnotations: {}
  podSecurityContext: {}
  securityContext: {}
  resources: {}
  nodeSelector: {}
  tolerations: []
  affinity: {}
  volumes: []
  volumeMounts: []
  stateless:
    strategy:
      type: rollingUpdate
      rollingUpdate:
        maxSurge: 25%
        maxUnavailable: 25%
      canary:
        stableService: ""
        canaryService: ""
        trafficRouting: {}
        steps: []
        analysis: {}
      blueGreen:
        activeService: ""
        previewService: ""
        autoPromotionEnabled: true
        scaleDownDelaySeconds: 30
  stateful:
    podManagementPolicy: OrderedReady
    updateStrategy:
      type: RollingUpdate
      rollingUpdate: {}
    volumeClaimTemplates: []

network:
  service:
    enabled: true
  headlessService:
    enabled: false
  httpRoute:
    internal:
      enabled: false
      parentRef:
        name: ""
        namespace: ""
      hostnames: []
      additionalHostnames: []
      dnsAutoRegistration:
        enabled: false
    external:
      enabled: false
      parentRef:
        name: ""
        namespace: ""
      hostnames: []
      additionalHostnames: []
      dnsAutoRegistration:
        enabled: false
  grpcRoute:
    internal:
      enabled: false
    external:
      enabled: false
  authorizationPolicy:
    enabled: false
    action: ALLOW
    rules: []

accessControl:
  serviceAccount:
    create: true
  rbac:
    create: false

config:
  configMap:
    enabled: false
  externalSecrets:
    enabled: false
  env: []
  envFrom: []
  additionalConfig: []
```

## 16. Proposed Repository Structure

초기 구현 시 다음 구조를 권장한다.

```text
.
├── README.md
├── CONTEXT.md
├── LICENSE
└── application-base
    ├── .helmignore
    ├── Chart.yaml
    ├── values.yaml
    ├── values.schema.json
    ├── templates
    │   ├── _helpers.tpl
    │   ├── workload.yaml
    │   ├── service.yaml
    │   ├── httproute.yaml
    │   ├── grpcroute.yaml
    │   ├── serviceaccount.yaml
    │   ├── rbac.yaml
    │   ├── configmap.yaml
    │   ├── externalsecret.yaml
    │   ├── hpa.yaml
    │   ├── pdb.yaml
    │   ├── inbound-authorization-policy.yaml
    │   └── tests
    │       └── test-connection.yaml
    └── examples
        ├── application.yaml
        └── stateful.yaml
```

chart는 `application-base/` 하위에 구성하고, 이 chart를 배포 대상으로 삼는다.

## 17. Compatibility Requirements

추후 확정해야 할 버전:

- Kubernetes minimum version
- Helm minimum version
- Argo Rollouts version
- Gateway API version
- External Secrets Operator version
- Service mesh version
- CNI version
- OpenTelemetry Operator version
- Prometheus Operator version

초기 권장 방향:

- Kubernetes는 실제 운영 클러스터의 지원 버전을 기준으로 최소 버전을 확정한다.
- Gateway API와 Argo Rollouts CRD 버전은 실제 클러스터 설치 버전에 맞춘다.
- Helm template에서 `.Capabilities.APIVersions.Has`를 활용해 CRD 존재 여부를 검증할지 결정한다.

## 18. Operational Requirements

chart는 운영 환경에서 다음 특성을 가져야 한다.

- dry-run과 template 렌더링이 안정적으로 동작해야 한다.
- 필수 values가 누락되었을 때 명확한 error message를 제공해야 한다.
- 기본 설정으로 과도한 권한을 생성하지 않아야 한다.
- HPA와 PDB 설정이 서로 충돌하지 않도록 문서화해야 한다.
- canary/blue-green 사용 시 필요한 service 및 route 관계가 명확해야 한다.
- 특정 service mesh 구현체에만 맞는 값을 user-facing values contract에 노출하지 않아야 한다.
- external secret을 사용하는 경우 secret 생성 주체와 참조 주체가 분리되어야 한다.
- OpenTelemetry auto-instrumentation이 필요한 경우 Pod annotation/env 기반으로 주입 가능해야 한다.

## 19. Validation and Testing Requirements

초기 검증 방식:

- `helm lint`
- `helm template`
- values schema validation
- 대표 example values 렌더링 테스트
- kubeconform 또는 kubeval 기반 manifest validation

필수 example:

- 기본 application
- internal HTTPRoute application
- external HTTPRoute application
- internal GRPCRoute application
- StatefulSet application
- canary strategy application
- blue-green strategy application
- external secret 참조 application
- OpenTelemetry Java agent injection application

## 20. Open Questions

아래 항목은 PRD 확정 전에 추가 결정이 필요하다.

- Kubernetes 최소 버전
- Helm 최소 버전
- custom autoscaling metric을 chart에서 표준화할지
- Prometheus Operator `ServiceMonitor`/`PodMonitor`를 포함할지
- gateway/platform layer의 claim-to-header mapping convention

## 21. License

이 프로젝트는 MIT License를 유지한다.
