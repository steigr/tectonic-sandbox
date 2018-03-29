#!/usr/bin/env bash
#
# generate manifests with the official tectonic-installer
#

[[ -z "$TRACE" ]] || set -x

set -e

TECTONIC_SANDBOX_ZIP="$1"
WORKDIR="$(mktemp -d -u)"

panic() {
    echo "${@}"
    exit 1
}

_ensure_temp() {
    if [[ -d "$1" ]]; then
        return
    else
        mkdir -p "$1"
        trap "rm -r $1" EXIT
    fi
}

_extract_license() {
    _ensure_temp "$1"
    [[ -f "$TECTONIC_SANDBOX_ZIP" ]] \
    && cp "$TECTONIC_SANDBOX_ZIP" "$1/sandbox.zip" \
    || curl -L -o "$1/sandbox.zip" "$TECTONIC_SANDBOX_ZIP"
    ( cd "$1"
      unzip sandbox.zip
      jq -r '.data.license' "$(find tectonic-sandbox-* -name license.json -type f | grep "provisioning" | grep "tectonic/secrets" | head -1)" | base64 -D > license.txt
      jq -r '.data.".dockerconfigjson"' "$(find tectonic-sandbox-* -name pull.json -type f | grep "provisioning" | grep "tectonic/secrets" | head -1)" | base64 -D > pull.json
      )
    cp "$1/license.txt" "$1/pull.json" .
}

[[ -f "license.txt" ]] || NEED_DATA=1
[[ -f "pull.json"   ]] || NEED_DATA=1

[[ -z "$NEED_DATA" ]] || _extract_license "$WORKDIR"