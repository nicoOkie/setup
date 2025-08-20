#!/usr/bin/env bash
set -euo pipefail

# --- Logging helpers ---
info()  { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# --- Init phase ---
init() {
  if [[ -z "${GITHUB_USERNAME:-}" ]]; then
    error "GITHUB_USERNAME is not set! Run: export GITHUB_USERNAME=yourname"
    exit 1
  fi

  info "Updating system..."
  sudo apt-get update -y && sudo apt-get upgrade -y

  # Fish
  if ! command -v fish &>/dev/null; then
    info "Installing Fish..."
    sudo apt-get install -y fish curl unzip wget gsettings-desktop-schemas
  else
    info "Fish already installed."
  fi

  local fish_path
  fish_path="$(command -v fish)"

  if ! grep -Fxq "$fish_path" /etc/shells; then
    info "Adding $fish_path to /etc/shells"
    echo "$fish_path" | sudo tee -a /etc/shells
  fi

  if [[ "$SHELL" != "$fish_path" ]]; then
    info "Changing default shell to Fish for $USER"
    chsh -s "$fish_path" "$USER"
  else
    info "Fish is already the default shell."
  fi

  # Starship
  if ! command -v starship &>/dev/null; then
    info "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  else
    info "Starship already installed."
  fi

  # Chezmoi
  if [[ ! -d "$HOME/.local/share/chezmoi" ]]; then
    info "Installing chezmoi and applying dotfiles..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$GITHUB_USERNAME"
  else
    info "Chezmoi already initialized, applying updates..."
    chezmoi apply
  fi

  info "✅ Init phase complete."
}

# --- Personalize phase ---
personalize() {
  local font_dir="$HOME/.local/share/fonts"
  local font_file="$font_dir/Fira Code Regular Nerd Font Complete.ttf"

  # Fonts
  if [[ ! -f "$font_file" ]]; then
    info "Installing FiraCode Nerd Font..."
    mkdir -p "$font_dir"
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -O /tmp/FiraCode.zip
    unzip -o /tmp/FiraCode.zip -d "$font_dir"
    fc-cache -fv "$font_dir"
  else
    info "FiraCode Nerd Font already installed."
  fi

  # Gnome Terminal
  local desired_font="FiraCode Nerd Font Mono 12"
  local profile
  profile="$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")"
  local profile_path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/"
  local current_font
  current_font="$(gsettings get "$profile_path" font | tr -d "'")"

  if [[ "$current_font" != "$desired_font" ]]; then
    info "Setting Gnome Terminal font to '$desired_font'"
    gsettings set "$profile_path" font "$desired_font"
  else
    info "Gnome Terminal already using '$desired_font'"
  fi

  info "🎨 Personalization complete!"
}

# --- Main run ---
init
personalize

info "🚀 Bootstrap finished. Log out and log back in to enjoy Fish + Starship!"
