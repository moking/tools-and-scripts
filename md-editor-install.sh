#!/usr/bin/env bash
# Install the dependencies of md-editor.py.
#
# Usage: md-editor-install.sh [--venv [DIR]]
#   (default)  use the system package manager (apt, dnf or pacman); falls back to
#              a virtualenv when none is found or it does not package PySide6
#   --venv     install from PyPI into a virtualenv (default DIR: ~/venv/md-editor)
#
# On Windows, or without bash:  pip install -r md-editor-requirements.txt
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
req="$here/md-editor-requirements.txt"
venv_dir="$HOME/venv/md-editor"
use_venv=0

case "${1:-}" in
    --venv) use_venv=1; [ -n "${2:-}" ] && venv_dir=$2 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    "") ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 1 ;;
esac

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO=sudo

have() { command -v "$1" >/dev/null 2>&1; }

deps_ok() {
    "$1" -c 'import markdown, PySide6.QtWebEngineWidgets' >/dev/null 2>&1
}

install_apt() {
    local pkgs="python3-markdown python3-pygments python3-pyside6.qtcore python3-pyside6.qtgui
        python3-pyside6.qtwidgets python3-pyside6.qtwebenginecore
        python3-pyside6.qtwebenginewidgets python3-pyside6.qtprintsupport"
    local p
    for p in $pkgs; do
        apt-cache show "$p" >/dev/null 2>&1 || { echo "apt: $p not available"; return 1; }
    done
    $SUDO apt-get install -y $pkgs
}

install_dnf() {
    dnf info python3-pyside6 >/dev/null 2>&1 || { echo "dnf: python3-pyside6 not available"; return 1; }
    $SUDO dnf install -y python3-pyside6 python3-markdown python3-pygments
}

install_pacman() {
    $SUDO pacman -S --needed --noconfirm pyside6 qt6-webengine python-markdown python-pygments
}

install_venv() {
    local py
    py=$(command -v python3 || command -v python) || { echo "python3 not found" >&2; exit 1; }
    if ! "$py" -m venv "$venv_dir"; then
        echo "Creating the venv failed. On Debian/Ubuntu install python3-venv first." >&2
        exit 1
    fi
    "$venv_dir/bin/pip" install --upgrade pip
    "$venv_dir/bin/pip" install -r "$req"
    deps_ok "$venv_dir/bin/python" || { echo "Install finished but PySide6/markdown still fail to import" >&2; exit 1; }
    echo
    echo "Done. Run with:"
    echo "  $venv_dir/bin/python $here/md-editor.py [FILE_OR_URL]"
}

if [ $use_venv -eq 0 ]; then
    if have python3 && deps_ok python3; then
        echo "All dependencies are already installed for $(command -v python3)."
        exit 0
    fi
    ok=1
    if have apt-get; then install_apt || ok=0
    elif have dnf; then install_dnf || ok=0
    elif have pacman; then install_pacman || ok=0
    else echo "No supported package manager (apt, dnf, pacman) found."; ok=0
    fi
    if [ $ok -eq 1 ] && deps_ok python3; then
        echo
        echo "Done. Run with:  $here/md-editor.py [FILE_OR_URL]"
        exit 0
    fi
    echo "System packages are not usable; installing into a virtualenv at $venv_dir instead."
fi
install_venv
