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
- Cilium, Istio ambient mode, Gateway API, Argo Rollouts 같은 플랫폼 표준이 서비스마다 다르게 적용될 수 있다.
- 배포 전략, 보안 컨텍스트, external secret 참조 방식, resource 정책, probe 정책이 일관되지 않다.
- chart 유지보수 비용이 서비스 수에 비례해 증가한다.
- 플랫폼팀과 애플리케이션팀 사이에서 "무엇을 values로 열고, 무엇을 표준으로 고정할지"가 불명확해진다.

이 프로젝트는 공통 배포 패턴을 하나의 base chart로 표준화하여, 애플리케이션별 chart 작성 비용을 줄이고 배포 품질을 일관되게 유지하는 것을 목표로 한다.

## 4. Goals

- 여러 애플리케이션에서 재사용 가능한 generic Helm chart를 제공한다.
- `values.yaml` 중심으로 workload, network, access control, config 설정을 제어한다.
- Cilium CNI, Istio ambient mode, Gateway API 기반 트래픽 라우팅 환경을 전제로 설계한다.
- Argo Rollouts 기반 progressive delivery 전략을 지원한다.
- chart 사용자에게는 단순한 설정 경험을 제공하고, chart 유지보수자에게는 확장 가능한 템플릿 구조를 제공한다.
- 보안, 운영 안정성, 네트워크 표준을 chart 레벨에서 반복 가능하게 만든다.

## 5. Non-Goals

- 데이터베이스, Kafka, Redis 등 stateful dependency 자체를 설치하지 않는다.
- Cilium, Istio, Argo Rollouts, External Secrets Operator, Gateway API CRD를 chart 내부에서 설치하지 않는다.
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
- Cilium CNI
- Istio ambient mode
- Gateway API
- Argo Rollouts
- External Secrets Operator

환경 설계 메모:

- Kubernetes 클러스터 공급자는 chart 설계의 핵심 전제가 아니다.
- EKS, VPC CNI chaining, EKS Custom Networking, ENIConfig, CGNAT 대역 사용 여부는 chart manifest 구조에 직접 영향을 주지 않는 클러스터 인프라 영역으로 본다.
- Service mesh는 sidecar injection이 아닌 Istio ambient mode를 전제로 한다.
- Ingress는 사용하지 않는다.
- HTTP 트래픽은 Gateway API `HTTPRoute`를 사용한다.
- gRPC 트래픽은 Gateway API `GRPCRoute`를 사용한다.
- GatewayClass와 Gateway 자체는 chart 외부에서 관리한다고 가정한다.
- canary와 blue-green 배포는 Argo Rollouts CRD 사용을 전제로 한다.

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

지원 workload:

- Argo Rollouts 기반 `Rollout`
- `StatefulSet`
- 기본 Kubernetes `Deployment` 지원 여부는 추가 논의 필요

참고:

- Kubernetes `ReplicaSet`을 직접 values에서 관리하기보다 Argo Rollouts의 `Rollout` 리소스를 통해 replica 기반 배포를 관리하는 방향을 권장한다.
- rolling update는 native workload strategy 또는 Argo Rollouts strategy로 표현할 수 있다.
- canary와 blue-green은 Argo Rollouts를 통해 지원한다.

### 10.1 Autoscaling

`workload.autoscaling`은 HPA 생성을 담당한다.

지원 항목:

- enabled
- minReplicas
- maxReplicas
- CPU utilization metric
- Memory utilization metric
- custom metrics 확장 가능 구조
- behavior scaleUp/scaleDown 정책

### 10.2 Pod Disruption Budget

`workload.pdb`는 PDB 생성을 담당한다.

지원 항목:

- enabled
- minAvailable
- maxUnavailable

### 10.3 Deployment Strategy

`workload.strategy`는 배포 전략을 담당한다.

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

### 10.4 Security Context Placement

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

추후 Pod Security Admission, policy engine, 표준 security profile 같은 요구가 커지면 `security` top-level 섹션 분리를 재검토한다.

