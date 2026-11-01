#!/usr/bin/env bash
# Build, sign, install and launch Flamewall.
#
# The filter is a NEFilterDataProvider system extension. Its entitlements are
# "restricted", so AMFI ignores them on an ad-hoc signature unless the
# amfi_get_out_of_my_way=1 boot-arg is set. Run `./run --doctor` to see which
# gates are met. See docs/superpowers/specs for the full story.
set -euo pipefail

# Resolve real script location (works for ./run and scripts/run.sh, including symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  LINK="$(readlink "$SOURCE")"
  if [[ "$LINK" == /* ]]; then
    SOURCE="$LINK"
  else
    SOURCE="$DIR/$LINK"
  fi
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
# Script lives in repo root or in scripts/
if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT="$SCRIPT_DIR"
fi
cd "$ROOT"

DERIVED="${ROOT}/build/DerivedData"
BUILT_APP="${DERIVED}/Build/Products/Debug/Flamewall.app"
INSTALLED_APP="/Applications/Flamewall.app"
EXT_ID="com.flamewall.app.filter"
EXT_REL="Contents/Library/SystemExtensions/FlamewallFilter.systemextension"
HOST_ENT="${ROOT}/Flamewall/Resources/Flamewall.entitlements"
FILTER_ENT="${ROOT}/FlamewallFilter/FlamewallFilter.entitlements"

blue() { printf '\033[34m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

ensure_project() {
  if [[ ! -f "${ROOT}/Flamewall.xcodeproj/project.pbxproj" ]]; then
    python3 "${ROOT}/scripts/generate_xcodeproj.py"
  fi
}

amfi_disabled() {
  nvram boot-args 2>/dev/null | grep -q 'amfi_get_out_of_my_way=1'
}

sip_disabled() {
  csrutil status 2>/dev/null | grep -qi 'disabled'
}

devmode_on() {
  systemextensionsctl developer 2>&1 | grep -qi 'developer mode is on'
}

firewall_off() {
  /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q 'disabled'
}

doctor() {
  blue "Flamewall doctor"
  echo
  echo "Machine gates:"
  if sip_disabled; then pass "SIP disabled"; else fail "SIP is enabled — required for ad-hoc system extensions"; fi
  if amfi_disabled; then
    pass "AMFI out of the way (amfi_get_out_of_my_way=1)"
  else
    fail "AMFI is enforcing — restricted entitlements will be IGNORED on an ad-hoc signature"
    echo "      Fix: sudo nvram boot-args=amfi_get_out_of_my_way=1 && reboot"
    echo "      (Apple Silicon also needs Permissive Security in Startup Security Utility.)"
  fi
  if devmode_on; then
    pass "System extension developer mode on"
  else
    fail "Developer mode off — fix: sudo systemextensionsctl developer on"
  fi
  if firewall_off; then
    pass "Built-in firewall off"
  else
    fail "Built-in firewall is ON — with SIP off this silently starves content filters (FB15879569)"
    echo "      Fix: System Settings → Network → Firewall → off"
  fi

  echo
  echo "Build gates:"
  if [[ -d "$INSTALLED_APP" ]]; then
    pass "Installed at $INSTALLED_APP"
    if codesign -dvv "$INSTALLED_APP" 2>&1 | grep -q 'Sealed Resources=none'; then
      fail "App is linker-signed (no sealed resources) — sysextd will reject it; run ./run"
    else
      pass "App has a real bundle signature"
    fi
    if codesign -d --entitlements - "$INSTALLED_APP" 2>/dev/null | tr -d '\0' | grep -q 'networkextension'; then
      pass "NE entitlements present in signature"
    else
      fail "NE entitlements missing from signature — run ./run"
    fi
  else
    fail "Not installed in /Applications — sysextd only reliably realizes extensions from there; run ./run"
  fi

  echo
  echo "Extension state:"
  if systemextensionsctl list 2>/dev/null | grep -q "$EXT_ID"; then
    systemextensionsctl list 2>/dev/null | grep "$EXT_ID" | sed 's/^/  /'
  else
    echo "  not registered yet — launch Flamewall and use Settings → System → Activate Filter"
  fi
  echo
}

build() {
  blue "Building Flamewall…"
  xcodebuild \
    -scheme Flamewall \
    -project Flamewall.xcodeproj \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    -configuration Debug \
    build
}

# Xcode's linker-signed ad-hoc signature leaves the Info.plist unbound and no
# sealed resources, which sysextd refuses. Re-sign properly, inside out.
resign() {
  local app="$1"
  blue "Re-signing (ad-hoc, with entitlements)…"
  codesign --force --sign - --entitlements "$FILTER_ENT" --timestamp=none \
    "${app}/${EXT_REL}"
  codesign --force --sign - --entitlements "$HOST_ENT" --timestamp=none \
    "$app"
  codesign --verify --deep --strict "$app"
  green "Signature valid."
}

install_app() {
  if [[ ! -d "$BUILT_APP" ]]; then
    red "Build produced no app at: $BUILT_APP"
    exit 1
  fi
  if [[ ! -d "${BUILT_APP}/${EXT_REL}" ]]; then
    red "System extension missing from app bundle at ${EXT_REL}"
    exit 1
  fi

  pkill -x Flamewall 2>/dev/null || true
  sleep 0.3

  blue "Installing to ${INSTALLED_APP}…"
  rm -rf "$INSTALLED_APP"
  cp -R "$BUILT_APP" "$INSTALLED_APP"
  # Sign after the copy: copying can disturb the seals.
  resign "$INSTALLED_APP"
}

launch_app() {
  blue "Launching Flamewall…"
  open "$INSTALLED_APP"
  green "Done. Look for the flame icon in the menu bar."
}

next_steps() {
  cat <<'EOF'

To turn on filtering:

  1. Menu bar flame → Settings → System → Activate Filter
  2. Approve in System Settings → General → Login Items & Extensions
     → Network Extensions
  3. Confirm:  systemextensionsctl list | grep flamewall
     You want [activated enabled].

If activation fails, run ./run --doctor first, then check the real reason:

  log show --last 2m --predicate 'process == "sysextd" OR process == "amfid"' \
    --style compact | grep -v 'xpc:connection'

EOF
}

ensure_project

case "${1:-}" in
  --doctor)
    doctor
    exit 0
    ;;
  --xcode)
    open "${ROOT}/Flamewall.xcodeproj"
    yellow "Opened Xcode. Note: Debug is ad-hoc signed on purpose — no Team needed."
    exit 0
    ;;
  --uninstall)
    blue "Removing system extension…"
    systemextensionsctl uninstall - "$EXT_ID" 2>&1 || \
      yellow "Uninstall failed (it may not be installed)."
    pkill -x Flamewall 2>/dev/null || true
    rm -rf "$INSTALLED_APP"
    green "Removed. To restore AMFI enforcement: sudo nvram -d boot-args && reboot"
    exit 0
    ;;
  --help|-h)
    cat <<'EOF'
Usage: ./run [--doctor|--xcode|--uninstall]

  ./run             Build, sign, install to /Applications, launch
  ./run --doctor    Check every gate and report what is unmet
  ./run --xcode     Open the Xcode project
  ./run --uninstall Remove the system extension and the installed app
EOF
    exit 0
    ;;
esac

if ! amfi_disabled; then
  yellow "AMFI is still enforcing — the filter will not activate."
  yellow "The app will build, install and track usage; run ./run --doctor for the fix."
  echo
fi

build
install_app
launch_app
next_steps
