#!/usr/bin/env bash
#
# generate manifests with the official tectonic-installer
#

[[ -z "$TRACE" ]] || set -x

set -e

TECTONIC_VERSION="1.8.9-tectonic.1"
TECTONIC_INSTALLER_ZIP="${1:-https://releases.tectonic.com/releases/tectonic_$TECTONIC_VERSION.zip}"
TECTONIC_ADMIN_EMAIL="admin@example.com"
TECTONIC_ADMIN_PASSWORD="sandbox"
TECTONIC_MANIFEST_ARCHIVE="tectonic-$TECTONIC_VERSION-manifests.tar.gz"

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

_prepare_installer() {
    _ensure_temp "$1"
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
  cp license.txt pull.json "$1"
}

_set_tfvars() {
    _ensure_temp "$1"
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
    _ensure_temp "$1"
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
    _ensure_temp "$1"
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


[[ -f license.txt ]] || panic "Provide own license.txt or download tectonic-sandbox"
[[ -f pull.json ]] || panic "Provide own pull.json or download tectonic-sandbox"

[[ -f "$TECTONIC_MANIFEST_ARCHIVE" ]] || (
  _prepare_installer "$WORKDIR"
  _provide_license "$WORKDIR"
  _set_tfvars "$WORKDIR"
  _disable_matchbox "$WORKDIR"
  _generate_manifests "$WORKDIR"
  _save_manifests "$WORKDIR"
)