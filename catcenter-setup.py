#!/usr/bin/env python3
"""Catalyst Center 3.x: complete first-login wizard, then create a site."""

import base64
import json
import requests
import sys
import time
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HOST = sys.argv[1] if len(sys.argv) > 1 else input("Catalyst Center IP: ")
BASE = f"https://{HOST}"
DEFAULT_USER = "admin"
DEFAULT_PASS = "P@ssword9"
NEW_USER = "catadmin"
NEW_PASS = f"Lab!{time.time_ns():x}"
NEW_EMAIL = "catadmin@lab.local"


def get_token(user, password):
    r = requests.post(
        f"{BASE}/api/system/v1/auth/token",
        auth=(user, password),
        verify=False,
    )
    r.raise_for_status()
    return r.json()["Token"]


def decode_jwt(token):
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def setup_wizard(token):
    claims = decode_jwt(token)
    admin_id = claims["sub"]
    rds = claims["rds"]
    headers = {"X-Auth-Token": token, "Content-Type": "application/json"}

    # 1. Create new super-admin user
    print(f"  Creating user '{NEW_USER}'...")
    r = requests.post(
        f"{BASE}/api/idm/v1/local/users",
        headers=headers,
        json={
            "username": NEW_USER,
            "passphrase": NEW_PASS,
            "firstName": "Cat",
            "lastName": "Center",
            "email": NEW_EMAIL,
            "rds": rds,
        },
        verify=False,
    )
    if not r.ok:
        print(f"  FAILED ({r.status_code}): {r.text}")
        sys.exit(1)
    print(f"  User created. ({r.status_code})")

    # 2. Delete default admin user
    print(f"  Deleting default admin (id={admin_id})...")
    r = requests.delete(
        f"{BASE}/api/idm/v1/local/users/{admin_id}",
        headers=headers,
        verify=False,
    )
    if not r.ok:
        print(f"  FAILED ({r.status_code}): {r.text}")
        sys.exit(1)
    print(f"  Default admin deleted. ({r.status_code})")

    # 3. Re-auth as new user (old token is invalid)
    print(f"  Re-authenticating as {NEW_USER}...")
    new_token = get_token(NEW_USER, NEW_PASS)
    headers = {"X-Auth-Token": new_token, "Content-Type": "application/json"}

    # 4. Mark first login complete (requires cookie auth, not X-Auth-Token)
    print("  Marking first login complete...")
    r = requests.post(
        f"{BASE}/auth/firstLogin",
        cookies={"X-JWT-ACCESS-TOKEN": new_token},
        verify=False,
    )
    if not r.ok:
        print(f"  FAILED ({r.status_code}): {r.text}")
        sys.exit(1)
    print(f"  First login done. ({r.status_code})")


def create_site(token, name, address, lat, lng, parent="Global"):
    r = requests.post(
        f"{BASE}/dna/intent/api/v1/site",
        headers={"X-Auth-Token": token, "Content-Type": "application/json"},
        json={
            "type": "building",
            "site": {
                "building": {
                    "name": name,
                    "address": address,
                    "parentName": parent,
                    "latitude": lat,
                    "longitude": lng,
                }
            },
        },
        verify=False,
    )
    r.raise_for_status()
    return r.json()


def check_execution(token, execution_url):
    headers = {"X-Auth-Token": token}
    for _ in range(30):
        r = requests.get(f"{BASE}{execution_url}", headers=headers, verify=False)
        r.raise_for_status()
        data = r.json()
        status = data.get("status", "")
        if status == "SUCCESS":
            print(f"  OK")
            return True
        if status == "FAILURE":
            print(f"  FAILED: {data}")
            return False
        time.sleep(2)
    print("  TIMEOUT waiting for execution")
    return False


# --- main ---
print(f"[1/3] Authenticating as {DEFAULT_USER} (default creds)...")
token = get_token(DEFAULT_USER, DEFAULT_PASS)
print("  Token acquired.")

print("[2/3] Completing first-login wizard...")
setup_wizard(token)

print("  Re-authenticating as new user...")
token = get_token(NEW_USER, NEW_PASS)
print("  Token acquired.")

print("[3/3] Creating site: 1WTC...")
result = create_site(
    token,
    name="1WTC",
    address="285 Fulton St, New York, NY 10007",
    lat=40.71274,
    lng=-74.01338,
)
execution_url = result.get("executionStatusUrl")
if execution_url:
    check_execution(token, execution_url)
else:
    print(f"  Response: {result}")

print(f"\nDone. GUI: {BASE} — {NEW_USER} / {NEW_PASS}")
