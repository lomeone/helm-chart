{{/*
Expand the name of the chart.
*/}}
{{- define "application-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "application-base.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "application-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "application-base.labels" -}}
helm.sh/chart: {{ include "application-base.chart" . }}
{{ include "application-base.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "application-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "application-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Common annotations.
*/}}
{{- define "application-base.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "application-base.serviceAccountName" -}}
{{- if .Values.accessControl.serviceAccount.create -}}
{{- default (include "application-base.fullname" .) .Values.accessControl.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.accessControl.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Container image reference.
*/}}
{{- define "application-base.image" -}}
{{- $repo := required "workload.image.repository is required" .Values.workload.image.repository -}}
{{- $tag := required "workload.image.tag is required" .Values.workload.image.tag -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}

{{/*
Build route hostnames by joining hostnames and additionalHostnames.
*/}}
{{- define "application-base.routeHostnames" -}}
{{- $hostnames := list -}}
{{- range .hostnames -}}
{{- $hostnames = append $hostnames . -}}
{{- end -}}
{{- range .additionalHostnames -}}
{{- $hostnames = append $hostnames . -}}
{{- end -}}
{{- toYaml $hostnames -}}
{{- end -}}

{{/*
Default route backendRefs.
*/}}
{{- define "application-base.defaultBackendRefs" -}}
- name: {{ include "application-base.fullname" . }}
  port: {{ (index .Values.network.service.ports 0).port | default 80 }}
{{- end -}}

{{/*
Render a parentRef from route values.
*/}}
{{- define "application-base.parentRef" -}}
{{- if not .route.parentRef.name -}}
{{- fail "route parentRef.name is required when a route is enabled" -}}
{{- end -}}
- name: {{ .route.parentRef.name | quote }}
{{- with .route.parentRef.namespace }}
  namespace: {{ . | quote }}
{{- end }}
{{- end -}}
