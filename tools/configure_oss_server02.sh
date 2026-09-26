#!/usr/bin/env bash

set -Eeuo pipefail

OSSUTIL_BIN="${IAPLACS_OSSUTIL_BIN:-$HOME/bin/ossutil}"
CONFIG_FILE="${OSSUTIL_CONFIG_FILE:-$HOME/.ossutilconfig}"
ENV_FILE="${IAPLACS_OSS_ENV_FILE:-$HOME/.iaplacs-oss.env}"
SITE_REPO="${IAPLACS_SITE_REPO:-$HOME/iaplacs-site}"

if [ ! -x "$OSSUTIL_BIN" ]; then
	echo "ERROR: ossutil is not installed at $OSSUTIL_BIN" >&2
	exit 1
fi

read -r -p "Bucket name: " bucket
read -r -p "OSS endpoint (example: oss-cn-hongkong.aliyuncs.com): " endpoint
default_public_url="https://${bucket}.${endpoint}"
read -r -p "Public image origin [$default_public_url]: " public_url
public_url="${public_url:-$default_public_url}"
read -r -p "Object prefix [iaplacs]: " prefix
prefix="${prefix:-iaplacs}"

if [[ ! "$bucket" =~ ^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$ ]]; then
	echo "ERROR: invalid Bucket name" >&2
	exit 1
fi
if [[ ! "$endpoint" =~ ^oss-[a-z0-9-]+\.aliyuncs\.com$ ]]; then
	echo "ERROR: expected a public OSS endpoint such as oss-cn-hongkong.aliyuncs.com" >&2
	exit 1
