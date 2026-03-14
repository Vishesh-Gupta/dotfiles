# Aliases.

_define_alias() {
  local name="$1"
  local value="$2"
  local allow_override="${3:-0}"

  if [[ -n "${aliases[$name]-}" ]]; then
    local existing="${aliases[$name]}"
    if [[ "$existing" != "$value" ]] && [[ "$allow_override" != "1" ]]; then
      print -u2 -- "[alias-collision] $name already set to '$existing', skipping '$value'"
      return 0
    fi
  fi

  alias "$name=$value"
}

_define_alias v 'view'
_define_alias gcleanup 'git-cleanup'
_define_alias tf 'terraform'
_define_alias tfi 'terraform init'
_define_alias tfp 'terraform plan'
_define_alias tfa 'terraform apply'
_define_alias tfd 'terraform destroy'
_define_alias tfv 'terraform validate'
_define_alias tff 'terraform fmt -recursive'
_define_alias tfw 'terraform workspace'
_define_alias tfo 'terraform output'

if command -v kubectl >/dev/null 2>&1; then
  _define_alias k 'kubectl'
  _define_alias kg 'kubectl get'
  _define_alias kd 'kubectl describe'
  _define_alias kl 'kubectl logs'
  _define_alias kaf 'kubectl apply -f'
  _define_alias kdf 'kubectl delete -f'
  _define_alias kctx 'kubectl config current-context'
  _define_alias kgns 'kubectl get namespaces'
  _define_alias kgp 'kubectl get pods'
  _define_alias kgpa 'kubectl get pods -A'
  _define_alias kgs 'kubectl get svc'
  _define_alias kgsa 'kubectl get svc -A'
  _define_alias kdp 'kubectl describe pod'
  _define_alias kx 'kubectl exec -it'
fi

if command -v gcloud >/dev/null 2>&1; then
  _define_alias gcld 'gcloud'
  _define_alias gclda 'gcloud auth list'
  _define_alias gcldp 'gcloud config list project'
  _define_alias gcldc 'gcloud config list'
  _define_alias gcldi 'gcloud compute instances list'
  _define_alias gcldk 'gcloud container clusters list'
fi

if command -v eza >/dev/null 2>&1; then
  _define_alias ls 'eza --icons' 1
  _define_alias la 'eza -a' 1
  _define_alias ll 'eza -la --git --icons' 1
fi
