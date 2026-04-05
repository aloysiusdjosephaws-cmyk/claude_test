{{/*
Expand the name of the chart.
*/}}
{{- define "fullstack-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fullstack-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "fullstack-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fullstack-app.labels" -}}
helm.sh/chart: {{ include "fullstack-app.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Audit Service selector labels
*/}}
{{- define "fullstack-app.audit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fullstack-app.name" . }}-audit
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
User Management selector labels
*/}}
{{- define "fullstack-app.userMgmt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fullstack-app.name" . }}-user-mgmt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Application Management selector labels
*/}}
{{- define "fullstack-app.appMgmt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fullstack-app.name" . }}-app-mgmt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Document Management selector labels
*/}}
{{- define "fullstack-app.docMgmt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fullstack-app.name" . }}-doc-mgmt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "fullstack-app.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fullstack-app.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
