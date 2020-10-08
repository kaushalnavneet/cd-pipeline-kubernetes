{{- define "pipeline.common.envvar.value" -}}
  {{- $name := index . 0 -}}
  {{- $secretName := index . 1 -}}
  {{- $secretKey := index . 2 -}}

  name: {{ $name }}
  valueFrom:
    configMapKeyRef:
      name: {{ $secretName }}
      key: {{ $secretKey }}
{{- end -}}


{{- define "pipeline.common.envvar.value.statefulset" -}}
  {{- $name := index . 0 -}}
  {{- $secretName := index . 1 -}}
  {{- $secretKey := index . 2 -}}

  name: {{ $name }}
            valueFrom:
              configMapKeyRef:
                name: {{ $secretName }}
                key: {{ $secretKey }}
{{- end -}}