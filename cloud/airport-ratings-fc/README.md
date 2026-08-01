# Airport ratings Function Compute API

This Function Compute Python 3.10 package provides shared, anonymous airport
forecast ratings for `https://iaplacs.xyz`.

## Deployment settings

- Function: `airport-ratings`
- Handler: `index.handler`
- Runtime: Python 3.10
- Region: China (Hong Kong)
- Role: `iaplacs-ratings-oss-role`
- Public trigger: `ratings-http`
- Endpoint: `https://airport-ratings-klxqryorbb.cn-hongkong.fcapp.run/`
- Environment variables:
  - `RATING_BUCKET=iaplacs-forecast-images-hk`
  - `OSS_ENDPOINT=https://oss-cn-hongkong-internal.aliyuncs.com`
  - `RATING_PREFIX=iaplacs/ratings/v1`

Build the deployable ZIP with:

```bash
bash cloud/airport-ratings-fc/build_zip.sh
```

The role must have `GetObject`, `PutObject`, `DeleteObject`, and `ListObjects`
only for `iaplacs/ratings/*` in the `iaplacs-forecast-images-hk` bucket.

The Alibaba Cloud Python 3.10 runtime includes `oss2`; the production ZIP
therefore contains only `index.py`. `requirements.txt` is retained for local
development environments that need to install the SDK explicitly.

The HTTP trigger accepts `GET`, `POST`, and `OPTIONS`; its CORS origin is
restricted by the function to `https://iaplacs.xyz` and
`https://www.iaplacs.xyz`.
