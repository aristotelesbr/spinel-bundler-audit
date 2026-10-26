# Results: 2026-10-26-v0.1.0

Method: [bench/README.md](../../README.md).

## Machine

| Item | Value |
|---|---|
| date | 2026-10-26 08:35:30 -0300 |
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
| load_average | 2.37 2.88 2.61 |

Load average before → after each round: 1: 2.37 2.88 2.61 → 1.66 2.57 2.51; 2: 1.66 2.57 2.51 → 1.62 2.35 2.43; 3: 1.62 2.35 2.43 → 1.89 2.27 2.39

## Time

Median wall time (interquartile range) over all rounds; the ratio's 95% confidence interval is a bootstrap of the medians.

| Case | bundler-audit | spinel-bundler-audit | ratio | 95% CI | per-round medians |
|---|---:|---:|---:|---|---|
| clean | 94.9 ms (94.0–97.9) | 3.7 ms (3.6–3.9) | 25.6x | 25.1–26.0x | 1: 93.8 / 3.7; 2: 94.6 / 3.8; 3: 96.6 / 3.7 |
| mastodon | 151.6 ms (149.8–155.1) | 12.6 ms (12.4–12.8) | 12.1x | 12.0–12.2x | 1: 149.3 / 12.4; 2: 151.6 / 12.5; 3: 155.1 / 12.7 |
| discourse | 174.9 ms (170.8–178.3) | 16.9 ms (16.7–17.3) | 10.3x | 10.2–10.5x | 1: 170.5 / 16.7; 2: 174.9 / 16.8; 3: 178.1 / 17.3 |
| forem | 173.8 ms (169.8–178.8) | 16.4 ms (16.3–17.0) | 10.6x | 10.5–10.7x | 1: 169.3 / 16.3; 2: 173.8 / 16.4; 3: 178.2 / 17.1 |
| synthetic | 273.4 ms (269.7–277.5) | 40.4 ms (39.4–40.9) | 6.8x | 6.7–6.8x | 1: 264.5 / 40.4; 2: 271.1 / 39.6; 3: 277.3 / 40.8 |
| forem-json | 178.9 ms (175.5–180.6) | 17.0 ms (16.7–17.3) | 10.5x | 10.4–10.6x | 1: 178.3 / 17.1; 2: 176.0 / 16.8; 3: 180.7 / 17.2 |

**first-run:** spinel-bundler-audit on mastodon with the index removed before every run: 118.6 ms (116.4–119.4).

## Peak memory and instructions (medians)

| Case | bundler-audit | spinel-bundler-audit | instructions, bundler-audit | instructions, spinel-bundler-audit |
|---|---:|---:|---:|---:|
| clean | 27.7 MiB | 4.3 MiB | 1173 M | 23 M |
| mastodon | 38.2 MiB | 13.8 MiB | 2014 M | 180 M |
| discourse | 38.4 MiB | 12.7 MiB | 2374 M | 257 M |
| forem | 39.8 MiB | 15.4 MiB | 2326 M | 246 M |
| synthetic | 47.0 MiB | 42.2 MiB | 3680 M | 600 M |
| forem-json | 40.1 MiB | 15.6 MiB | 2336 M | 244 M |