### 10.5 Volume Placement

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
```

StatefulSet의 `volumeClaimTemplates` 지원 여부는 추가 논의가 필요하다.

## 11. Network

`network`는 application으로 들어오거나 application을 식별하기 위한 네트워크 리소스를 담당한다.

포함 범위:

- Service
- headless Service
- HTTPRoute
- GRPCRoute
- service labels
- service annotations
- route labels
- route annotations

지원 리소스:

- `Service`
- headless `Service`
- Gateway API `HTTPRoute`
- Gateway API `GRPCRoute`

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
- rules
- matches
- filters
- backendRefs
- annotations
- labels

기본 방향:

- Ingress는 지원하지 않는다.
- internal route와 external route는 독립적으로 켜고 끌 수 있어야 한다.
- GatewayClass/Gateway 자체는 chart 외부에서 관리한다.
- Argo Rollouts canary/blue-green 전략에서 필요한 service 참조와 route backend 조정이 가능해야 한다.

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
- `ExternalSecret` 리소스 생성을 chart가 담당할지, 기존 Secret 참조만 담당할지는 추가 논의한다.

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

추후 다음 요구가 명확해지면 `observability` top-level 섹션을 재검토한다.

- `ServiceMonitor`/`PodMonitor`를 chart가 직접 생성해야 하는 경우
- OpenTelemetry `Instrumentation` CR을 chart가 직접 생성해야 하는 경우
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
  type: Rollout
  replicas: 2
  image:
    repository: ""
    tag: ""
    pullPolicy: IfNotPresent
  strategy:
    type: rollingUpdate
  autoscaling:
    enabled: false
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

network:
  service:
    enabled: true
  headlessService:
    enabled: false
  httpRoute:
    internal:
      enabled: false
    external:
      enabled: false
  grpcRoute:
    internal:
      enabled: false
    external:
      enabled: false

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
├── Chart.yaml
├── README.md
├── CONTEXT.md
├── LICENSE
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
│   ├── hpa.yaml
│   ├── pdb.yaml
│   └── tests
│       └── test-connection.yaml
└── examples
    └── application.yaml
```

추가 고려:

- chart root를 repository root로 둘지, `charts/application-base` 하위로 둘지 결정이 필요하다.
- 단일 chart repository라면 root chart 구조가 단순하다.
- 여러 chart를 앞으로 관리할 계획이면 `charts/application-base` 구조가 낫다.

## 17. Compatibility Requirements

추후 확정해야 할 버전:

- Kubernetes minimum version
- Helm minimum version
- Argo Rollouts version
- Gateway API version
- External Secrets Operator version
- Istio version
- Cilium version
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
- Istio ambient mode 환경에서 sidecar 전제 설정을 넣지 않아야 한다.
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
- Argo Rollouts canary application
- Argo Rollouts blue-green application
- external secret 참조 application
- OpenTelemetry Java agent injection application

## 20. Open Questions

아래 항목은 PRD 확정 전에 추가 결정이 필요하다.

- chart root를 repository root로 둘지, `charts/application-base`로 둘지
- Kubernetes 최소 버전
- Helm 최소 버전
- Argo Rollouts 사용을 필수 전제로 둘지, optional로 둘지
- 기본 workload type을 `Rollout`, `Deployment`, `StatefulSet` 중 무엇으로 둘지
- native `Deployment`를 지원할지
- StatefulSet에서 volumeClaimTemplates를 지원할지
- ExternalSecret 리소스 생성을 chart가 담당할지, 기존 Secret 참조만 할지
- HTTPRoute/GRPCRoute parentRefs convention을 chart에서 얼마나 추상화할지
- internal/external Gateway 이름과 namespace convention
- custom autoscaling metric을 chart에서 표준화할지
- Prometheus Operator `ServiceMonitor`/`PodMonitor`를 포함할지
- OpenTelemetry `Instrumentation` 리소스를 chart가 생성할지
- 기본 securityContext 값을 강하게 둘지, 빈 값으로 두고 권장값만 문서화할지

## 21. License

이 프로젝트는 MIT License를 유지한다.

