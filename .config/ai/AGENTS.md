# Global agent instructions

Shared by every AI coding agent on this machine. The dotfiles installer links
this one file to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
`~/.gemini/GEMINI.md` and `~/.config/opencode/AGENTS.md`. Project-level
instruction files take precedence over this one.

## Working style

- Read the surrounding code before changing it, and match its style, naming and comment density.
- Keep changes minimal and focused on the task; don't refactor unrelated code.
- Run the project's own lint, typecheck and tests before calling work done, and report failures honestly.
- Ask before destructive or hard-to-reverse actions: deleting files or branches, force-pushing, rewriting history, touching production.
- Never commit secrets. API keys live in `~/.config/ai/secrets.env`, which is not tracked.

## Environment

- Tools are managed by mise (`~/.config/mise/config.toml`); per-project versions come from `mise.toml`, `.nvmrc`, `.python-version`, `.go-version`.
- Prefer `rg` over `grep`, `fd` over `find`, `uv` for Python packages, and `gh` for GitHub.
- Git: commit only when asked; never commit directly to `main`.
