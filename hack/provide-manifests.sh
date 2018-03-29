#!/usr/bin/env bash
#
# generate manifests with the official tectonic-installer
#

set -e

TECTONIC_MANIFEST_ARCHIVE="${1:-$(ls tectonic-*-manifests.tar.gz)}"
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

_prepare_workdir() {
    _ensure_temp "$1"
    tar -x -f "$TECTONIC_MANIFEST_ARCHIVE" -C "$1"
}

# to make k8s available on port :443
# ssl-passthrough is enabled
# and an ingress rule is added for kubernetes
_patch_tectonic_ingress() {
    _ensure_temp "$1"
    ( cd "$1"
      
      # move k8s api to port 445
      for manifest in $(find $(find $(find . -name '*manifest' -type d) -name '*apiserver.yaml' -type f); do 
          sed -e 's|secure-port=443|secure-port=445|g' "$manifest" > "$manifest".tmp \
          && mv "$manifest".tmp "$manifest"
      done

      INGRESS_HOSTPORT_MANIFEST="$(find $(find $(find . -name ingress -type d) -name hostport -type d) -name daemonset.yaml -type f | head -1)"
      sed -e 's|DoesNotExist|Exists|' "$INGRESS_HOSTPORT_MANIFEST" > "$INGRESS_HOSTPORT_MANIFEST".tmp \
      && mv "$INGRESS_HOSTPORT_MANIFEST".tmp "$INGRESS_HOSTPORT_MANIFEST"

      INGRESS_HOSTPORT_MANIFEST="$(find $(find $(find . -name ingress -type d) -name hostport -type d) -name daemonset.yaml -type f | head -1)"
      sed -e 's|DoesNotExist|Exists|' "$INGRESS_HOSTPORT_MANIFEST" > "$INGRESS_HOSTPORT_MANIFEST".tmp \
      && mv "$INGRESS_HOSTPORT_MANIFEST".tmp "$INGRESS_HOSTPORT_MANIFEST"

      LAST_ARG="$(grep -- '- --' "$INGRESS_HOSTPORT_MANIFEST" | tail -1)"
      SSL_PT_ARG="$(echo "$LAST_ARG" | sed -e "s|--.*|--enable-ssl-passthrough|" -e 's|[[:space:]]|\\ |g')"
      sed "/$LAST_ARG/a\\
$SSL_PT_ARG\\
" "$INGRESS_HOSTPORT_MANIFEST" > "$INGRESS_HOSTPORT_MANIFEST".tmp \
      && mv "$INGRESS_HOSTPORT_MANIFEST".tmp "$INGRESS_HOSTPORT_MANIFEST"

      sed 's|^        ||' <<'EOING' >> "$INGRESS_HOSTPORT_MANIFEST"
        ---
        apiVersion: extensions/v1beta1
        kind: Ingress
        metadata:
          name: kubernetes
          namespace: default
          annotations:
            ingress.kubernetes.io/ssl-passthrough: "true"
            kubernetes.io/ingress.class: "tectonic"
        spec:
          rules:
          - host: kubernetes.sandbox
            http:
              paths:
              - backend:
                  serviceName: kubernetes
                  servicePort: 443
EOING
      )
}

_install_to_provisioning_dir() {
    _ensure_temp "$1"
    [[ ! -d "$2" ]] || rm -r "$2"
    mkdir -p "$2"
    tar -c -C "$1" $(ls -A "$1") | tar -x -C "$2"
}

_prepare_workdir "$WORKDIR"
_patch_tectonic_ingress "$WORKDIR"
_install_to_provisioning_dir "$WORKDIR" "$PWD/provisioning/tectonic"