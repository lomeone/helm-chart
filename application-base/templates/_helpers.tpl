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

{{/*
Render pod spec shared by Rollout and StatefulSet.
*/}}
{{- define "application-base.podSpec" -}}
serviceAccountName: {{ include "application-base.serviceAccountName" . }}
{{- with .Values.workload.image.pullSecrets }}
imagePullSecrets:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.workload.podSecurityContext }}
securityContext:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.workload.priorityClassName }}
priorityClassName: {{ . | quote }}
{{- end }}
{{- if .Values.workload.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ .Values.workload.terminationGracePeriodSeconds }}
{{- end }}
{{- with .Values.workload.initContainers }}
initContainers:
{{ toYaml . | indent 2 }}
{{- end }}
containers:
  - name: {{ include "application-base.name" . }}
    image: {{ include "application-base.image" . | quote }}
    imagePullPolicy: {{ .Values.workload.image.pullPolicy }}
{{- with .Values.workload.command }}
    command:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.args }}
    args:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.ports }}
    ports:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.env }}
    env:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.config.env }}
{{- if $.Values.workload.env }}
{{ toYaml . | indent 6 }}
{{- else }}
    env:
{{ toYaml . | indent 6 }}
{{- end }}
{{- end }}
{{- $envFrom := concat (.Values.workload.envFrom | default list) (.Values.config.envFrom | default list) -}}
{{- if .Values.config.configMap.enabled -}}
{{- if .Values.config.configMap.mount.enabled -}}
{{- else -}}
{{- $envFrom = append $envFrom (dict "configMapRef" (dict "name" (include "application-base.fullname" .))) -}}
{{- end -}}
{{- end -}}
{{- if and .Values.config.externalSecrets.enabled .Values.config.externalSecrets.envFrom.enabled -}}
{{- $secretName := default (include "application-base.fullname" .) .Values.config.externalSecrets.target.name -}}
{{- $envFrom = append $envFrom (dict "secretRef" (dict "name" $secretName)) -}}
{{- end -}}
{{- with $envFrom }}
    envFrom:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.resources }}
    resources:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.securityContext }}
    securityContext:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.readinessProbe }}
    readinessProbe:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.livenessProbe }}
    livenessProbe:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.startupProbe }}
    startupProbe:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.lifecycle }}
    lifecycle:
{{ toYaml . | indent 6 }}
{{- end }}
{{- $volumeMounts := .Values.workload.volumeMounts | default list -}}
{{- if and .Values.config.configMap.enabled .Values.config.configMap.mount.enabled -}}
{{- $volumeMounts = append $volumeMounts (dict "name" .Values.config.configMap.mount.name "mountPath" .Values.config.configMap.mount.mountPath "readOnly" .Values.config.configMap.mount.readOnly) -}}
{{- end -}}
{{- with $volumeMounts }}
    volumeMounts:
{{ toYaml . | indent 6 }}
{{- end }}
{{- with .Values.workload.extraContainers }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- $volumes := .Values.workload.volumes | default list -}}
{{- if and .Values.config.configMap.enabled .Values.config.configMap.mount.enabled -}}
{{- $volumes = append $volumes (dict "name" .Values.config.configMap.mount.name "configMap" (dict "name" (include "application-base.fullname" .))) -}}
{{- end -}}
{{- with $volumes }}
volumes:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.workload.nodeSelector }}
nodeSelector:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.workload.affinity }}
affinity:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.workload.tolerations }}
tolerations:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.workload.topologySpreadConstraints }}
topologySpreadConstraints:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
