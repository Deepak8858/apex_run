# ApexRun Website Scaffold

Static files for `https://apexrun.app`.

## Pages

- `/` -> `index.html`
- `/privacy` -> `privacy.html`
- `/terms` -> `terms.html`
- `/support` -> `support.html`
- `/account/delete` -> `account/delete.html`
- `/.well-known/apple-app-site-association`
- `/.well-known/assetlinks.json`

## Before Deploy

1. Replace `support@apexrun.app` if the support mailbox changes.
2. Fill `website/.well-known/assetlinks.json` with the production Android SHA-256 certificate fingerprint.
3. Fill `website/.well-known/apple-app-site-association` with the real Apple Team ID.
4. Configure host rewrites so `/privacy`, `/terms`, `/support`, and `/account/delete` serve the matching HTML files.