fi
if [[ ! "$public_url" =~ ^https://[^[:space:]\']+$ ]]; then
	echo "ERROR: public image origin must be one HTTPS URL without a trailing object path" >&2
	exit 1
fi
if [[ "$prefix" == *".."* || ! "$prefix" =~ ^[A-Za-z0-9._/-]+$ ]]; then
	echo "ERROR: invalid object prefix" >&2
	exit 1
fi

public_url="${public_url%/}"
prefix="${prefix#/}"
prefix="${prefix%/}"

if [ ! -s "$CONFIG_FILE" ]; then
	echo "No ossutil credentials found. Enter a RAM-user AccessKey only in this terminal."
	read -r -p "AccessKey ID: " access_key_id
	read -r -s -p "AccessKey Secret: " access_key_secret
	echo
	if [ -z "$access_key_id" ] || [ -z "$access_key_secret" ]; then
		echo "ERROR: AccessKey ID and Secret are required" >&2
		exit 1
	fi

	umask 077
	tmp_config="$(mktemp "$HOME/.ossutilconfig.XXXXXX")"
	{
		printf '[Credentials]\n'
		printf 'language = EN\n'
		printf 'endpoint = %s\n' "$endpoint"
		printf 'accessKeyID = %s\n' "$access_key_id"
		printf 'accessKeySecret = %s\n' "$access_key_secret"
		printf 'stsToken =\n'
		printf 'outputDir = %s\n' "$HOME/.ossutil_output"
	} > "$tmp_config"
	chmod 600 "$tmp_config"
	mv "$tmp_config" "$CONFIG_FILE"
	unset access_key_id access_key_secret
fi

echo "Checking Bucket access..."
if ! "$OSSUTIL_BIN" ls "oss://$bucket" -e "$endpoint" -c "$CONFIG_FILE" >/dev/null; then
	echo "ERROR: Bucket check failed. Confirm that the RAM policy includes oss:GetBucketInfo and oss:ListObjects, and that the RAM user belongs to the Bucket owner account." >&2
	exit 1
fi

read -r -p "Replace this Bucket's CORS rules for iaplacs.xyz? [y/N]: " configure_cors
if [[ "$configure_cors" =~ ^[Yy]$ ]]; then
	cors_file="$(mktemp /tmp/iaplacs-cors.XXXXXX.xml)"
	trap 'rm -f "${cors_file:-}" "${headers_file:-}"' EXIT
	{
		printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
		printf '%s\n' '<CORSConfiguration>'
		printf '%s\n' '  <CORSRule>'
		printf '%s\n' '    <AllowedOrigin>https://iaplacs.xyz</AllowedOrigin>'
		printf '%s\n' '    <AllowedOrigin>https://www.iaplacs.xyz</AllowedOrigin>'
		printf '%s\n' '    <AllowedMethod>GET</AllowedMethod>'
		printf '%s\n' '    <AllowedMethod>HEAD</AllowedMethod>'
		printf '%s\n' '    <AllowedHeader>*</AllowedHeader>'
		printf '%s\n' '    <ExposeHeader>ETag</ExposeHeader>'
		printf '%s\n' '    <ExposeHeader>Content-Length</ExposeHeader>'
		printf '%s\n' '    <ExposeHeader>Content-Type</ExposeHeader>'
		printf '%s\n' '    <MaxAgeSeconds>86400</MaxAgeSeconds>'
		printf '%s\n' '  </CORSRule>'
		printf '%s\n' '</CORSConfiguration>'
	} > "$cors_file"
	"$OSSUTIL_BIN" cors --method put "oss://$bucket" "$cors_file" -e "$endpoint" -c "$CONFIG_FILE"
fi

sample="$(
	find "$SITE_REPO/data/current/maps" -type f -name '*.webp' -printf '%T@ %p\n' 2>/dev/null \
		| sort -nr | sed -n '1s/^[^ ]* //p'
)"
if [ -z "$sample" ]; then
	echo "ERROR: no WebP sample found under $SITE_REPO/data/current/maps" >&2
	exit 1
fi

test_key="iaplacs-test/$(basename "$sample")"
if [ -n "$prefix" ]; then
	test_key="$prefix/$test_key"
fi

echo "Uploading one isolated test object..."
"$OSSUTIL_BIN" cp "$sample" "oss://$bucket/$test_key" -f -e "$endpoint" -c "$CONFIG_FILE" \
	--meta "Cache-Control:public,max-age=604800#Content-Type:image/webp" \
	--acl public-read

test_url="$public_url/$test_key"
headers_file="$(mktemp /tmp/iaplacs-headers.XXXXXX)"
curl -fsS --range 0-0 --max-time 30 -H 'Origin: https://iaplacs.xyz' \
	-D "$headers_file" -o /dev/null "$test_url"
if ! grep -qi '^access-control-allow-origin: https://iaplacs\.xyz' "$headers_file"; then
	echo "ERROR: test object is reachable, but the CORS response does not allow https://iaplacs.xyz" >&2
	echo "Test URL: $test_url" >&2
	exit 1
fi

umask 077
tmp_env="$(mktemp "$HOME/.iaplacs-oss.env.XXXXXX")"
{
	printf 'IAPLACS_OSS_ENABLED=1\n'
	printf 'IAPLACS_OSS_BUCKET=%q\n' "$bucket"
	printf 'IAPLACS_OSS_ENDPOINT=%q\n' "$endpoint"
	printf 'IAPLACS_OSS_PUBLIC_BASE_URL=%q\n' "$public_url"
	printf 'IAPLACS_OSS_PREFIX=%q\n' "$prefix"
	printf 'IAPLACS_OSS_OBJECT_ACL=public-read\n'
	printf 'IAPLACS_OSSUTIL_BIN=%q\n' "$OSSUTIL_BIN"
	printf 'IAPLACS_OSS_RETAIN_RUNS=5\n'
	printf 'IAPLACS_OSS_RETENTION_ENABLED=1\n'
	printf 'IAPLACS_OSS_PRUNE_SCRIPT=%q\n' "$HOME/bin/prune_iaplacs_oss.sh"
} > "$tmp_env"
chmod 600 "$tmp_env"
mv "$tmp_env" "$ENV_FILE"

echo "OSS publishing is enabled for the server-side forecast publishers."
echo "Verified test URL: $test_url"
echo "Runtime settings: $ENV_FILE"
echo "Retention: latest 5 initialization times per forecast family"
