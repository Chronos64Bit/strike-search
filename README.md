# Strike Search

The SearXNG search backend behind [Strike](https://ventryx.xyz), a
privacy-first browser by Ventryx. Runs on Railway, deployed straight from this
repository.

Forked from [protemplate/searxng](https://github.com/protemplate/searxng),
which supplies the Railway wiring. The differences are deliberate and each one
exists because of something that broke.

## What changed from upstream

**The base image is pinned.** Upstream tracked `searxng/searxng:latest`. That
rebuilds daily, so a redeploy triggered months later by an unrelated change
would ship a different SearXNG than the one anyone tested. Bump the tag in the
`Dockerfile` on purpose, and re-test when you do.

**Config syncs on every boot, not just the first.** Upstream copied
`/etc/searxng-backup` into the volume only when `settings.yml` was missing.
That is right exactly once; afterwards the volume holds a file, the copy is
skipped forever, and editing this repo changes nothing. The deploy still goes
green, and the instance still serves the old config. `entrypoint.sh` now
copies every boot, which makes this repository the source of truth and makes a
deploy actually deploy.

The trade-off: edits made by hand inside the running container do not survive
a restart. That is intended. Config that exists only inside a container cannot
be reviewed, diffed, or rolled back.

**Missing secret key is fatal.** Upstream warned and continued, leaving
SearXNG's built-in `ultrasecretkey` in place; SearXNG then refused to start
several steps later with a message describing the symptom rather than the
cause. If it had started, session cookies would have been forgeable with a key
that is public knowledge. It now stops and says so.

## Configuration

Everything lives in `searxng/settings.yml`, commented with the reasoning.
Briefly: Strike branding, dark theme, no autocomplete, image proxy on, Google
and Bing disabled because they block datacenter IPs, and ventryx.xyz boosted
in the ranking.

### Environment

| Variable | Required | Notes |
|---|---|---|
| `SEARXNG_SECRET_KEY` | yes | Container refuses to start without it. Never in this repo. |
| `SEARXNG_BASE_URL` | yes | Must be `https://` — Railway terminates TLS, and `http://` produces redirect loops and mixed-content failures that look like browser bugs. |
| `SEARXNG_UWSGI_WORKERS` | no | Defaults to 4. Two is plenty for a single-instance deployment and halves the memory bill. |
| `SEARXNG_UWSGI_THREADS` | no | Defaults to 4. |

## Before you restart it

Validating YAML is not validating a `settings.yml`. `yaml.safe_load` succeeding
only means the file is well-formed; SearXNG applies a schema on top, and only
that decides whether the process starts. Check with SearXNG's own loader in the
container first:

```sh
SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml \
  /usr/local/searxng/.venv/bin/python -c 'from searx import settings'
```

It names the offending key exactly, for example

```
Expected `str`, got `bool` - at `brand.public_instances`
```

That error never reaches Railway's deploy logs, because SearXNG fails before
it has configured logging. Looking for it there does not work.

If the container is already crash-looping you cannot use the console at all —
Railway attaches only to a *running* instance. Set the service's Custom Start
Command to `sleep infinity`, deploy, fix it, then clear the command.

## Known limits

**No Redis, so the limiter is off.** SearXNG's bot protection keeps its
counters in Redis or Valkey. With no backing store it does not fail loudly, it
just stops limiting. Turning it on without Redis buys the appearance of
protection and none of it. Enable both in the same change.

**Boosting cannot invent results.** The `hostnames` plugin reorders what the
engines returned. If ventryx.xyz is not in DuckDuckGo, Brave or Mojeek's index,
there is nothing to move up, and the fix is getting indexed rather than more
configuration.

**Every query from every user passes through this instance.** Strike's claim is
that it does not keep what it does not need, and a shared instance concentrates
exactly what a privacy product promises not to collect. That is a bigger
promise to keep than handing searches to DuckDuckGo, not a smaller one.
