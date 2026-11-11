#!/usr/bin/env bash
# NOX server installer for Linux x64.
#   curl -fsSL https://noxft.it/install-server.sh | bash
# Checks that this is Linux on x64, downloads the official package from the NOX GitHub release,
# and installs it in ~/nox-server (or $NOX_SERVER_DIR). An existing appsettings.json and the
# data/ folder are kept. Nothing runs as root and the server is not started automatically.
set -euo pipefail

# temporary folder, removed on exit (global: the exit trap runs after main has returned)
NOX_TMP=""
trap '[ -n "$NOX_TMP" ] && rm -rf "$NOX_TMP"' EXIT

main() {
  local url="https://github.com/gabrielechi/Nox/releases/download/v.3.4/NOX-Server-linux-x64.zip"
  local dir="${NOX_SERVER_DIR:-$HOME/nox-server}"

  fail() { printf '\nNOX: %s\n' "$1" >&2; exit 1; }

  # 1. operating system and architecture
  local os arch bits
  os="$(uname -s)"
  [ "$os" = "Linux" ] || fail "this installer is for Linux (this system: $os). On Windows use: powershell -c \"irm https://noxft.it/install-server.ps1 | iex\""
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) ;;
    *) fail "the NOX server is built for x64 (x86_64); this machine is $arch, so it cannot run it." ;;
  esac
  bits="$(getconf LONG_BIT 2>/dev/null || echo 64)"
  [ "$bits" = "64" ] || fail "a 64-bit Linux system is required (this one is $bits-bit)."

  # 2. tools
  local tool
  for tool in curl unzip; do
    command -v "$tool" >/dev/null 2>&1 || fail "'$tool' is missing. Install it (for example: sudo apt install $tool) and run the command again."
  done

  # 3. download and unpack in a temporary folder
  NOX_TMP="$(mktemp -d)"
  local tmp="$NOX_TMP"
  printf 'Downloading the NOX server for Linux x64...\n'
  curl -fL --progress-bar -o "$tmp/server.zip" "$url" || fail "download failed: $url"
  unzip -q "$tmp/server.zip" -d "$tmp/package" || fail "the downloaded package could not be unpacked."
  local src="$tmp/package/NOX-Server-linux-x64"
  [ -f "$src/Server" ] || fail "unexpected package contents (Server not found)."

  # 4. install, keeping an existing configuration and data
  mkdir -p "$dir"
  if [ -f "$dir/appsettings.json" ]; then
    cp "$src/appsettings.json" "$dir/appsettings.json.new"
    printf 'Your appsettings.json was kept; the new default is in appsettings.json.new\n'
  else
    cp "$src/appsettings.json" "$dir/appsettings.json"
  fi
  cp "$src/Server" "$dir/Server.new" || fail "could not write to $dir"
  mv -f "$dir/Server.new" "$dir/Server" || fail "could not replace $dir/Server: stop the running server and try again."
  chmod +x "$dir/Server"
  cp "$src/README.txt" "$dir/README.txt"

  printf '\nNOX server installed in %s\n\n' "$dir"
  printf 'Start it:          cd "%s" && ./Server\n' "$dir"
  printf 'Settings:          %s/appsettings.json (port, address, HTTPS)\n' "$dir"
  printf 'Data and backups:  %s/data (created on first start)\n\n' "$dir"
  printf 'Over plain HTTP passwords travel unencrypted: set up HTTPS before using it outside your own network.\n'
}

main "$@"
