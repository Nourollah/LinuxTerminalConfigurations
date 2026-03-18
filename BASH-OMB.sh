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

info() { echo -e "${BLUE}$*${NOCOLOR}"; }
ok()   { echo -e "${GREEN}$*${NOCOLOR}"; }
warn() { echo -e "${YELLOW}$*${NOCOLOR}"; }
err()  { echo -e "${RED}$*${NOCOLOR}"; }

# -----------------------------
# Paths (Bash)
# -----------------------------
BASHRC_FILE="$HOME/.bashrc"
BASHRC_D_DIR="$HOME/.bashrc.d"
ALIASES_FILE="$BASHRC_D_DIR/optional-aliases.sh"
FUNCTIONS_FILE="$BASHRC_D_DIR/functions.sh"
BASHRC_D_LOADER="$BASHRC_D_DIR/00-load-bashrc-d.sh"

# -----------------------------
# Helpers
# -----------------------------
require_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || { err "Missing required command: $c"; return 1; }
}

prompt_yes_no() {
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
    case "${ID:-} ${ID_LIKE:-}" in
      *debian*|*ubuntu*|debian|ubuntu|linuxmint|pop) echo "debian"; return 0 ;;
      *rhel*|*fedora*|*centos*|rhel|fedora|centos|rocky|almalinux) echo "rhel"; return 0 ;;
    esac
  fi
  echo "unknown"
}

unique_items() {
  awk '!seen[$0]++' <(printf '%s\n' "$@")
}

ensure_bashrc_d_loader() {
  mkdir -p "$BASHRC_D_DIR"
  ensure_file_exists "$BASHRC_D_LOADER"

  cat > "$BASHRC_D_LOADER" <<'EOF'
# Load ~/.bashrc.d/*.sh (managed)
if [ -d "$HOME/.bashrc.d" ]; then
  for f in "$HOME/.bashrc.d"/*.sh; do
    [ -r "$f" ] && . "$f"
  done
fi
EOF

  ensure_file_exists "$BASHRC_FILE"
  # Remove previously written absolute loader path so HOME stays portable across servers.
  sed -i -E '/^[[:space:]]*\.[[:space:]]+"\/[^"]+\/\.bashrc\.d\/00-load-bashrc-d\.sh"[[:space:]]*$/d' "$BASHRC_FILE"
  append_line_once "" "$BASHRC_FILE"
  append_line_once "# Load bashrc snippets" "$BASHRC_FILE"
  append_line_once '. "$HOME/.bashrc.d/00-load-bashrc-d.sh"' "$BASHRC_FILE"
}

set_omb_theme_powerline() {
  ensure_file_exists "$BASHRC_FILE"

  if grep -Eq '^[[:space:]]*OSH_THEME=' "$BASHRC_FILE"; then
    sed -i 's/^[[:space:]]*OSH_THEME=.*/OSH_THEME="powerline"/' "$BASHRC_FILE"
  else
    printf '\nOSH_THEME="powerline"\n' >> "$BASHRC_FILE"
  fi
}

# -----------------------------
# Packages (tolerant)
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
      info "Detected Debian-like OS. Installing optional packages with apt..."
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
      info "Detected RHEL/Fedora-like OS. Installing optional packages with dnf..."
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
# Bash snippets: aliases / functions
# -----------------------------
setup_optional_aliases() {
  mkdir -p "$BASHRC_D_DIR"

  cat > "$ALIASES_FILE" <<'EOF'
# Optional aliases (managed)
alias ls='lsd'
alias tree='lsd --tree'
alias treed='lsd --tree --depth'
alias lsdu='du -a -h --max-depth=1 | sort -hr'
alias du='ncdu'
alias grep='rg'

# Help output via bat when available (Bash-safe)
if command -v bat >/dev/null 2>&1; then
  alias helpbat='2>&1 | bat --language=help --style=plain'
fi
EOF

  ensure_bashrc_d_loader
  ok "Enabled optional aliases: $ALIASES_FILE"
}

setup_functions_file() {
  mkdir -p "$BASHRC_D_DIR"

  if [ ! -f "$FUNCTIONS_FILE" ]; then
    cat > "$FUNCTIONS_FILE" <<'EOF'
# Custom Bash functions (user-editable)

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

  ensure_bashrc_d_loader
  ok "Enabled functions file: $FUNCTIONS_FILE"
}

append_alias_vim_nvim() {
  mkdir -p "$BASHRC_D_DIR"
  append_line_once "alias vim='nvim'" "$ALIASES_FILE"
  ensure_bashrc_d_loader
  ok "Enabled: alias vim='nvim' in $ALIASES_FILE"
}

# -----------------------------
# Neovim / Vim configs
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
install_oh_my_bash() {
  require_cmd curl

  info "Installing oh-my-bash..."
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" || true
  ok "oh-my-bash install finished."

  # Ensure login shells load ~/.bashrc (so OSH_THEME in ~/.bashrc takes effect)
  if [ -f "$HOME/.bash_profile" ] && ! grep -qE '(^|\s)\. ~/.bashrc(\s|$)|(^|\s)source ~/.bashrc(\s|$)' "$HOME/.bash_profile"; then
    printf '\n# Load ~/.bashrc\n[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' >> "$HOME/.bash_profile"
  fi
}

install_pixi() {
  require_cmd curl
  info "Installing Pixi..."
  curl -fsSL https://pixi.sh/install.sh | bash
  ok "Pixi install finished."
}

install_uv() {
  require_cmd curl
  info "Installing UV..."
  curl -LsSf https://astral.sh/uv/install.sh | bash
  ok "UV install finished."
}

# -----------------------------
# Main
# -----------------------------
cd "$HOME"

install_oh_my_bash
set_omb_theme_powerline
ensure_bashrc_d_loader
ok "Configured oh-my-bash theme: OSH_THEME=\"powerline\" in $BASHRC_FILE"

os_family="$(detect_os_family)"
optional_pkgs_debian=( fzf ripgrep fd-find jq bat tmux btop lsd ncdu neovim curl git )
optional_pkgs_rhel=( fzf ripgrep fd-find jq bat tmux btop lsd ncdu neovim curl git )

if prompt_yes_no "Install optional packages for detected OS (${os_family})?"; then
  if [ "$os_family" = "debian" ]; then
    install_optional_packages_tolerant "$os_family" "${optional_pkgs_debian[@]}"
  elif [ "$os_family" = "rhel" ]; then
    install_optional_packages_tolerant "$os_family" "${optional_pkgs_rhel[@]}"
  else
    install_optional_packages_tolerant "$os_family"
  fi
else
  info "Skipping optional packages."
fi

if prompt_yes_no "Set optional aliases in $BASHRC_FILE?"; then
  setup_optional_aliases
else
  info "Skipping optional aliases."
fi

if prompt_yes_no "Configure AstroNvim (requires Neovim)?"; then
  if has_nvim; then
    install_astronvim
    if prompt_yes_no "Set alias vim=nvim (so vim opens Neovim)?"; then
      append_alias_vim_nvim
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

if prompt_yes_no "Add optional Bash functions feature (functions file loaded from $BASHRC_FILE)?"; then
  setup_functions_file
else
  info "Skipping Bash functions feature."
fi

if prompt_yes_no "Install Pixi (via https://pixi.sh/install.sh)?"; then
  install_pixi
else
  info "Skipping Pixi."
fi

if prompt_yes_no "Install UV (via https://astral.sh/uv/install.sh)?"; then
  install_uv
else
  info "Skipping UV."
fi

ok "Done. Restart your shell or run: source $BASHRC_FILE"