# Deployment Notes

## Do You Need Server Deployment?

For the current GitHub Pages plan, the website itself is not deployed on the IAP server.

The IAP server only needs a scheduled publishing job:

1. read model/observation products;
2. render maps and JSON into a temporary release directory;
3. validate `manifest.json` and image paths;
4. copy the result to `data/current`;
5. commit and push to GitHub.

GitHub Pages then serves the updated static files.

## When a Real Server Becomes Necessary

Add a backend server later only if the site needs:

- login or access control;
- database queries;
- very large historical archive search;
- user-submitted jobs;
- real-time computation;
- APIs for other systems.

## Future Publishing Script Shape

The IAP server can run a scheduled script similar to:

```bash
#!/usr/bin/env bash
set -euo pipefail

SITE_REPO="$HOME/iaplacs-site"
PRODUCT_DIR="/path/to/generated/web-products"

cd "$SITE_REPO"
git pull --ff-only

rm -rf data/current
mkdir -p data
cp -R "$PRODUCT_DIR" data/current

test -f data/current/manifest.json
find data/current/maps -type f | head -n 1 >/dev/null

git add data/current
git commit -m "Update forecast products $(date +%Y%m%d_%H%M)" || exit 0
git push
```

For production, publish into timestamped release directories and switch `current` only after validation.
