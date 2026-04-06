{{/*
Expand the name of the chart.
*/}}
{{- define "uds.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "uds.fullname" -}}
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
{{- define "uds.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "uds.labels" -}}
helm.sh/chart: {{ include "uds.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Audit Service selector labels
*/}}
{{- define "uds.audit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uds.name" . }}-audit
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
User Management selector labels
*/}}
{{- define "uds.userMgmt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uds.name" . }}-user-mgmt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Application Management selector labels
*/}}
{{- define "uds.appMgmt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uds.name" . }}-app-mgmt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Document Management selector labels
*/}}
{{- define "uds.docMgmt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uds.name" . }}-doc-mgmt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "uds.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uds.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
