#!/usr/bin/env bash

# Smoke test for gz302 LLM virtualenv
# Usage: ./tests/smoke_llm_venv.sh [path-to-venv]
# If no path provided, defaults to /home/$SUDO_USER/.gz302-llm-venv or $HOME/.gz302-llm-venv

set -euo pipefail

venv_path="${1:-}"
if [[ -z "$venv_path" ]]; then
  if [[ -n "${SUDO_USER:-}" ]]; then
    venv_path="/home/$SUDO_USER/.gz302-llm-venv"
  else
    venv_path="$HOME/.gz302-llm-venv"
  fi
fi

echo "[INFO] Using virtualenv path: $venv_path"

if [[ ! -d "$venv_path" ]]; then
  echo "[ERROR] Virtualenv not found at $venv_path"
  echo "[HINT] Run gz302-llm.sh for your distro to create the venv, or pass the venv path as the first argument."
  exit 2
fi

python_bin="$venv_path/bin/python"
pip_bin="$venv_path/bin/pip"

if [[ ! -x "$python_bin" ]]; then
  echo "[ERROR] Python binary not found or not executable: $python_bin"
  exit 3
fi

echo "[INFO] Python interpreter: $($python_bin -c 'import sys; print(sys.executable)')"
echo "[INFO] Python version: $($python_bin -c 'import sys; print(sys.version.split()[0])')"

echo "[INFO] Checking pip packages (top-level)..."
"$pip_bin" list --format=columns | sed -n '1,20p' || true

echo "[INFO] Attempting to import torch inside the virtualenv..."
if "$python_bin" -c 'import importlib,sys; importlib.import_module("torch"); print("torch OK: ", __import__("torch").__version__)'; then
  echo "[SUCCESS] torch imported successfully inside venv"
  exit 0
else
  echo "[WARNING] torch import failed inside venv"
  echo "[HINT] Torch may not be installed or may be incompatible with this environment."
  exit 5
fi
