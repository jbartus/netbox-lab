#!/bin/bash

set -xeuo pipefail

dnf -y install docker
systemctl enable --now docker

# generate tls certs for https (note: nothing to do with the saml certs)
mkdir -p /opt/keycloak/conf/certs

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /opt/keycloak/conf/certs/keycloak.key \
  -out /opt/keycloak/conf/certs/keycloak.crt \
  -subj "/CN=keycloak"

chmod 644 /opt/keycloak/conf/certs/keycloak.*
chown -R 1000:1000 /opt/keycloak/conf/certs

# run keycloak container
docker run -d --name keycloak \
  -p 443:8443 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  -v /opt/keycloak/conf/certs/:/opt/keycloak/conf/certs/:ro \
  -e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/conf/certs/keycloak.crt \
  -e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/conf/certs/keycloak.key \
  quay.io/keycloak/keycloak:latest start-dev

# wait a bit for it to come up
sleep 30

# get an api token
TOKEN=$(curl -k -X POST https://localhost:443/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -s | jq -r '.access_token')

# create a new realm
curl -k -X POST https://localhost:443/admin/realms \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "foo",
    "enabled": true
  }'

# create a user
curl -k -X POST https://localhost:443/admin/realms/foo/users \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "exampleuser",
    "email": "user@example.org",
    "firstName": "example",
    "lastName": "user",
    "enabled": true,
    "emailVerified": true,
    "credentials": [{
      "type": "password",
      "value": "wordpass",
      "temporary": false
    }]
  }'

# create a saml client
curl -k -X POST https://localhost:443/admin/realms/foo/clients \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "nbe",
    "enabled": true,
    "protocol": "saml",
    "redirectUris": [
      "https://1.2.3.4/oauth/complete/saml/"
    ],
    "attributes": {
      "saml.client.signature": "false",
      "saml_force_name_id_format": "true",
      "saml_name_id_format": "email"
    }
  }'

# get the ID of the client we just created
CLIENT_ID=$(curl -k -X GET https://localhost:443/admin/realms/foo/clients \
  -H "Authorization: Bearer ${TOKEN}" \
  -s | jq -r '.[] | select(.clientId=="nbe") | .id')

# get the IDs of the default client scopes and delete them
ROLE_LIST_SCOPE_ID=$(curl -k -X GET https://localhost:443/admin/realms/foo/client-scopes \
  -H "Authorization: Bearer ${TOKEN}" \
  -s | jq -r '.[] | select(.name=="role_list") | .id')

curl -k -X DELETE "https://localhost:443/admin/realms/foo/clients/${CLIENT_ID}/default-client-scopes/${ROLE_LIST_SCOPE_ID}" \
  -H "Authorization: Bearer ${TOKEN}"

SAML_ORG_SCOPE_ID=$(curl -k -X GET https://localhost:443/admin/realms/foo/client-scopes \
  -H "Authorization: Bearer ${TOKEN}" \
  -s | jq -r '.[] | select(.name=="saml_organization") | .id')

curl -k -X DELETE "https://localhost:443/admin/realms/foo/clients/${CLIENT_ID}/default-client-scopes/${SAML_ORG_SCOPE_ID}" \
  -H "Authorization: Bearer ${TOKEN}"

# create attribute mappers for email, first name, last name
curl -k -X POST "https://localhost:443/admin/realms/foo/clients/${CLIENT_ID}/protocol-mappers/models" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "email attribute mapper",
    "protocol": "saml",
    "protocolMapper": "saml-user-property-mapper",
    "config": {
      "user.attribute": "email",
      "attribute.name": "email",
      "attribute.nameformat": "Basic"
    }
  }'

curl -k -X POST "https://localhost:443/admin/realms/foo/clients/${CLIENT_ID}/protocol-mappers/models" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "firstname attribute mapper",
    "protocol": "saml",
    "protocolMapper": "saml-user-property-mapper",
    "config": {
      "user.attribute": "first_name",
      "attribute.name": "firstName",
      "attribute.nameformat": "Basic"
    }
  }'

curl -k -X POST "https://localhost:443/admin/realms/foo/clients/${CLIENT_ID}/protocol-mappers/models" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "lastname attribute mapper",
    "protocol": "saml",
    "protocolMapper": "saml-user-property-mapper",
    "config": {
      "user.attribute": "last_name",
      "attribute.name": "lastName",
      "attribute.nameformat": "Basic"
    }
  }'