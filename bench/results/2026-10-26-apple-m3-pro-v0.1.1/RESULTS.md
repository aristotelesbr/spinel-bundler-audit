# Results: 2026-10-26-v0.1.1

Method: [bench/README.md](../../README.md).

## Machine

| Item | Value |
|---|---|
| date | 2026-10-26 08:39:08 -0300 |
| cpu | Apple M3 Pro |
| memory_gib | 18 |
| cores | 11 |
| os | macOS 27.0.1 |
| platform | macos-arm64 |
| ruby | ruby 3.4.1 (2024-12-25 revision 48d4efcb85) +PRISM [arm64-darwin23] |
| bundler_audit | bundler-audit 0.9.3 |
| spinel_bundler_audit | spinel-bundler-audit 0.1.1 |
| binary_sha256 | c60c8fd48a4403a61850d547bbf66da513308aa95fb33a4158b33f5a87b8c245 |
| hyperfine | hyperfine 2.0.0 |
| ruby_advisory_db | 03da937a9e171e3fedebde6620e203559b7a60c0 |
| advisories | 1269 |
| apps | mastodon mastodon/mastodon@f045f6b43fa813564ddeaeffd8d7736e0ef19835, discourse discourse/discourse@568a006ad8f5d8ae59af64edbd33a151d36fdbde, forem forem/forem@88f91b40d4e2917756f5e56b72577e727da49995 |
| lockfile_sha256 | clean 6246797d80e97034a4802311d7cc991b45c6e0c9e2262411a9af4d290a4ef4d8, mastodon fc991791fd5372091a41491ada1b5d33e32bbe7d51ea79c7f82ccae792cfc108, discourse f57e9309ef79523816a2283b89a0174f160c7b7dfa6edaebe86b89f118c89db9, forem 218755f682ca6002b9c93dcb9d06f353254c136394e05d841281ffa8b97c7991, synthetic b40a759a9e0f73a2f1e0395225acd085f22dda9b65ca638f83ee36f72874815a, forem-json 218755f682ca6002b9c93dcb9d06f353254c136394e05d841281ffa8b97c7991 |
| load_average | 1.82 2.25 2.39 |

Load average before → after each round: 1: 1.82 2.25 2.39 → 1.55 2.09 2.31; 2: 1.55 2.09 2.31 → 1.54 1.96 2.25; 3: 1.54 1.96 2.25 → 2.45 2.28 2.35

## Time

Median wall time (interquartile range) over all rounds; the ratio's 95% confidence interval is a bootstrap of the medians.

| Case | bundler-audit | spinel-bundler-audit | ratio | 95% CI | per-round medians |
|---|---:|---:|---:|---|---|
| clean | 98.7 ms (97.4–99.5) | 3.6 ms (3.0–3.8) | 27.3x | 27.0–27.6x | 1: 97.2 / 3.7; 2: 98.6 / 3.7; 3: 99.8 / 2.6 |
| mastodon | 157.8 ms (156.9–158.8) | 8.1 ms (8.0–8.2) | 19.5x | 19.5–19.6x | 1: 157.3 / 8.0; 2: 157.5 / 8.1; 3: 158.8 / 8.2 |
| discourse | 180.5 ms (179.7–181.3) | 9.2 ms (9.0–9.3) | 19.6x | 19.5–19.8x | 1: 179.7 / 9.1; 2: 180.1 / 9.2; 3: 181.4 / 9.3 |
| forem | 179.1 ms (178.3–179.9) | 10.5 ms (10.4–10.6) | 17.1x | 16.9–17.1x | 1: 178.3 / 10.4; 2: 178.9 / 10.4; 3: 179.9 / 10.6 |
| synthetic | 278.0 ms (277.1–278.8) | 38.1 ms (37.6–38.4) | 7.3x | 7.3–7.3x | 1: 277.3 / 37.6; 2: 277.6 / 38.0; 3: 278.6 / 38.5 |
| forem-json | 180.7 ms (180.1–181.1) | 10.7 ms (10.6–10.8) | 16.8x | 16.8–16.9x | 1: 180.2 / 10.7; 2: 180.6 / 10.7; 3: 181.0 / 10.7 |

**first-run:** spinel-bundler-audit on mastodon with the index removed before every run: 115.8 ms (115.5–116.1).

## Peak memory and instructions (medians)

| Case | bundler-audit | spinel-bundler-audit | instructions, bundler-audit | instructions, spinel-bundler-audit |
|---|---:|---:|---:|---:|
| clean | 27.8 MiB | 4.4 MiB | 1173 M | 23 M |
| mastodon | 38.2 MiB | 8.7 MiB | 2014 M | 106 M |
| discourse | 38.3 MiB | 9.5 MiB | 2374 M | 127 M |
| forem | 39.8 MiB | 9.2 MiB | 2327 M | 147 M |
| synthetic | 47.0 MiB | 32.9 MiB | 3681 M | 562 M |
| forem-json | 40.1 MiB | 10.0 MiB | 2336 M | 145 M |
