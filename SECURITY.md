# Security

## Reporting a vulnerability in spinel-bundler-audit

Report it privately through
[GitHub's vulnerability reporting](https://github.com/aristotelesbr/spinel-bundler-audit/security/advisories/new)
rather than in a public issue. Include the version (`spinel-bundler-audit
version`), your platform and the steps to reproduce.

This includes the tool reporting a lockfile as clean when bundler-audit
0.9.3 finds an advisory in it with the same database: a missed
vulnerability is a security problem here.

## Vulnerabilities in gems

spinel-bundler-audit reports advisories from
[ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db). A new or
wrong advisory for a gem goes there, not here.

## Supported versions

Fixes go into the latest release.
