#!/bin/bash
set -e

if [ -f /home/deployer/.ssh/authorized_keys ]; then
  chmod 600 /home/deployer/.ssh/authorized_keys
  chown deployer:deployer /home/deployer/.ssh/authorized_keys
fi

if [ -S /var/run/docker.sock ]; then
  DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
  DOCKER_GROUP="$(getent group "$DOCKER_GID" | cut -d: -f1 || true)"
  if [ -z "$DOCKER_GROUP" ]; then
    DOCKER_GROUP="docker-host"
    groupadd -g "$DOCKER_GID" "$DOCKER_GROUP"
  fi
  usermod -aG "$DOCKER_GROUP" deployer
fi

exec /usr/sbin/sshd -D -e
