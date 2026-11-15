#!/usr/bin/env python3
"""Schreibt die Export-Optionen für Xcode 26 (ohne feste Bundle-ID im Repo)."""
import os
import plistlib
from pathlib import Path

export = {
    "method": "app-store-connect",
    "destination": "export",
    "signingStyle": "manual",
    "signingCertificate": "Apple Distribution",
    "teamID": os.environ["APPLE_TEAM_ID"],
    "provisioningProfiles": {os.environ["BUNDLE_ID"]: os.environ["PROFILE_NAME"]},
    "uploadSymbols": True,
    "manageAppVersionAndBuildNumber": False,
}
Path("build").mkdir(exist_ok=True)
with open("build/ExportOptions.plist", "wb") as output:
    plistlib.dump(export, output)
