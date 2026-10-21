# Dotfiles

[![Quality and Security Checks](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/quality-and-security.yml/badge.svg)](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/quality-and-security.yml)

One AI-ready developer setup for **macOS and Debian/Ubuntu**: the same shell, the same tools, the same AI agents on every machine, including servers and containers where you run as root.

## How it works

| Layer | macOS | Debian / Ubuntu |
| --- | --- | --- |
| System packages | Homebrew (`Brewfile`: GUI apps only) | apt (`zsh`, `git`, `curl`, `build-essential`, ...) |
| CLI tools, runtimes, AI agents | **mise** (`.config/mise/config.toml`) | **mise** (same file) |
| Rust | rustup (official installer) | rustup (official installer) |
| Shell | zsh + Oh My Zsh + Starship | zsh + Oh My Zsh + Starship (set as login shell) |

Everything that can be cross-platform comes from **one tool list** in [`.config/mise/config.toml`](.config/mise/config.toml). mise installs prebuilt binaries into `~/.local/share/mise` without sudo, so it works the same for a laptop user and for root in a container.

## Installation

### One-liner (no clone)

```sh
curl -fsSL "https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh" | bash
```

Downloads this repo, installs in copy mode, then deletes the download. Preview with `| bash -s -- --dry-run`. Override the source with `DOTFILES_REPO=<owner>/<repo>` and `DOTFILES_REF=<branch-or-tag>`.

### Local clone (recommended if you edit the dotfiles)

```sh
git clone https://github.com/Vishesh-Gupta/dotfiles.git "$HOME/personal/dotfiles"
cd "$HOME/personal/dotfiles"
./scripts/install.sh
```

Then open a new terminal and sign in to the AI tools you use (`claude`, `codex`, `gemini`, `copilot`, ...). Run `ai-doctor` to see what's installed.

### Installer options

| Flag | Effect |
| --- | --- |
| `--link` (default) | Symlink files from the repo into `$HOME` |
| `--copy` | Copy files instead (needed for `--self-destruct`) |
| `--self-destruct` | Delete the repo after installing |
| `--no-packages` | Only sync dotfiles; skip apt/Homebrew, mise tools and Zsh plugins |
| `--dry-run` | Print what would happen |

The installer is idempotent. Existing dotfiles that differ from the repo are moved to `~/.dotfiles-backup/<timestamp>/` first.

Set `GITHUB_TOKEN` before installing on shared CI runners or networks, to avoid GitHub API rate limits when mise resolves versions.

## AI tools

Installed on every machine through mise:

| Command | Tool |
| --- | --- |
| `claude` | Claude Code |
| `codex` | OpenAI Codex CLI |
| `gemini` | Google Gemini CLI |
| `copilot` | GitHub Copilot CLI |
| `opencode` | opencode |
| `cursor-agent` | Cursor CLI agent |
| `llm` | Simon Willison's `llm` (prompts, embeddings, plugins from the shell) |
| `aider` | aider |

Add or remove agents by editing the `[tools]` table in `.config/mise/config.toml`, then run `mise install`. Update everything with `mise upgrade`.

**Shared instructions.** [`.config/ai/AGENTS.md`](.config/ai/AGENTS.md) is linked to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md` and `~/.config/opencode/AGENTS.md`, so every agent follows the same global rules. Edit it once.

**API keys.** Put keys in `~/.config/ai/secrets.env`. The installer creates it as an empty `chmod 600` template, and it is never tracked. zsh and bash load it automatically. Most agents also support browser sign-in, so keys are optional.

**Agents see your tools.** AI agents and editors run commands in non-interactive shells that skip `.zshrc`. `~/.zshenv`, `~/.profile` and `~/.bashrc` put mise's shims on `PATH`, so agents get the same `rg`, `node`, `python` and so on as your terminal.

## Developer tools

Also from mise, on both platforms:

- **Shell:** `bat`, `eza`, `fd`, `fzf`, `ripgrep`, `zoxide`, `starship`
- **Git:** `gh`, `delta`, `lazygit`
- **Languages:** `node` (LTS), `python`, `go`, `uv`, plus Rust via rustup (`clippy`, `rustfmt`, `rust-analyzer`)
- **Utilities:** `jq`, `yq`, `btop`, `glow`, `hyperfine`, `tealdeer` (`tldr`), `zellij`, `shellcheck`

macOS only (Homebrew `Brewfile`): Ghostty.

## What's configured

- **fzf:** uses `fd` (respects `.gitignore`, includes dotfiles). `Ctrl-T` finds files with a `bat` preview, `Alt-C` jumps to a directory with an `eza` tree preview, `Ctrl-R` searches history, and `**<Tab>` gives fuzzy path completion.
- **fzf-tab:** every Tab completion opens in fzf; `cd <Tab>` previews directory contents.
- **eza:** `ls`, `la`, `ll` (git status, relative times), `lt` (tree, respects `.gitignore`).
- **zoxide:** `cd` learns your directories; `cd foo` jumps to the best match.
- **git + delta:** highlighted diffs with line numbers, histogram diffs, `zdiff3` conflicts, `pull --rebase` with autostash, auto upstream on first push, pruning on fetch. Keep your name and email in `~/.gitconfig`.
- **mise:** per-project versions from `mise.toml`, `.nvmrc`, `.python-version`, `.go-version`.
- **History:** 100k entries shared across shells, with timestamps and no duplicates. Commands starting with a space are not saved.
- **Zellij:** copies to the system clipboard over OSC 52, so it works over SSH and on both platforms.

## Repository layout

- `.zshrc`: entrypoint that loads `.zshrc.d/*.zsh` in order (`env`, `fzf`, `oh-my-zsh`, `history`, `prompt`, `tools`, `functions`, `aliases`, `ai`), then `~/.zshrc.local` if present
- `.zshenv`, `.zprofile`, `.profile`, `.bashrc`: `PATH` for every shell, including non-interactive ones
- `.config/mise/config.toml`: the cross-platform tool list
- `.config/ai/AGENTS.md`: global instructions shared by all AI agents
- `.config/git/`: git defaults and global ignore
- `.config/ghostty/config`, `.config/zellij/config.kdl`, `.config/starship.toml`: terminal, multiplexer and prompt
- `Brewfile`: macOS-only apps
- `scripts/install.sh`, `scripts/bootstrap.sh`: installer and one-liner entrypoint

## Shell helpers

- `ai-doctor`: lists installed AI tools and which API keys are set
- `view <file>`: syntax-highlighted file viewer (`bat`), renders Markdown with `glow`
- `git-cleanup` / `gcleanup`: deletes local branches whose upstream was deleted, after confirmation
- `tfinit`: `terraform init` plus a multi-platform provider lock
- `bench-shell [runs]`: measures interactive zsh startup time with `hyperfine`

## Testing

```sh
./scripts/test.sh          # syntax, config parsing, real installs into a temp $HOME, clean zsh startup
./scripts/security-scan.sh # shellcheck + advisory scan for risky shell patterns
```

CI also runs the full installer on macOS, Ubuntu (as a sudo user) and a Debian container (as root), then checks that every tool is reachable from interactive and non-interactive shells.

## Maintenance

```sh
cd "$HOME/personal/dotfiles" && git pull && ./scripts/install.sh   # re-sync everything
mise upgrade                                                          # update tools and AI agents
```

## Security notes

- Review remote scripts before running `curl | bash`.
- Keep secrets in `~/.config/ai/secrets.env` or `~/.zshrc.local`, never in this repo.
