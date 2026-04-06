#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------
# Colors
# -----------------------------
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
LIGHTRED='\033[1;31m'

# -----------------------------
# Paths
# -----------------------------
ZSHRC_FILE="$HOME/.zshrc"
ZSHRC_D_DIR="$HOME/.zshrc.d"
ALIASES_FILE="$ZSHRC_D_DIR/optional-aliases.zsh"
FUNCTIONS_FILE="$ZSHRC_D_DIR/functions.zsh"

# -----------------------------
# Logging / helpers
# -----------------------------
info()  { echo -e "${BLUE}$*${NOCOLOR}"; }
ok()    { echo -e "${GREEN}$*${NOCOLOR}"; }
warn()  { echo -e "${YELLOW}$*${NOCOLOR}"; }
err()   { echo -e "${RED}$*${NOCOLOR}"; }

require_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || { err "Missing required command: $c"; return 1; }
}

prompt_yes_no() {
  # usage: prompt_yes_no "Question"  (0=yes, 1=no)
  local q="$1"
  local ans=""
  read -r -p "$q [y/N]: " ans || true
  case "${ans,,}" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_file_exists() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  touch "$f"
}

append_line_once() {
  local line="$1"
  local file="$2"
  ensure_file_exists "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
  fi
}

ensure_sourced_in_zshrc_once() {
  local file_to_source="$1"
  ensure_file_exists "$ZSHRC_FILE"
  append_line_once "source $file_to_source" "$ZSHRC_FILE"
}

ts() { date +%Y%m%d%H%M%S; }

backup_if_exists() {
  local p="$1"
  if [ -e "$p" ]; then
    mv "$p" "$p.bak.$(ts)"
  fi
}

detect_os_family() {
  # echoes: debian | rhel | unknown
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID_LIKE:-} ${ID:-}" in
      *debian*|*ubuntu*|debian|ubuntu|linuxmint|pop) echo "debian"; return 0 ;;
      *rhel*|*fedora*|*centos*|rhel|fedora|centos|rocky|almalinux) echo "rhel"; return 0 ;;
    esac
  fi
  echo "unknown"
}

unique_items() {
  # prints unique lines in order
  awk '!seen[$0]++' <(printf '%s\n' "$@")
}

# -----------------------------
# Install: system packages (tolerant)
# -----------------------------
install_optional_packages_tolerant() {
  local family="$1"; shift
  local -a pkgs=( "$@" )
  local -a missing=()
  local -a installed=()
  local p

  if [ "${#pkgs[@]}" -eq 0 ]; then
    warn "No optional packages configured."
    return 0
  fi

  mapfile -t pkgs < <(unique_items "${pkgs[@]}")

  case "$family" in
    debian)
      if ! command -v apt-get >/dev/null 2>&1; then
        err "apt-get not found; skipping optional packages."
        return 1
      fi
      info "Detected Debian-like OS. Setting up repos and installing optional packages with apt..."
      # Add eza repo
      sudo mkdir -p /etc/apt/keyrings
      wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
      echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
      
      # Add helix PPA (Ubuntu only, for Debian use official repo)
      if command -v add-apt-repository >/dev/null; then
        sudo add-apt-repository -y ppa:maveonair/helix-editor
      fi

      sudo apt-get update -y
      for p in "${pkgs[@]}"; do
        if sudo apt-get install -y "$p"; then
          installed+=( "$p" )
        else
          missing+=( "$p" )
        fi
      done
      ;;
    rhel)
      if ! command -v dnf >/dev/null 2>&1; then
        err "dnf not found; skipping optional packages."
        return 1
      fi
      info "Detected RHEL/Fedora-like OS. Setting up repos and installing optional packages with dnf..."
      # Enable zellij COPR repository
      sudo dnf copr enable -y varlad/zellij || true
      for p in "${pkgs[@]}"; do
        if sudo dnf -y install "$p"; then
          installed+=( "$p" )
        else
          missing+=( "$p" )
        fi
      done
      ;;
    *)
      warn "Unsupported/unknown OS family; skipping optional packages."
      return 0
      ;;
  esac

  if [ "${#installed[@]}" -gt 0 ]; then
    ok "Installed packages: ${installed[*]}"
  fi
  if [ "${#missing[@]}" -gt 0 ]; then
    warn "Unavailable/failed packages: ${missing[*]}"
  else
    ok "All optional packages installed successfully."
  fi
}

# -----------------------------
# Setup: aliases / functions
# -----------------------------
setup_optional_aliases() {
  mkdir -p "$ZSHRC_D_DIR"

  cat > "$ALIASES_FILE" <<'EOF'
# Optional aliases
# Basic list with icons and group directories first
alias ls="eza --icons --group-directories-first"

# Full tree view with icons
alias tree="eza --icons --tree"

# Tree view with specific depth (eza uses --level instead of --depth)
alias treed="eza --icons --tree --level"
alias lsdu='du -a -h --max-depth=1 | sort -hr'
alias du='dust'
alias top='btm'
alias cd='z'
alias grep='rg'

# Helpful global aliases (Zsh)
alias -g -- -h='-h 2>&1 | bat --language=help --style=plain'
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
EOF

  ensure_sourced_in_zshrc_once "$ALIASES_FILE"
  ok "Enabled optional aliases: ${LIGHTRED}$ALIASES_FILE${NOCOLOR}"
}

setup_functions_file() {
  mkdir -p "$ZSHRC_D_DIR"

  if [ ! -f "$FUNCTIONS_FILE" ]; then
    cat > "$FUNCTIONS_FILE" <<'EOF'
# Custom Zsh functions (user-editable)

printcsv() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: printcsv <filename>"
    return 1
  fi

  if [ -f "$1" ]; then
    column -t -s, < "$1"
  else
    echo "Error: File '$1' not found."
    return 1
  fi
}
EOF
  fi

  ensure_sourced_in_zshrc_once "$FUNCTIONS_FILE"
  ok "Enabled functions file: ${LIGHTRED}$FUNCTIONS_FILE${NOCOLOR}"
}

