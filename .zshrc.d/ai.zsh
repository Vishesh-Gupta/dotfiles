# AI tooling: API keys and a health check.

# API keys (ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY, ...) live in an
# untracked file. Most agents can also sign in with a browser instead.
if [[ -r "$HOME/.config/ai/secrets.env" ]]; then
  set -a
  source "$HOME/.config/ai/secrets.env"
  set +a
fi

# Show which AI tools are installed and which API keys are set.
ai-doctor() {
  local -a tools=(claude codex gemini copilot opencode cursor-agent llm aider)
  local -a keys=(ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY GITHUB_TOKEN)
  local tool key version

  print -P "%BAI tools%b (change with: dotfiles install)"
  for tool in $tools; do
    if (( $+commands[$tool] )) && version="$($tool --version 2>/dev/null | head -n 1)"; then
      printf '  %-13s %s\n' "$tool" "${version:-installed}"
    else
      printf '  %-13s %s\n' "$tool" "-"
    fi
  done

  print -P "%BAPI keys%b (optional; most tools also support browser sign-in)"
  for key in $keys; do
    if [[ -n "${(P)key}" ]]; then
      printf '  %-18s set\n' "$key"
    else
      printf '  %-18s not set\n' "$key"
    fi
  done
}
