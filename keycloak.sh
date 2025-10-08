#!/bin/bash

set -xeuo pipefail

dnf -y install docker
systemctl enable --now docker

mkdir -p /opt/keycloak/conf/certs

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /opt/keycloak/conf/certs/keycloak.key \
  -out /opt/keycloak/conf/certs/keycloak.crt \
  -subj "/CN=keycloak"

chmod 644 /opt/keycloak/conf/certs/keycloak.*
chown -R 1000:1000 /opt/keycloak/conf/certs

docker run -d --name keycloak \
  -p 443:8443 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  -v /opt/keycloak/conf/certs/:/opt/keycloak/conf/certs/:ro \
  -e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/conf/certs/keycloak.crt \
  -e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/conf/certs/keycloak.key \
  quay.io/keycloak/keycloak:latest start-dev
