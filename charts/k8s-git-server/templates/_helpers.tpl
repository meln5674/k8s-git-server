{{/*
Expand the name of the chart.
*/}}
{{- define "k8s-git-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "k8s-git-server.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "k8s-git-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k8s-git-server.labels" -}}
helm.sh/chart: {{ include "k8s-git-server.chart" . }}
{{ include "k8s-git-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k8s-git-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-git-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "k8s-git-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "k8s-git-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "k8s-git-server.pvcName" -}}
{{- .Values.persistence.existingPersistentVolumeClaim.name | default (include "k8s-git-server.fullname" .) -}}
{{- end -}}

{{- define "k8s-git-server.externalHosts" -}}
{{- $dot := . -}}
{{- range .Values.ssh.externalHosts }}
{{ tpl . $dot }}
{{- end -}}
{{- end -}}

{{- define "k8s-git-server.secretName" -}}
{{- $dot := index . 0 -}}
{{- $user := index . 1 -}}
{{ with $dot.Values.ssh.secrets.namePrefix }}{{ . }}-{{ end }}{{ $user }}{{ with $dot.Values.ssh.secrets.nameSuffix }}-{{ . }}{{ end }}
{{- end -}}
