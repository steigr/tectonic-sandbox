#!/usr/bin/env bash
#
# vagrant-ignition 0.0.3 currently supports only virtualbox
# but there are PRs pending adding support for VMware
#

[[ -z "$TRACE" ]] || set -x

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -e

VAGRANT_IGNITON_REPO="https://github.com/steigr/vagrant-ignition"
VAGRANT_IGNITON_BRANCH="feature/detect-active-provider"
VAGRANT_IGNITON_GEM="build/vagrant-ignition.gem"

VAGRANT_HOME=/opt/vagrant
WORKDIR="$(mktemp -d -u)"

_checkout() {
    git clone "$VAGRANT_IGNITON_REPO" "$1" -b "$VAGRANT_IGNITON_BRANCH"
}

_build_gem() {
    ( cd "$1"
      export GEM_HOME="$PWD/gems" \
             GEM_PATH="$PWD/gems:$VAGRANT_HOME/embedded/gems" \
             PATH="$VAGRANT_HOME/embedded/bin:$PATH"
             gem install --no-ri --no-rdoc rake bundler
             rake build )
}

_install_plugin() {
    cp "$1/pkg"/vagrant-ignition-*.gem "$VAGRANT_IGNITON_GEM"
    vagrant plugin install "$VAGRANT_IGNITON_GEM"
}

_ensure_build

[[ -f "$VAGRANT_IGNITON_GEM" ]] || (
  _ensure_temp "$WORKDIR"
  _checkout "$WORKDIR"
  _build_gem "$WORKDIR"
  _install_plugin "$WORKDIR"
)