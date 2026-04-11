#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSL_DIR="$ROOT_DIR/DSL_directory"
VENV_DIR="$ROOT_DIR/.venv"
APT_UPDATED=0

log() {
  printf '[setup] %s\n' "$1"
}

warn() {
  printf '[setup][warn] %s\n' "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[setup][error] Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

has_apt_sudo() {
  command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1
}

apt_update_once() {
  if [[ "$APT_UPDATED" == "0" ]]; then
    log "Running apt-get update"
    sudo apt-get update
    APT_UPDATED=1
  fi
}

apt_install_pkg_if_missing() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    return
  fi

  apt_update_once
  log "Installing system package: $pkg"
  sudo apt-get install -y "$pkg"
}

ensure_system_dependencies() {
  if ! has_apt_sudo; then
    warn "apt-get/sudo unavailable. Skipping system package auto-install."
    warn "Please ensure these are installed manually: python3-venv, python3-pip, ocaml, opam, graphviz, python3-graphviz"
    return
  fi

  apt_install_pkg_if_missing python3-venv
  apt_install_pkg_if_missing python3-pip
  apt_install_pkg_if_missing ocaml
  apt_install_pkg_if_missing opam
  apt_install_pkg_if_missing graphviz
  apt_install_pkg_if_missing python3-graphviz
}

ensure_opam_available() {
  if command -v opam >/dev/null 2>&1; then
    return
  fi

  printf '[setup][error] opam is still not available after system dependency install.\n' >&2
  exit 1
}

ensure_opam_env() {
  if [[ ! -d "$HOME/.opam" ]]; then
    log "Initializing opam"
    opam init -y --disable-sandboxing
  fi

  if ! opam switch list --short | grep -q .; then
    log "Creating default opam switch"
    opam switch create default -y
  fi

  if opam switch list --short | grep -qx default; then
    opam switch set default
  else
    first_switch="$(opam switch list --short | head -n 1)"
    opam switch set "$first_switch"
  fi

  # Load opam environment in this shell so opam-installed tools are visible.
  eval "$(opam env --shell=bash)"
}

ensure_dune_available() {
  if command -v dune >/dev/null 2>&1; then
    return
  fi

  log "dune not found; installing dune through opam"
  opam install -y dune

  if ! command -v dune >/dev/null 2>&1; then
    # Re-evaluate env in case opam updated paths during install.
    eval "$(opam env --shell=bash)"
  fi

  if ! command -v dune >/dev/null 2>&1; then
    printf '[setup][error] dune installation failed.\n' >&2
    exit 1
  fi
}

ensure_pip_available() {
  if python3 -m pip --version >/dev/null 2>&1; then
    return
  fi

  log "python3 pip module not found; attempting bootstrap with ensurepip"
  if python3 -m ensurepip --upgrade >/dev/null 2>&1; then
    if python3 -m pip --version >/dev/null 2>&1; then
      return
    fi
  fi

  if has_apt_sudo; then
    log "Installing python3-pip via apt-get"
    apt_update_once
    sudo apt-get install -y python3-pip
  else
    printf '[setup][error] pip is missing and auto-install requires apt-get + sudo.\n' >&2
    printf '[setup][error] Please install python3-pip manually, then rerun setup.sh.\n' >&2
    exit 1
  fi

  if ! python3 -m pip --version >/dev/null 2>&1; then
    printf '[setup][error] python3-pip installation failed.\n' >&2
    exit 1
  fi
}

ensure_venv_ready() {
  if [[ ! -d "$VENV_DIR" ]]; then
    log "Creating project virtual environment at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
  fi

  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    printf '[setup][error] virtualenv python not found at %s/bin/python\n' "$VENV_DIR" >&2
    exit 1
  fi

  log "Upgrading pip in project virtual environment"
  "$VENV_DIR/bin/python" -m pip install --upgrade pip
}

log "Starting AutomataGen bootstrap"

require_cmd python3

if [[ ! -f "$ROOT_DIR/requirements.txt" ]]; then
  printf '[setup][error] requirements.txt not found in %s\n' "$ROOT_DIR" >&2
  exit 1
fi

if [[ ! -d "$DSL_DIR" ]]; then
  printf '[setup][error] DSL_directory not found in %s\n' "$ROOT_DIR" >&2
  exit 1
fi

ensure_system_dependencies
ensure_opam_available
ensure_opam_env
ensure_dune_available
ensure_pip_available
ensure_venv_ready

log "Installing Python dependencies from requirements.txt into virtual environment"
"$VENV_DIR/bin/python" -m pip install -r "$ROOT_DIR/requirements.txt"

log "Ensuring Python graphviz package for runtime (system python)"
if python3 -c "import graphviz" >/dev/null 2>&1; then
  log "python3 graphviz module already available"
elif has_apt_sudo; then
  apt_install_pkg_if_missing python3-graphviz
else
  warn "python3 graphviz module missing and apt-get unavailable; visualize() may fail"
fi

log "Installing OCaml dependencies from opam metadata (if needed)"
if ! (cd "$DSL_DIR" && opam install . --deps-only -y); then
  warn "opam dependency installation failed or was skipped by your environment; continuing with dune build"
fi

log "Building DSL executable"
(cd "$DSL_DIR" && dune build bin/main.exe)

log "Setup complete"
log "Run sample: cd DSL_directory && dune exec dsl_directory -- source-code/all_features.agen"
log "Run Python tests with virtualenv: $VENV_DIR/bin/pytest -q python/test_automata.py"
