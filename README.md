# Dotfiles

[![CI](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/ci.yml)

One command to set up a new machine, **macOS or Debian/Ubuntu**. Pick your tools from a menu and get the same shell, CLI tools and AI agents everywhere, including servers and containers where you run as root.

## Set up a new machine

```sh
curl -fsSL https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh | bash
```

or, where only `wget` is available:

```sh
wget -qO- https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh | bash
```

This puts the dotfiles in `~/.dotfiles` and opens the tool menu:

```text
Dotfiles setup: choose what to install
↑/↓ move · space toggle · a all · n none · enter install · q quit
Always installed: zsh config, Shell essentials

AI agents
> [x] Claude Code
  [x] OpenAI Codex CLI
  [x] Google Gemini CLI
  [x] GitHub Copilot CLI
  [ ] opencode
  [ ] Cursor agent CLI
  ...
Languages
  [x] Node.js (LTS)
  [x] Python 3.13 + uv
  ...
```

Press Enter and it installs everything you ticked, then sets zsh as your shell. Open a new terminal, sign in to your AI tools, and run `dotfiles doctor`.

Skip the menu with installer options after `bash -s --`:

```sh
curl -fsSL .../bootstrap.sh | bash -s -- --all                  # everything
curl -fsSL .../bootstrap.sh | bash -s -- --yes                  # defaults (or your last selection)
curl -fsSL .../bootstrap.sh | bash -s -- --tools claude,node,go # exactly these (see: dotfiles list)
curl -fsSL .../bootstrap.sh | bash -s -- --dry-run              # preview only
```

## The `dotfiles` command

After setup, manage the machine like Homebrew:

| Command | What it does |
| --- | --- |
| `dotfiles install` | Open the menu again to add or remove tools |
| `dotfiles update` | Pull the latest dotfiles and re-apply your selection |
| `dotfiles upgrade` | Upgrade every tool and AI agent (`mise upgrade`, `rustup update`) |
| `dotfiles doctor` | Check that everything you selected is installed |
| `dotfiles list` | Show the tool catalog |
| `dotfiles dir` | Print where the dotfiles live (`~/.dotfiles`) |

## How it works

| Layer | macOS | Debian / Ubuntu |
| --- | --- | --- |
| Base system | Command Line Tools (git) | apt: `zsh`, `git`, `curl`, `build-essential`, ... (sudo only if not root) |
| CLI tools, runtimes, AI agents | **mise** | **mise** (same versions) |
| Rust | rustup | rustup |
| Desktop apps | Homebrew casks (only if you pick one) | n/a |

- **[`tools.conf`](tools.conf)** is the catalog behind the menu. Each line is a tool id, section, label, default (`core`/`on`/`off`) and how to install it. To add a tool, add a line, then run `dotfiles install`.
- The installer turns your selection into `~/.config/mise/config.toml`, and mise installs prebuilt binaries into `~/.local/share/mise` without sudo.
- Your selection is saved in `~/.config/dotfiles/selected-tools`, so the menu starts from your last choice and `dotfiles update` re-applies it.
- Existing dotfiles that differ from the repo are moved to `~/.dotfiles-backup/<timestamp>/` before being replaced.

## AI setup

- **Agents in the menu:** Claude Code, Codex, Gemini CLI, Copilot CLI, opencode, Cursor agent, `llm` and aider. On macOS you can also pick the Claude and ChatGPT desktop apps.
- **Shared instructions:** [`.config/ai/AGENTS.md`](.config/ai/AGENTS.md) is linked to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md` and `~/.config/opencode/AGENTS.md`, so every agent follows the same rules. Edit it once.
- **API keys:** go in `~/.config/ai/secrets.env`, which is created as an empty `chmod 600` template and never tracked. zsh and bash load it. Most agents also support browser sign-in.
- **Agents see your tools:** AI agents and editors run commands in non-interactive shells. `~/.zshenv`, `~/.profile` and `~/.bashrc` put mise's shims on `PATH`, so agents get the same `rg`, `node` and `python` as your terminal.
- **`ai-doctor`:** shows installed agents and which API keys are set.

## Shell

- **Always installed:** zsh with Oh My Zsh, fzf-tab, autosuggestions and syntax highlighting, plus Starship, fzf, fd, ripgrep, bat, eza, zoxide and delta.
- **fzf:** `Ctrl-T` finds files (with a `bat` preview), `Alt-C` jumps to a directory (with an `eza` tree preview), `Ctrl-R` searches history, and `**<Tab>` gives fuzzy path completion.
- **eza:** `ls`, `la`, `ll` (git status, relative times), `lt` (tree).
- **zoxide:** `cd` learns your directories; `cd foo` jumps to the best match.
- **git + delta:** highlighted diffs, `zdiff3` conflicts, `pull --rebase` with autostash, auto upstream on first push, pruning on fetch. Keep your name and email in `~/.gitconfig`.
- **mise:** per-project versions from `mise.toml`, `.nvmrc`, `.python-version`, `.go-version`.
- **History:** 100k entries shared across shells, with no duplicates. Commands starting with a space are not saved.
- **Helpers:** `view <file>`, `git-cleanup` (asks first), `tfinit`, `bench-shell`.
- **Machine-specific settings:** put them in `~/.zshrc.local` (not tracked).

## Repository layout

- `scripts/bootstrap.sh`: the one-liner entrypoint (curl or wget, then git clone or tarball)
- `scripts/install.sh`: menu and installer (works with macOS's built-in bash 3.2)
- `tools.conf`: tool catalog
- `bin/dotfiles`: the `dotfiles` command
- `.zshrc`, `.zshrc.d/*.zsh`: zsh config split by concern
- `.zshenv`, `.zprofile`, `.profile`, `.bash_profile`, `.bashrc`: `PATH` for every shell
- `.config/`: git, Starship, Ghostty, Zellij and shared AI agent instructions

## Testing

```sh
./scripts/test.sh          # catalog, generated config, menu (via a pty), bootstrap, installs into a temp $HOME
./scripts/security-scan.sh # shellcheck + advisory scan for risky shell patterns
```

## CI and updates

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every pull request, on pushes to `main`, weekly (Monday) and on demand:

| Job | Checks |
| --- | --- |
| `lint` | jactionlint for workflows, shellcheck and the risky-pattern scan |
| `test` | `scripts/test.sh` on Ubuntu and on macOS with the system bash 3.2 |
| `full-install` | the real installer on macOS, Ubuntu (`--all`) and a root Debian container, run twice, then every tool checked from zsh and login bash |
| `bootstrap` | the documented `wget \| bash` one-liner against the branch |

Actions are pinned to commit SHAs. [Dependabot](.github/dependabot.yml) proposes updates weekly, grouped into one PR, after a 7-day cooldown. CLI tools and AI agents track `latest` through mise instead, so the weekly CI run is what catches an upstream release that breaks the setup.

## Security notes

- Read `scripts/bootstrap.sh` before piping it to bash.
- Keep secrets in `~/.config/ai/secrets.env` or `~/.zshrc.local`, never in this repo.
