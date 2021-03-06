#!/usr/bin/env bash
#
# generate manifests with the official tectonic-installer
#

[[ -z "$TRACE" ]] || set -x

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -e

TECTONIC_VERSION="1.8.9-tectonic.1"
TECTONIC_INSTALLER_ZIP="${1:-https://releases.tectonic.com/releases/tectonic_$TECTONIC_VERSION.zip}"
TECTONIC_ADMIN_EMAIL="${TECTONIC_ADMIN_EMAIL:-$(whoami)@$(hostname -f)}"
TECTONIC_ADMIN_PASSWORD="${TECTONIC_ADMIN_PASSWORD:-sandbox}"
TECTONIC_MANIFEST_ARCHIVE="build/tectonic-$TECTONIC_VERSION-manifests.tar.gz"
TECTONIC_LICENSE=build/license.txt
TECTONIC_PULLSECRET=build/pull.json
WORKDIR="$(mktemp -d -u)"

_prepare_installer() {
    [[ -f "$TECTONIC_INSTALLER_ZIP" ]] \
    && cp "$TECTONIC_INSTALLER_ZIP" "$1/installer.zip" \
    || curl -L -o "$1/installer.zip" "$TECTONIC_INSTALLER_ZIP"
    ( cd "$1"
      unzip installer.zip
      mv "tectonic_$TECTONIC_VERSION"/* .
      rm -r "tectonic_$TECTONIC_VERSION" installer.zip
    )
}

_provide_license() {
  _ensure_temp "$1"
  cp "$TECTONIC_LICENSE" "$TECTONIC_PULLSECRET" "$1"
}

_set_tfvars() {
    ( cd "$1"; \
      export INSTALLER_PATH="$PWD/tectonic-installer/darwin/installer" PATH="$PWD/tectonic-installer/darwin:$PATH"
      terraform init
      sed -e 's|^        ||' >terraform.tfvars <<EOF 
        tectonic_base_domain = "sandbox"
        tectonic_cluster_name = "sandbox"
        tectonic_container_linux_channel = "alpha"
        tectonic_container_linux_version = "latest"
        tectonic_etcd_count = "0"
        tectonic_license_path = "license.txt"
        tectonic_master_count = "1"
        tectonic_metal_controller_domain = "kubernetes.sandbox"
        tectonic_metal_controller_domains = ["kubernetes.sandbox"]
        tectonic_metal_controller_macs = ["00:00:00:00:00:00"]
        tectonic_metal_controller_names = ["kubernetes"]
        tectonic_metal_ingress_domain = "tectonic.sandbox"
        tectonic_metal_worker_domains = ["kubernetes.sandbox"]
        tectonic_metal_worker_macs = ["00:00:00:00:00:00"]
        tectonic_metal_worker_names = ["kubernetes"]
        tectonic_pull_secret_path = "pull.json"
        // managed by vagrant
        tectonic_ssh_authorized_key = "bWFuYWdlZC1ieS12YWdyYW50Cg=="
        tectonic_tls_validity_period = "26280"
        tectonic_vanilla_k8s = false
        tectonic_worker_count = "1"
        tectonic_admin_email="$TECTONIC_ADMIN_EMAIL"
        tectonic_admin_password="$TECTONIC_ADMIN_PASSWORD"
EOF
    )
}

_disable_matchbox() {
    ( cd "$1"
      echo > platforms/metal/provider.tf
      sed '/^variable "tectonic_metal_matchbox/,/^}$/d' platforms/metal/variables.tf > platforms/metal/variables.tf.tmp \
      && mv platforms/metal/variables.tf.tmp platforms/metal/variables.tf
      sed '/^resource "matchbox_/,/^}$/d' platforms/metal/matchers.tf > platforms/metal/matchers.tf.tmp \
      && mv platforms/metal/matchers.tf.tmp platforms/metal/matchers.tf
      sed '/^resource "matchbox_/,/^}$/d' platforms/metal/profiles.tf > platforms/metal/profiles.tf.tmp \
      && mv platforms/metal/profiles.tf.tmp platforms/metal/profiles.tf
      sed -e 's|timeout\s*.*|timeout = "1s"|' platforms/metal/remote.tf > platforms/metal/remote.tf.tmp \
      && mv platforms/metal/remote.tf.tmp platforms/metal/remote.tf
      )
}

_generate_manifests() {
    ( cd "$1"
      touch license.txt
      touch pull.json
      tectonic-installer/darwin/terraform init platforms/metal
      tectonic-installer/darwin/terraform get platforms/metal
      tectonic-installer/darwin/terraform plan platforms/metal
      tectonic-installer/darwin/terraform apply -auto-approve=true platforms/metal 3>&2 2>&1 1>&3 \
      | grep -q 'dial tcp'
    )
}

_save_manifests() {
  _ensure_temp "$1"
  tar -z -c -C "$1/generated" . > "$TECTONIC_MANIFEST_ARCHIVE"
}

_ensure_build

[[ -f "$TECTONIC_LICENSE" ]] || panic "Provide own $TECTONIC_LICENSE or download tectonic-sandbox"
[[ -f "$TECTONIC_PULLSECRET" ]] || panic "Provide own $TECTONIC_PULLSECRET or download tectonic-sandbox"

[[ -f "$TECTONIC_MANIFEST_ARCHIVE" ]] || (
  _ensure_temp "$WORKDIR"
  _prepare_installer "$WORKDIR"
  _provide_license "$WORKDIR"
  _set_tfvars "$WORKDIR"
  _disable_matchbox "$WORKDIR"
  _generate_manifests "$WORKDIR"
  _save_manifests "$WORKDIR"
)
