# Single node Tectonic Sandbox

This repo provides a Vagrant setup for spinning up a single node kubernetes with tectonic installed.

## Usage

- Create a modified coreos alpha box: `hack/install-vagrant-box.sh`
- Install a slightly modfied version of `vagrant-ignition` with VMware support.
- Download Tectonic sandbox to reuse existing `license.txt` and `pull.json`
- Download Tectonic installer to build kubernetes manifests
- Provide manifests in `provisioning/tectonic` and modify them to run Kubernetes API-Server and Ingress-Controllers on the same IP.

## Manual steps

Add `172.17.4.101 kubernetes.sandbox tectonic.sandbox` to your `/etc/hosts`-File.

## Running

`vagrant up` is your friend. You will find `tectonic.sandbox.pem` as Server-Certificate to access [https://tectonic.sandbox/](https://tectonic.sandbox/).

## Background

Tectonic Sandbox currently support VirtualBox only. Furthermore Tectonic adds some really nice features (included Prometheus and Grafana) and stuff to play with (Open Cloud Services and Custom Applications).

To bring it all together and run on a developer machine or laptop I wrote some scripts, which basically replaces those old parts from tectonic-sandbox by CoreOS with their current release.