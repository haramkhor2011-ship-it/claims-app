# Claims AME Post-Install & Pre-Startup Automation

This repo includes a Makefile that sets up **App-Managed Encryption (AME)** for DHPO credentials and seeds facilities automatically.
If you only want the automation: run **`make up`** and you’re done.
If you want to learn what’s happening, read on (novice-friendly).

---

## What is AME (10 seconds)
- We keep **one key** (keystore or key file) next to the app.
- The app uses it to **encrypt** facility login/password into the DB, and **decrypts** on the fly.
- You never touch SQL crypto. You use a simple **admin API** to add/rotate facilities.

---

## Quickstart

### 1) Create facilities.json (or let `make seed` create a sample)
```json
[
  {
    "facilityCode": "HOSP1",
    "facilityName": "City Hospital",
    "active": true,
    "endpointUrl": "https://qa.eclaimlink.ae/dhpo/ValidateTransactions.asmx",
    "soap12": false,
    "callerLicense": "LIC123",
    "ePartner": "EPART001",
    "login": "dhpo_user_hosp1",
    "password": "S3cureP@ss!"
  }
]

export ADMIN_TOKEN='<SUPER_ADMIN_BEARER_TOKEN>'
make up
