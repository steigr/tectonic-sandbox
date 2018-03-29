#!/usr/bin/env bash
#
# vagrant-ignition 0.0.3 currently supports only virtualbox
# but there are PRs pending adding support for VMware
#

set -e

VAGRANT_IGNITON_REPO="https://github.com/steigr/vagrant-ignition"
VAGRANT_IGNITON_BRANCH="feature/detect-active-provider"

VAGRANT_HOME=/opt/vagrant
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
        trap "rm -rf $1/.git; rm -r $1" EXIT
    fi
}

_checkout() {
    _ensure_temp "$1"
    git clone "$VAGRANT_IGNITON_REPO" "$1" -b "$VAGRANT_IGNITON_BRANCH"
}

_build_gem() {
    _ensure_temp "$1"
    ( cd "$1"; GEM_HOME="$PWD/gems" GEM_PATH="$PWD/gems:$VAGRANT_HOME/embedded/gems" PATH="$VAGRANT_HOME/embedded/bin:$PATH" "$VAGRANT_HOME/embedded/bin/gem" install --no-ri --no-rdoc rake bundler)
    ( cd "$1"; GEM_HOME="$PWD/gems" GEM_PATH="$PWD/gems:$VAGRANT_HOME/embedded/gems" PATH="$VAGRANT_HOME/embedded/bin:$PATH" "$VAGRANT_HOME/embedded/bin/rake" build )
}

_install_plugin() {
    _ensure_temp "$1"
    ( cd "$1"; vagrant plugin install "$(ls pkg/vagrant-ignition-*.gem | tail -1 )" )
}

_checkout "$WORKDIR"
_build_gem "$WORKDIR"
_install_plugin "$WORKDIR"