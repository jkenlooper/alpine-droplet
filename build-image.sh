#!/bin/sh

set -o errexit

F="${1-:alpine-virt-image-$(date +%Y-%m-%d-%H%M)}"

./alpine-make-vm-image/alpine-make-vm-image \
  --packages "$(cat packages)" \
  --script-chroot \
  --image-format qcow2 \
  $F.qcow2 -- ./setup.sh
bzip2 -z $F.qcow2
