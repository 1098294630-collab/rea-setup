#!/usr/bin/env sh
# Install REA (rea-agents) on macOS or Linux.
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/rea-setup/main/install.sh | sh
set -eu

say()  { printf '\033[36m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }

node_ok() {
  v=$(node -v 2>/dev/null) || return 1
  v=${v#v}
  major=${v%%.*}
  rest=${v#*.}
  minor=${rest%%.*}
  patch=${rest#*.}
  patch=${patch%%-*}
  case "$major" in
    22) [ "$minor" -gt 23 ] || { [ "$minor" -eq 23 ] && [ "$patch" -ge 4 ]; } ;;
    24) [ "$minor" -gt 22 ] || { [ "$minor" -eq 22 ] && [ "$patch" -ge 1 ]; } ;;
    26) [ "$minor" -gt 12 ] || { [ "$minor" -eq 12 ] && [ "$patch" -ge 1 ]; } ;;
    *)  [ "$major" -gt 26 ] ;;
  esac
}

say "Checking Node.js"
if command -v node >/dev/null 2>&1 && node_ok; then
  note "found $(node -v), supported"
else
  note "missing or older than 22.23.4 / 24.22.1 / 26.12.1"
  say "Installing Node.js 24 with fnm"
  curl -fsSL https://fnm.vercel.app/install | bash
  FNM_DIR="${FNM_DIR:-$HOME/.local/share/fnm}"
  export PATH="$FNM_DIR:$PATH"
  # shellcheck disable=SC1090
  eval "$(fnm env 2>/dev/null)" || true
  fnm install 24
  fnm use 24
  fnm default 24
  note "installed $(node -v)"
  note "open a new terminal if 'node -v' still shows an old version"
fi

say "Installing rea-agents"
if [ "$(id -u)" -eq 0 ]; then
  npm install --global rea-agents@latest --no-audit --no-fund
else
  npm install --global rea-agents@latest --no-audit --no-fund 2>/dev/null || {
    note "global install needs a writable npm prefix; retrying with a user-local prefix"
    NPM_PREFIX="$HOME/.local"
    mkdir -p "$NPM_PREFIX"
    npm install --global --prefix "$NPM_PREFIX" rea-agents@latest --no-audit --no-fund
    note "add this to your shell profile: export PATH=\"$NPM_PREFIX/bin:\$PATH\""
    export PATH="$NPM_PREFIX/bin:$PATH"
  }
fi

say "Version"
rea --version

say "Configuring your coding agent"
note "Pick the client(s) you use, confirm the plan, then restart the client."
rea setup

printf '\n'
printf 'CLI   : %s\n' "$(command -v rea)"
printf 'Skill : %s\n' "$HOME/.agents/skills/reverse-engineer-anything"
printf 'Docs  : %s\n' "https://morluto.github.io/rea/zh-CN/get-started/"