# -----------------------------
# Setup: nvim / vim configs
# -----------------------------
has_nvim() { command -v nvim >/dev/null 2>&1; }

install_astronvim() {
  require_cmd git

  info "Installing AstroNvim template..."
  mkdir -p "$HOME/.config"

  backup_if_exists "$HOME/.config/nvim"
  backup_if_exists "$HOME/.local/share/nvim"
  backup_if_exists "$HOME/.local/state/nvim"
  backup_if_exists "$HOME/.cache/nvim"

  git clone --depth 1 https://github.com/AstroNvim/template "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
  ok "AstroNvim configured at \$HOME/.config/nvim"
}

install_vimrc_amix() {
  require_cmd git

  info "Installing amix/vimrc..."
  backup_if_exists "$HOME/.vim_runtime"
  backup_if_exists "$HOME/.vimrc"

  git clone --depth=1 https://github.com/amix/vimrc.git "$HOME/.vim_runtime"
  sh "$HOME/.vim_runtime/install_awesome_vimrc.sh"
  ok "amix/vimrc installed."
}

# -----------------------------
# Optional installers
# -----------------------------
install_pixi() {
  require_cmd curl
  info "Installing Pixi..."
  curl -fsSL https://pixi.sh/install.sh | sh
  ok "Pixi install finished."
}

install_uv() {
  require_cmd curl
  info "Installing UV..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ok "UV install finished."
}

prompt_setup_optional_shell_features() {
  if prompt_yes_no "Set optional aliases in $ZSHRC_FILE?"; then
    setup_optional_aliases
  else
    info "Skipping optional aliases."
  fi

  if prompt_yes_no "Add optional Zsh functions feature (functions file sourced from $ZSHRC_FILE)?"; then
    setup_functions_file
  else
    info "Skipping optional Zsh functions feature."
  fi
}

# -----------------------------
# Main
# -----------------------------
cd "$HOME"

# 1) oh-my-zsh
require_cmd wget
require_cmd git

info "Installing oh-my-zsh..."
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ok "oh-my-zsh installed successfully. Please change your default shell to ${LIGHTRED}zsh${NOCOLOR}"

# 2) Theme: powerlevel10k
info "Configuring powerlevel10k theme..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC_FILE"
info "For best results, install a Nerd Font: ${LIGHTRED}https://github.com/romkatv/powerlevel10k#fonts${NOCOLOR}"

# 3) Plugins
info "Installing oh-my-zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" || true
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting" || true

sed -i -E 's/^[[:space:]]*plugins=\(([^)]*)\)/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting)/; s/\b(zsh-autosuggestions)\b(\s+\1\b)+/\1/g; s/\b(zsh-syntax-highlighting)\b(\s+\1\b)+/\1/g; s/\b(fast-syntax-highlighting)\b(\s+\1\b)+/\1/g' "$ZSHRC_FILE"
ok "Plugins configured."

# 4) Optional packages + aliases
os_family="$(detect_os_family)"
optional_pkgs_debian=( eza helix ripgrep fd-find bat zoxide btm du-dust git-delta hyperfine jq tmux curl git zellij xh fzf neovim )
optional_pkgs_rhel=( eza helix ripgrep fd-find bat zoxide bottom rust-dust git-delta hyperfine jq tmux curl git zellij xh fzf neovim )

if prompt_yes_no "Is this a new-system install and do you want to install optional packages with the system package manager?"; then
  if [ "$os_family" = "debian" ]; then
    install_optional_packages_tolerant "$os_family" "${optional_pkgs_debian[@]}"
  elif [ "$os_family" = "rhel" ]; then
    install_optional_packages_tolerant "$os_family" "${optional_pkgs_rhel[@]}"
  else
    install_optional_packages_tolerant "$os_family"
  fi

  prompt_setup_optional_shell_features
else
  if prompt_yes_no "Do you want to proceed with Pixi to install additional packages?"; then
    if ! command -v pixi >/dev/null 2>&1; then
      install_pixi
    fi

    if command -v pixi >/dev/null 2>&1; then
      pixi global install zoxide ripgrep fd-find bat eza btm dust delta hyperfine xh sd helix zellij btop

      if prompt_yes_no "Set optional aliases and functions for Pixi-installed packages?"; then
        setup_optional_aliases
        setup_functions_file
      else
        info "Skipping Pixi optional shell features."
      fi
    else
      warn "Pixi is not available; skipping Pixi package installation."
    fi
  else
    info "Skipping optional package installation. Only shell configuration will be adjusted."
  fi
fi

# 5) AstroNvim vs Vim config + optional vim->nvim alias
if prompt_yes_no "Configure AstroNvim (requires Neovim)?"; then
  if has_nvim; then
    install_astronvim
    if prompt_yes_no "Set alias vim=nvim (so vim opens Neovim)?"; then
      append_line_once "alias vim='nvim'" "$ALIASES_FILE"
      ensure_sourced_in_zshrc_once "$ALIASES_FILE"
      ok "Enabled: alias vim='nvim' in ${LIGHTRED}$ALIASES_FILE${NOCOLOR}"
    else
      info "Skipping alias vim=nvim."
    fi
  else
    warn "Neovim not found. Installing Vim config instead."
    install_vimrc_amix
  fi
else
  info "Skipping AstroNvim. Installing Vim config instead."
  install_vimrc_amix
fi

if prompt_yes_no "Install UV (via https://astral.sh/uv/install.sh)?"; then
  install_uv
else
  info "Skipping UV."
fi

ok "Done."