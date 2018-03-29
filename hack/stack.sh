#!/usr/bin/env bash

panic() {
    echo "${@}"
    exit 1
}

[[ "$1" ]] || panic "Give URL to tectonc-sandbox as first argument. Check out https://coreos.com/tectonic/sandbox/ for more information."

bash hack/install-vagrant-box.sh
bash hack/install-custom-vagrant-ignition-gem.sh
bash hack/extract-license-from-sandbox.sh "$1"
bash hack/generate-manifests.sh
bash hack/provide-manifests.sh