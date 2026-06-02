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
{{- else if (.Values.global).env -}}
{{- $prefix := printf "%s-" .Values.global.env -}}
{{- if hasPrefix $prefix .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Values.global.env .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
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
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
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
{{- printf "%s:%s" .Values.workload.image.repository .Values.workload.image.tag -}}
{{- end -}}

{{/*
Default route backendRefs.
*/}}
{{- define "application-base.defaultBackendRefs" -}}
- name: {{ include "application-base.fullname" . }}
  port: {{ (index .Values.network.service.ports 0).port | default 80 }}
{{- end -}}

{{/*
Build container env field block.
*/}}
{{- define "application-base.containerEnvBlock" -}}
{{- $env := concat (.Values.workload.env | default list) (.Values.config.env | default list) -}}
{{- with $env -}}
env:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Build container envFrom field block.
*/}}
{{- define "application-base.containerEnvFromBlock" -}}
{{- $envFrom := concat (.Values.workload.envFrom | default list) (.Values.config.envFrom | default list) -}}
{{- if and .Values.config.configMap.enabled (not .Values.config.configMap.mount.enabled) -}}
{{- $envFrom = append $envFrom (dict "configMapRef" (dict "name" (include "application-base.fullname" .))) -}}
{{- end -}}
{{- if and .Values.config.externalSecrets.enabled .Values.config.externalSecrets.envFrom.enabled -}}
{{- $secretName := default (include "application-base.fullname" .) .Values.config.externalSecrets.target.name -}}
{{- $envFrom = append $envFrom (dict "secretRef" (dict "name" $secretName)) -}}
{{- end -}}
{{- with $envFrom -}}
envFrom:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Build container volumeMounts field block.
*/}}
{{- define "application-base.containerVolumeMountsBlock" -}}
{{- $volumeMounts := .Values.workload.volumeMounts | default list -}}
{{- if and .Values.config.configMap.enabled .Values.config.configMap.mount.enabled -}}
{{- $volumeMounts = append $volumeMounts (dict "name" .Values.config.configMap.mount.name "mountPath" .Values.config.configMap.mount.mountPath "readOnly" .Values.config.configMap.mount.readOnly) -}}
{{- end -}}
{{- with $volumeMounts -}}
volumeMounts:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Build pod volumes field block.
*/}}
{{- define "application-base.podVolumesBlock" -}}
{{- $volumes := .Values.workload.volumes | default list -}}
{{- if and .Values.config.configMap.enabled .Values.config.configMap.mount.enabled -}}
{{- $volumes = append $volumes (dict "name" .Values.config.configMap.mount.name "configMap" (dict "name" (include "application-base.fullname" .))) -}}
{{- end -}}
{{- with $volumes -}}
volumes:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Common pod spec shared by Rollout and StatefulSet.
Designed to be included with nindent 6 (spec: is at indent 4).
*/}}
{{- define "application-base.podSpec" -}}
serviceAccountName: {{ include "application-base.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.accessControl.serviceAccount.automountServiceAccountToken }}
{{- with .Values.workload.image.pullSecrets }}
imagePullSecrets:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end }}
{{- with .Values.workload.podSecurityContext }}
securityContext:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end }}
{{- with .Values.workload.priorityClassName }}
priorityClassName: {{ . | quote }}
{{- end }}
{{- if .Values.workload.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ .Values.workload.terminationGracePeriodSeconds }}
{{- end }}
{{- with .Values.workload.initContainers }}
initContainers:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end }}
containers:
  - name: {{ include "application-base.name" . }}
    image: {{ include "application-base.image" . | quote }}
    imagePullPolicy: {{ .Values.workload.image.pullPolicy }}
    {{- with .Values.workload.command }}
    command:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with .Values.workload.args }}
    args:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with .Values.workload.ports }}
    ports:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with include "application-base.containerEnvBlock" . }}{{- . | nindent 4 }}{{- end }}
    {{- with include "application-base.containerEnvFromBlock" . }}{{- . | nindent 4 }}{{- end }}
    {{- with .Values.workload.resources }}
    resources:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with .Values.workload.securityContext }}
    securityContext:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with .Values.workload.readinessProbe }}
    readinessProbe:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with .Values.workload.livenessProbe }}
    livenessProbe:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with .Values.workload.startupProbe }}
    startupProbe:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with .Values.workload.lifecycle }}
    lifecycle:
      {{- toYaml . | trimSuffix "\n" | nindent 6 }}
    {{- end }}
    {{- with include "application-base.containerVolumeMountsBlock" . }}{{- . | nindent 4 }}{{- end }}
  {{- with .Values.workload.extraContainers }}
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
  {{- end }}
{{- with include "application-base.podVolumesBlock" . }}{{- . | nindent 0 }}{{- end }}
{{- with .Values.workload.nodeSelector }}
nodeSelector:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end }}
{{- with .Values.workload.affinity }}
affinity:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end }}
{{- with .Values.workload.tolerations }}
tolerations:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end }}
{{- with .Values.workload.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | trimSuffix "\n" | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Render a parentRef from route values.
*/}}
{{- define "application-base.parentRef" -}}
- name: {{ .route.parentRef.name | quote }}
{{- with .route.parentRef.namespace }}
  namespace: {{ . | quote }}
{{- end }}
{{- end -}}
