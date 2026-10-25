# Changelog

## Unreleased

- A check decodes the URL, title, description and scores of an advisory
  only when the report shows it, so it no longer decodes advisories a
  report leaves out. The index format changes; an index written by 0.1.0
  is rebuilt on the next check.

## 0.1.0 (2026-10-25)

- First release: `check`, `update`, `download`, `stats` and `version`,
  compatible with bundler-audit 0.9.3.
- Advisory index bound to the database commit.
- Prebuilt binaries for Linux x86_64, Linux arm64 and macOS arm64, and
  `install.sh` to install them in one line.
