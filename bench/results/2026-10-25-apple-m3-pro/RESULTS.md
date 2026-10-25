# Results: 2026-10-25-apple-m3-pro

Method: [bench/README.md](../../README.md).

## Machine

| Item | Value |
|---|---|
| date | 2026-10-25 11:22:47 -0300 |
| cpu | Apple M3 Pro |
| memory_gib | 18 |
| cores | 11 |
| os | macOS 27.0.1 |
| platform | macos-arm64 |
| ruby | ruby 3.4.1 (2024-12-25 revision 48d4efcb85) +PRISM [arm64-darwin23] |
| bundler_audit | bundler-audit 0.9.3 |
| spinel_bundler_audit | spinel-bundler-audit 0.1.0 |
| binary_sha256 | 831bf68e39b73a456adb9e6db2ed6b75be05467b1372d411d864eed8162ea095 |
| hyperfine | hyperfine 2.0.0 |
| ruby_advisory_db | 03da937a9e171e3fedebde6620e203559b7a60c0 |
| advisories | 1269 |
| apps | mastodon mastodon/mastodon@f045f6b43fa813564ddeaeffd8d7736e0ef19835, discourse discourse/discourse@568a006ad8f5d8ae59af64edbd33a151d36fdbde, forem forem/forem@88f91b40d4e2917756f5e56b72577e727da49995 |
| lockfile_sha256 | clean 6246797d80e97034a4802311d7cc991b45c6e0c9e2262411a9af4d290a4ef4d8, mastodon fc991791fd5372091a41491ada1b5d33e32bbe7d51ea79c7f82ccae792cfc108, discourse f57e9309ef79523816a2283b89a0174f160c7b7dfa6edaebe86b89f118c89db9, forem 218755f682ca6002b9c93dcb9d06f353254c136394e05d841281ffa8b97c7991, synthetic b40a759a9e0f73a2f1e0395225acd085f22dda9b65ca638f83ee36f72874815a, forem-json 218755f682ca6002b9c93dcb9d06f353254c136394e05d841281ffa8b97c7991 |
| load_average | 1.69 2.42 2.65 |

Load average before → after each round: 1: 2.32 2.29 2.52 → 1.68 2.10 2.43; 2: 1.68 2.10 2.43 → 1.31 1.90 2.32; 3: 1.31 1.90 2.32 → 1.37 1.81 2.25

## Time

Median wall time (interquartile range) over all rounds; the ratio's 95% confidence interval is a bootstrap of the medians.

| Case | bundler-audit | spinel-bundler-audit | ratio | 95% CI | per-round medians |
|---|---:|---:|---:|---|---|
| clean | 98.8 ms (97.5–99.7) | 3.5 ms (3.4–3.6) | 28.2x | 28.0–28.5x | 1: 97.2 / 3.6; 2: 98.6 / 3.5; 3: 99.7 / 3.4 |
| mastodon | 158.4 ms (156.7–159.0) | 12.9 ms (12.5–13.0) | 12.3x | 12.2–12.4x | 1: 151.7 / 12.5; 2: 158.4 / 12.9; 3: 158.9 / 13.0 |
| discourse | 181.2 ms (180.4–181.9) | 17.1 ms (16.9–17.2) | 10.6x | 10.6–10.6x | 1: 175.3 / 17.0; 2: 181.4 / 17.1; 3: 181.7 / 17.2 |
| forem | 179.9 ms (178.4–180.4) | 16.9 ms (16.5–17.0) | 10.6x | 10.6–10.7x | 1: 175.7 / 16.7; 2: 180.1 / 16.6; 3: 180.3 / 17.0 |
| synthetic | 279.4 ms (278.3–280.2) | 40.8 ms (40.6–41.0) | 6.8x | 6.8–6.9x | 1: 276.0 / 40.6; 2: 279.7 / 40.8; 3: 280.1 / 40.9 |
| forem-json | 181.6 ms (180.9–182.0) | 17.3 ms (17.2–17.5) | 10.5x | 10.5–10.5x | 1: 180.7 / 17.4; 2: 181.7 / 17.3; 3: 181.7 / 17.3 |

**first-run:** spinel-bundler-audit on mastodon with the index removed before every run: 120.1 ms (119.8–120.4).

## Peak memory and instructions (medians)

| Case | bundler-audit | spinel-bundler-audit | instructions, bundler-audit | instructions, spinel-bundler-audit |
|---|---:|---:|---:|---:|
| clean | 27.8 MiB | 4.3 MiB | 1173 M | 23 M |
| mastodon | 38.2 MiB | 13.7 MiB | 2013 M | 179 M |
| discourse | 38.4 MiB | 12.9 MiB | 2373 M | 250 M |
| forem | 39.9 MiB | 15.4 MiB | 2324 M | 246 M |
| synthetic | 47.0 MiB | 42.2 MiB | 3677 M | 599 M |
| forem-json | 40.1 MiB | 15.6 MiB | 2335 M | 244 M |
