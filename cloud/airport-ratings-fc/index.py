"""HTTP API for shared IAP-LACS airport forecast ratings.

Deploy this file as ``index.handler`` to Alibaba Cloud Function Compute (FC)
with an HTTP trigger.  Each anonymous browser writes one small OSS object for
one airport/run, so concurrent visitors never overwrite a shared JSON file.
"""

import base64
import json
import os
import re
from datetime import datetime, timezone

import oss2


BUCKET_NAME = os.getenv("RATING_BUCKET", "iaplacs-forecast-images-hk")
OSS_ENDPOINT = os.getenv("OSS_ENDPOINT", "https://oss-cn-hongkong-internal.aliyuncs.com")
OBJECT_PREFIX = os.getenv("RATING_PREFIX", "iaplacs/ratings/v1").strip("/")
ALLOWED_ORIGINS = {
    "https://iaplacs.xyz",
    "https://www.iaplacs.xyz",
}
AIRPORTS = {
    "dehong_mangshi",
    "xishuangbanna_gasa",
    "puer_lancang_jingmai",
}
RATINGS = {"accurate", "inaccurate", "fair"}
SAFE_ID = re.compile(r"^[A-Za-z0-9_-]{6,128}$")
SAFE_CLIENT_ID = re.compile(r"^[A-Za-z0-9_-]{16,128}$")


def handler(event, context):
    """Return global counts and save a visitor's selected rating."""
    request = _parse_event(event)
    origin = _header(request.get("headers", {}), "origin")
    method = request.get("requestContext", {}).get("http", {}).get("method", "").upper()

    if method == "OPTIONS":
        return _response(204, "", origin)
    if origin and origin not in ALLOWED_ORIGINS:
        return _response(403, {"error": "origin_not_allowed"}, origin)

    try:
        bucket = _bucket(context)
        if method == "GET":
            query = request.get("queryParameters") or {}
            source_id, run_id = _validate_scope(query)
            client_id = query.get("client_id", "")
            if client_id and not SAFE_CLIENT_ID.fullmatch(client_id):
                raise ValueError("invalid_client_id")
            return _response(200, _read_summary(bucket, source_id, run_id, client_id), origin)

        if method == "POST":
            payload = _parse_body(request)
            source_id, run_id = _validate_scope(payload)
            airport_id = payload.get("airport_id", "")
            client_id = payload.get("client_id", "")
            rating = payload.get("rating")
            if airport_id not in AIRPORTS:
                raise ValueError("invalid_airport_id")
            if not SAFE_CLIENT_ID.fullmatch(client_id):
                raise ValueError("invalid_client_id")
            if rating is not None and rating not in RATINGS:
                raise ValueError("invalid_rating")

            object_name = _object_name(source_id, run_id, airport_id, client_id)
            if rating is None:
                if bucket.object_exists(object_name):
                    bucket.delete_object(object_name)
            else:
                record = {
                    "source_id": source_id,
                    "run_id": run_id,
                    "airport_id": airport_id,
                    "rating": rating,
                    "updated_at": _now(),
                }
                bucket.put_object(
                    object_name,
                    json.dumps(record, ensure_ascii=False, separators=(",", ":")),
                    headers={"Content-Type": "application/json"},
                )
            return _response(200, _read_summary(bucket, source_id, run_id, client_id), origin)

        return _response(405, {"error": "method_not_allowed"}, origin)
    except ValueError as error:
        return _response(400, {"error": str(error)}, origin)
    except Exception as error:  # Function logs retain the implementation detail.
        print("airport ratings API failed:", repr(error))
        return _response(500, {"error": "internal_error"}, origin)


def _parse_event(event):
    if isinstance(event, bytes):
        event = event.decode("utf-8")
    if isinstance(event, str):
        event = json.loads(event)
    if not isinstance(event, dict):
        raise ValueError("invalid_event")
    return event


def _parse_body(request):
    body = request.get("body") or "{}"
    if request.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")
    payload = json.loads(body)
    if not isinstance(payload, dict):
        raise ValueError("invalid_body")
    return payload


def _validate_scope(payload):
    source_id = payload.get("source_id", "")
    run_id = payload.get("run_id", "")
    if source_id not in {"huan", "tianhe"}:
        raise ValueError("invalid_source_id")
    if not SAFE_ID.fullmatch(run_id):
        raise ValueError("invalid_run_id")
    return source_id, run_id


def _bucket(context):
    credentials = context.credentials
    auth = oss2.StsAuth(
        credentials.access_key_id,
        credentials.access_key_secret,
        credentials.security_token,
    )
    return oss2.Bucket(auth, OSS_ENDPOINT, BUCKET_NAME)


def _object_name(source_id, run_id, airport_id, client_id):
    return f"{OBJECT_PREFIX}/{source_id}/{run_id}/{airport_id}/{client_id}.json"


def _read_summary(bucket, source_id, run_id, viewer_client_id):
    prefix = f"{OBJECT_PREFIX}/{source_id}/{run_id}/"
    counts = {
        airport_id: {"accurate": 0, "inaccurate": 0, "fair": 0, "total": 0}
        for airport_id in AIRPORTS
    }
    viewer_ratings = {}
    latest_update = None

    for obj in oss2.ObjectIterator(bucket, prefix=prefix):
        if not obj.key.endswith(".json"):
            continue
        try:
            record = json.loads(bucket.get_object(obj.key).read().decode("utf-8"))
            airport_id = record.get("airport_id")
            rating = record.get("rating")
            if airport_id not in AIRPORTS or rating not in RATINGS:
                continue
            counts[airport_id][rating] += 1
            counts[airport_id]["total"] += 1
            updated_at = record.get("updated_at")
            if updated_at and (latest_update is None or updated_at > latest_update):
                latest_update = updated_at
            if viewer_client_id and obj.key.endswith(f"/{viewer_client_id}.json"):
                viewer_ratings[airport_id] = {"rating": rating, "updated_at": updated_at}
        except Exception as error:
            print("skip invalid rating object", obj.key, repr(error))

    return {
        "source_id": source_id,
        "run_id": run_id,
        "updated_at": latest_update,
        "ratings": counts,
        "viewer_ratings": viewer_ratings,
    }


def _header(headers, name):
    for key, value in headers.items():
        if key.lower() == name:
            return value
    return ""


def _response(status_code, body, origin):
    headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
        "Vary": "Origin",
    }
    if origin in ALLOWED_ORIGINS:
        headers["Access-Control-Allow-Origin"] = origin
    body_text = body if isinstance(body, str) else json.dumps(body, ensure_ascii=False)
    return {
        "statusCode": status_code,
        "headers": headers,
        "isBase64Encoded": False,
        "body": body_text,
    }


def _now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
