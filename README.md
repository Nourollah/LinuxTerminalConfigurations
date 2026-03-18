# Linux CLI Bootstrap (Bash \+ oh\-my\-bash \+ Vim/Neovim)

This repository provides bootstrap scripts to quickly configure a Linux command\-line environment. The focus is on a nicer interactive shell experience, a small set of common CLI tools, and an editor setup (Vim/Neovim).

## Quick install

### Basic installation ways
| Method | Command |
|:--|:--|
| curl \(Bash \+ oh\-my\-bash\) | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/Nourollah/linux-cli-config-zsh-vim/main/BASH-OMB.sh)"` |
| wget \(Bash \+ oh\-my\-bash\) | `bash -c "$(wget -qO- https://raw.githubusercontent.com/Nourollah/linux-cli-config-zsh-vim/main/BASH-OMB.sh)"` |

## What the scripts do (high level)

### `BASH-OMB.sh`
Sets up a Bash environment by:
- installing **oh\-my\-bash**
- setting the oh\-my\-bash theme to **powerline**
- optionally installing CLI tools \(see full list below\)
- optionally configuring Vim/Neovim
- optionally installing Pixi and UV

### `ZSH-P10k.sh`
Sets up a Zsh environment by:
- installing **oh\-my\-zsh**
- configuring **powerlevel10k**
- optionally installing CLI tools \(see full list below\)
- optionally configuring Vim/Neovim
- optionally installing Pixi and UV

## Optional CLI tools installed by the scripts

When the script asks:
- `Install optional packages for detected OS (...) ?`

and you answer `yes`, it installs the following packages:

| Tool / Package | What it does |
|:--|:--|
| `fzf` | Interactive fuzzy finder for files, command history, and any text list in terminal workflows. |
| `ripgrep` \(`rg`\) | Very fast recursive text search tool; useful replacement for many `grep -R` use cases. |
| `fd-find` | Faster and simpler alternative to `find` with sane defaults. \(On some distros the command is `fdfind`\). |
| `jq` | JSON parser/formatter for CLI pipelines; extract/filter JSON fields from API responses and files. |
| `bat` | `cat` replacement with syntax highlighting, line numbers, and Git integration. |
| `tmux` | Terminal multiplexer for persistent, split, and multi-window shell sessions. |
| `btop` | Interactive system monitor for CPU, memory, disk, network, and processes. |
| `lsd` | Modern `ls` replacement with icons, colors, and tree view support. |
| `ncdu` | Interactive disk usage analyzer to find large files/folders quickly. |
| `neovim` | Modern Vim-based editor for terminal-centric editing and plugin workflows. |
| `curl` | Command-line data transfer tool for HTTP/HTTPS and other protocols. |
| `git` | Distributed version control system used for source control and repository operations. |

### Notes about package names/commands
- The package list above reflects what the scripts install with `apt`/`dnf`.
- On Debian-like systems, some commands can differ from package names \(for example `fd-find` may provide `fdfind`\).
- `ZSH-P10k.sh` also requires `wget` to bootstrap oh-my-zsh installation.

## Notes
- These scripts may modify your shell startup files (for example `~/.bashrc` or `~/.zshrc`) and may install packages using `sudo`.
- Restart the terminal session after running, or reload your shell config.