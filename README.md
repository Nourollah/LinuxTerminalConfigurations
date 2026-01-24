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
- optionally installing common CLI tools
- optionally configuring Vim/Neovim
- optionally installing Pixi and UV

### `ZSH-P10k.sh`
Sets up a Zsh environment by:
- installing **oh\-my\-zsh**
- configuring **powerlevel10k**
- optionally installing common CLI tools
- optionally configuring Vim/Neovim
- optionally installing Pixi and UV

## Notes
- These scripts may modify your shell startup files (for example `~/.bashrc` or `~/.zshrc`) and may install packages using `sudo`.
- Restart the terminal session after running, or reload your shell config.