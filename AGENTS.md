# Contributor & agent notes

## ALWAYS bump the version on every change

PlayLimit auto-updates itself from this repo, so versioning is **not optional**.
Any change to the app that will be committed must bump the version in lockstep:

- `__version__` in `albion_limiter.py`
- `version_info.txt` — `filevers`, `prodvers`, `FileVersion`, `ProductVersion`
- `version.txt` — the single value installed clients read to decide whether to update

Use semantic-ish increments: **patch** (x.y.**Z**) for fixes/small tweaks,
**minor** (x.**Y**.0) for new features. Keep all four spots identical.

### Release gate for `version.txt` + the exe (important)

`version.txt` is what installed copies compare against before downloading
`dist/PlayLimit.exe`. A `version.txt` bump is only *safe to release/merge* once the
compiled artifacts are rebuilt to match it:

1. On Windows, rebuild with the PyInstaller command in `README.md`.
2. Regenerate `dist/PlayLimit.exe.sha256`.
3. Commit `version.txt` + `dist/PlayLimit.exe` + `dist/PlayLimit.exe.sha256` together.

Bumping `version.txt` ahead of the rebuilt exe makes every client "update" to the
stale bytes already in `dist/`. If you bump `version.txt` in a source-only change,
flag clearly that the exe must be rebuilt before the release is merged/shipped.

## Branching

Work directly on the default branch (`master`). Do **not** create feature branches
or open PRs for routine changes — commit straight to `master`. (This overrides the
general "one branch + one PR per change" workflow for this repo.)

## Commits

Commits are GPG-signed by the maintainer. Prepare the working tree and hand over the
exact `git add` / `git commit` commands — do not commit on their behalf.

## Tests

Run before pushing:

```bash
python3 -m unittest test_basic -v   # core logic
python3 test_matcher.py             # game-detection matcher
```

The dashboard (`monitor/dashboard.html`) has a `?demo=1` mode for a quick visual check.
