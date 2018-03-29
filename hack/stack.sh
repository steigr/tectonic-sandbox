#!/usr/bin/env bash

[[ -z "$TRACE" ]] || set -x

bash hack/install-vagrant-box.sh
bash hack/install-custom-vagrant-ignition-gem.sh
bash hack/extract-license-from-sandbox.sh "$1"
bash hack/generate-manifests.sh
bash hack/provide-manifests.sh