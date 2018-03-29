#!/usr/bin/env bash
#
# generate manifests with the official tectonic-installer
#

[[ -z "$TRACE" ]] || set -x

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -e

TECTONIC_SANDBOX_ZIP="$1"
WORKDIR="$(mktemp -d -u)"

_extract_license() {
    _ensure_temp "$1"
    [[ "$TECTONIC_SANDBOX_ZIP" ]] || panic "Give URL or path to tectonc-sandbox zip-file as first argument. Check out https://coreos.com/tectonic/sandbox/ for more information."
    [[ -f "$TECTONIC_SANDBOX_ZIP" ]] \
    && cp "$TECTONIC_SANDBOX_ZIP" "$1/sandbox.zip" \
    || curl -L -o "$1/sandbox.zip" "$TECTONIC_SANDBOX_ZIP"
    ( cd "$1"
      unzip sandbox.zip
      jq -r '.data.license' "$(find tectonic-sandbox-* -name license.json -type f | grep "provisioning" | grep "tectonic/secrets" | head -1)" | base64 -D > license.txt
      jq -r '.data.".dockerconfigjson"' "$(find tectonic-sandbox-* -name pull.json -type f | grep "provisioning" | grep "tectonic/secrets" | head -1)" | base64 -D > pull.json
      )
    cp "$1/license.txt" "$1/pull.json" build/
}

_ensure_build

[[ -f "license.txt" ]] || NEED_DATA=1
[[ -f "pull.json"   ]] || NEED_DATA=1

[[ -z "$NEED_DATA" ]] || _extract_license "$WORKDIR"