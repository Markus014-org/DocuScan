#!/usr/bin/env python3
"""Publiziert ausschließlich die letzte gültige Build-Nummer einer Beta-Testgruppe.

Das Apple-P8-Geheimnis bleibt in GitHub Actions. Das iPhone lädt nur die
öffentliche resultierende JSON-Datei von GitHub Pages.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

BASE = "https://api.appstoreconnect.apple.com"


def version_key(version: str):
    parts = version.split(".")
    return tuple(int(part) if part.isdigit() else 0 for part in parts)


def eligible(build):
    attrs = build.get("attributes", {})
    return (
        attrs.get("processingState") == "VALID"
        and attrs.get("expired") is False
        and bool(attrs.get("version"))
    )


def beta_state_ready(details, is_internal: bool):
    """Nur bereits für die jeweilige Testart nutzbare Builds melden."""
    field = "internalBuildState" if is_internal else "externalBuildState"
    return details.get("attributes", {}).get(field) in {"READY_FOR_BETA_TESTING", "IN_BETA_TESTING"}


def latest_group_build(builds):
    accepted = [build for build in builds if eligible(build)]
    return max(accepted, key=lambda b: (b["attributes"].get("uploadedDate") or "", version_key(b["attributes"]["version"])), default=None)


def api_get(path, token):
    # Nur URLs der Apple-API; 'next' in paginierten Ergebnissen prüfen.
    url = path if path.startswith("https://") else BASE + path
    if not url.startswith(BASE + "/"):
        raise ValueError("Unbekanntes API-Ziel: " + url)
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    import jwt  # pip install PyJWT cryptography

    issuer = os.environ["ASC_ISSUER_ID"]
    key_id = os.environ["ASC_KEY_ID"]
    private_key = os.environ["ASC_PRIVATE_KEY"]
    group_id = os.environ["ASC_BETA_GROUP_ID"]
    now = int(time.time())
    token = jwt.encode({"iss": issuer, "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
                       private_key, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})

    quoted_group = urllib.parse.quote(group_id, safe="")
    group = api_get("/v1/betaGroups/" + quoted_group, token)
    is_internal = group["data"]["attributes"]["isInternalGroup"]
    path = "/v1/betaGroups/" + quoted_group + "/builds?limit=200"
    builds = []
    for _ in range(20):
        page = api_get(path, token)
        builds += page.get("data", [])
        path = page.get("links", {}).get("next")
        if not path:
            break
    valid = sorted(
        (build for build in builds if eligible(build)),
        key=lambda b: (b["attributes"].get("uploadedDate") or "", version_key(b["attributes"]["version"])),
        reverse=True,
    )
    best = None
    for candidate in valid:
        candidate_id = urllib.parse.quote(candidate["id"], safe="")
        detail = api_get("/v1/builds/" + candidate_id + "/buildBetaDetail", token)
        if beta_state_ready(detail["data"], is_internal):
            best = candidate
            break
    if not best:
        print("Noch kein für diese Testgruppe freigegebener Build. Kein Manifest veröffentlicht.")
        return

    build_id = urllib.parse.quote(best["id"], safe="")
    version_response = api_get("/v1/builds/" + build_id + "/preReleaseVersion", token)
    marketing_version = version_response["data"]["attributes"]["version"]
    result = {
        "version": marketing_version,
        "build": best["attributes"]["version"],
        "publishedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "site/latest-build.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Version {result['version']} Build {result['build']} veröffentlicht.")


if __name__ == "__main__":
    main()
