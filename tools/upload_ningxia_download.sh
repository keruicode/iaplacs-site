#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/runtime_paths.sh"
source "$IAPLACS_SCRIPT_DIR/plot_scheduler.sh"
iaplacs_require_compute || exit 77
run="${1:-}"
directory="${2:-}"
[[ "$run" =~ ^[0-9]{8}_[0-9]{2}$ && -f "$directory/index.json" ]] || exit 64
python="${PYTHON_BIN:-/public/software/apps/conda/latest/bin/python3}"
read -r file digest < <("$python" - "$directory/index.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
print(data["file"], data["sha256"])
PY
)
[[ "$file" =~ ^ningxia_[0-9]{10}_d[0-9]{2}_[a-f0-9]{16}\.nc$ && "$digest" =~ ^[a-f0-9]{64}$ ]] || exit 65
[[ "$(sha256sum "$directory/$file" | cut -d' ' -f1)" == "$digest" ]] || exit 65
host="${GITHUB_HOST:-server02}"
incoming="ningxia_nc_${run}_${digest:0:16}"
remote_command=$(printf 'RUN=%q FILE=%q DIGEST=%q INCOMING=%q bash -s' "$run" "$file" "$digest" "$incoming")
# Verify the public object on every retry, including after a prior receipt.
if [[ -f "$directory/.published-sha256" && "$(<"$directory/.published-sha256")" == "$digest" ]]; then
  index_digest="$(sha256sum "$directory/index.json" | cut -d' ' -f1)"
  check=$(printf 'RUN=%q FILE=%q EXPECTED=%q bash -s' "$run" "$file" "$index_digest")
  if ssh -o BatchMode=yes -o ConnectTimeout=20 "$host" "$check" <<'CHECK'
set -Eeuo pipefail
unset LD_LIBRARY_PATH LIBRARY_PATH LD_PRELOAD
source "$HOME/.iaplacs-oss.env"
prefix="${IAPLACS_OSS_PREFIX:-}"; prefix="${prefix#/}"; prefix="${prefix%/}"
base="${IAPLACS_OSS_PUBLIC_BASE_URL%/}/${prefix:+$prefix/}data/current/maps/worknx_summary_$RUN/downloads"
actual="$(curl -fsS --max-time 30 "$base/index.json" | sha256sum | cut -d' ' -f1)"
[[ "$actual" == "$EXPECTED" ]]
headers="$(curl -fsSI --max-time 30 "$base/$FILE")"
grep -Fq "filename=${FILE%_*}.nc" <<<"$headers"
CHECK
  then exit 0; fi
fi
ssh -o BatchMode=yes -o ConnectTimeout=20 "$host" "mkdir -p \"\$HOME/incoming/$incoming\""
rsync -a "$directory/index.json" "$directory/$file" "$host:incoming/$incoming/"
ssh -o BatchMode=yes -o ConnectTimeout=20 "$host" "$remote_command" <<'REMOTE'
set -Eeuo pipefail
unset LD_LIBRARY_PATH LIBRARY_PATH LD_PRELOAD
source "$HOME/.iaplacs-oss.env"
[[ "${IAPLACS_OSS_ENABLED:-0}" == 1 ]] || exit 75
dir="$HOME/incoming/$INCOMING"
[[ "$(sha256sum "$dir/$FILE" | cut -d' ' -f1)" == "$DIGEST" ]] || exit 65
exec 8>"$HOME/.iaplacs-github-publish.lock"
flock -w 600 8 || exit 75
oss="${IAPLACS_OSSUTIL_BIN:-$HOME/bin/ossutil}"
prefix="${IAPLACS_OSS_PREFIX:-}"
prefix="${prefix#/}"; prefix="${prefix%/}"
relative="data/current/maps/worknx_summary_$RUN/downloads"
key="${prefix:+$prefix/}$relative"
base="${IAPLACS_OSS_PUBLIC_BASE_URL%/}/${prefix:+$prefix/}$relative"
GOMAXPROCS=1 "$oss" cp "$dir/$FILE" "oss://$IAPLACS_OSS_BUCKET/$key/$FILE" -f \
  -e "$IAPLACS_OSS_ENDPOINT" --acl "${IAPLACS_OSS_OBJECT_ACL:-public-read}" \
  --meta "Content-Type:application/x-netcdf#Content-Disposition:attachment; filename=${FILE%_*}.nc#Cache-Control:public, max-age=31536000, immutable"
curl -fsS --max-time 180 "$base/$FILE" -D "$dir/.verified.headers" -o "$dir/.verified.nc"
grep -Fq "filename=${FILE%_*}.nc" "$dir/.verified.headers"
[[ "$(sha256sum "$dir/.verified.nc" | cut -d' ' -f1)" == "$DIGEST" ]] || exit 65
GOMAXPROCS=1 "$oss" cp "$dir/index.json" "oss://$IAPLACS_OSS_BUCKET/$key/index.json" -f \
  -e "$IAPLACS_OSS_ENDPOINT" --acl "${IAPLACS_OSS_OBJECT_ACL:-public-read}" \
  --meta 'Content-Type:application/json#Cache-Control:no-cache'
curl -fsS --max-time 30 "$base/index.json" -o "$dir/.verified.json"
cmp "$dir/index.json" "$dir/.verified.json"
rm -f "$dir/$FILE" "$dir/index.json" "$dir/.verified.nc" "$dir/.verified.json" "$dir/.verified.headers"
rmdir "$dir"
REMOTE
printf '%s\n' "$digest" > "$directory/.published-sha256.tmp"
mv "$directory/.published-sha256.tmp" "$directory/.published-sha256"
