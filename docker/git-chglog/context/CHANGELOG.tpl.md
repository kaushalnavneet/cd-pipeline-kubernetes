{{ if .Versions -}}
## [Unreleased]({{ .Info.RepositoryURL }}/compare/{{ $latest := index .Versions 0 }}{{ $latest.Tag.Name }}...HEAD)

{{- if .Unreleased.MergeCommits}}
### Changes
{{ range .Unreleased.MergeCommits -}}
- {{ .Header }}({{.Hash.Long}})
{{ end }}
{{ end -}}

{{ range .Versions }}
## {{ if .Tag.Previous }}[{{ .Tag.Name }}]({{ $.Info.RepositoryURL }}/compare/{{ .Tag.Previous.Name }}...{{ .Tag.Name }}){{ else }}{{ .Tag.Name }}{{ end }} - {{ datetime "2006-01-02" .Tag.Date }}



{{- if .MergeCommits}}
### Changes
{{ range .MergeCommits -}}
- {{ .Header }} ({{.Hash.Long}})
{{ end }}
{{ end -}}

{{ end -}}

{{ end -}}