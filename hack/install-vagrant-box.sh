#!/usr/bin/env bash

[[ -z "$TRACE" ]] || set -x

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -e

BOX_NAME="coreos-alpha"
BOX_CHANNEL="${BOX_NAME##*-}"
COREOS_BASE_URL="https://$BOX_CHANNEL.release.core-os.net/amd64-usr/current"

DISK_SIZE="100G"

BOX_URL="$COREOS_BASE_URL/coreos_production_vagrant_vmware_fusion.box"
BOX_JSON="$COREOS_BASE_URL/coreos_production_vagrant_vmware_fusion.json"
VMDK_URL="$COREOS_BASE_URL/coreos_production_vmware_image.vmdk.bz2"
VERSION_URL="$COREOS_BASE_URL/version.txt"
VDISKMANAGER="/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager"

BUILD_PATH="$(mktemp -d -u)"

_ensure_temp() {
    mkdir -p "$1"
    trap "rm -r $1" EXIT
}

_download_box() {
    _ensure_temp "$1"
    curl -L "$BOX_URL" | tar xvzC "$1"
}

_download_vmdk() {
    _ensure_temp "$1"
    curl -L "$VMDK_URL" | bzcat > "$1/$(ls -A $1 | grep '.vmdk$')"
}

_resize_disk() {
    _ensure_temp "$1"
    "$VDISKMANAGER" -x "$DISK_SIZE" "$1/$(ls -A $1 | grep '.vmdk$')"
}

_compress_box() {
    _ensure_temp "$1"
    [[ -f "$1/Vagrantfile" ]] || panic "Vagrantfile in $1 not found"
    tar -z -c -C "$1" $(ls -A $1) > "build/$BOX_NAME.box"
}

_get_version_param() {
  export "$1=$(curl -sL "$VERSION_URL" | grep "^$1=" | cut -f2 -d=)"
}

_create_box_json() {
    _get_version_param COREOS_VERSION
    sed -e 's|^    ||' >"build/$BOX_NAME.json" <<EOJSOM 
    {
      "name": "$BOX_NAME",
      "description": "CoreOS $BOX_CHANNEL",
      "versions": [{
        "version": "$COREOS_VERSION",
        "providers": [{
          "name": "vmware_fusion",
          "url": "build/$BOX_NAME.box",
          "checksum_type": "sha256",
          "checksum": "$(shasum -p -a 256 "build/$BOX_NAME.box" | awk '{print $1}')"
        }]
      }]
    }
EOJSOM
}

_add_box() {
    vagrant box list | grep -q "^$BOX_NAME" \
    || vagrant box add "build/$BOX_NAME.json"
    vagrant box outdated \
    || vagrant box add "build/$BOX_NAME.json"
}

_ensure_build

vagrant box list | grep -q "^$BOX_NAME" || (
  [[ -f "build/$BOX_NAME.box" ]] || (
    _download_box "$BUILD_PATH"
    _download_vmdk "$BUILD_PATH"
    _resize_disk "$BUILD_PATH"
    _compress_box "$BUILD_PATH"
  )

  [[ -f "build/$BOX_NAME.json" ]] || _create_box_json "$BUILD_PATH"
  _add_box "$BUILD_PATH"
  )
