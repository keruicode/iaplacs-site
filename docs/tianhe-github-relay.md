# Tianhe GitHub Publisher

The publisher runs on Tianhe itself. It checks the newest completed
`WORK_nx` and `WORK_yn` forecast figures, copies only new products to a local
GitHub Pages checkout, retains five run directories per product family,
rebuilds `data/tianhe/current/forecast-runs.json`, and pushes the result to
GitHub. No Mac cron task is used.

The publisher reads these default Tianhe locations:

```text
/fs2/home/junzhang/zhoubj/WORK_nx
/fs2/home/junzhang/zhoubj/WORK_yn
```

It uses ImageMagick when present; otherwise it uses Pillow from the existing
`wrf-scripts` Conda environment to create bounded WebP and preview WebP files.
When available, it runs Git through `/fs2/home/junzhang/kerui/bin/git-system`
to avoid environment library conflicts from scientific-module shells.

After cloning `iaplacs-site` to `/fs2/home/junzhang/kerui/iaplacs-site`,
verify discovery without changing files:

```bash
tools/tianhe_publish_forecast_to_github.sh --dry-run
```

Install or refresh the managed Tianhe cron entry:

```bash
tools/install_tianhe_publisher_cron.sh
```

The cron entry runs every 15 minutes (minutes 07, 22, 37, and 52) and logs to
`~/.iaplacs-tianhe/logs/github-publisher.log`. It requires Tianhe to reach
GitHub and to have GitHub push authentication configured for the repository.
If GitHub is temporarily unreachable, the publisher still creates the local
catalog commit and retries the push on its next scheduled run. Each Git network
operation has two attempts by default; adjust
`IAPLACS_TIANHE_GIT_NETWORK_ATTEMPTS` or
`IAPLACS_TIANHE_GIT_NETWORK_RETRY_DELAY` only when needed.
