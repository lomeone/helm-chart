# Project Context

## Purpose

`application-base` is a generic Helm chart for deploying Kubernetes applications with a stable, implementation-neutral values contract.

The chart is intended to be reused across applications. Users configure application behavior through `values.yaml`, while the chart templates render the platform-specific Kubernetes resources.

## Design Principles

- Keep user-facing values focused on application intent, not infrastructure implementation details.
- Organize values around four sections: `workload`, `network`, `accessControl`, and `config`.
- Avoid exposing service mesh specific names in values.
- Avoid exposing progressive delivery controller specific names in values.
- Prefer safe empty defaults where platform policy may vary.
- Do not create raw Kubernetes `Secret` resources from literal secret values.

## Current Implementation Choices

- Chart path: `application-base/`
- Stateless workload implementation: Argo Rollouts `Rollout`
- Stateful workload implementation: Kubernetes `StatefulSet`
- HTTP routing: Gateway API `HTTPRoute`
- gRPC routing: Gateway API `GRPCRoute`
- Secret integration: External Secrets Operator `ExternalSecret`
- Inbound authorization implementation: Istio `AuthorizationPolicy`
- Request authentication: not created by this chart
- OpenTelemetry `Instrumentation`: not created by this chart

## Authentication and Authorization Boundary

JWT request authentication and claim-to-header mapping are platform responsibilities.

The expected request flow is:

```text
gateway/platform layer
  -> validates JWT
  -> strips or overwrites untrusted identity headers
  -> maps verified claims into trusted request headers
  -> forwards request into the mesh
application-base chart
  -> optionally renders application-specific inbound authorization policy
application
  -> performs business authorization from trusted headers
```

The chart should only manage application-specific authorization policy. It should not render Istio `RequestAuthentication` or equivalent service mesh authentication resources.

## Observability Boundary

OpenTelemetry `Instrumentation` resources are expected to be managed as namespace or platform shared resources.

Application charts enable injection through pod annotations and environment variables only.

## Outstanding Decisions

- Kubernetes minimum version
- Helm minimum version
- StatefulSet `volumeClaimTemplates` support level
- custom autoscaling metric standardization
- whether to render Prometheus Operator `ServiceMonitor` or `PodMonitor`
- gateway/platform claim-to-header mapping convention

