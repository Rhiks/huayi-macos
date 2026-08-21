# Security Policy

## Supported version

Only the latest commit on the default branch is supported during the preview stage.

## Reporting a vulnerability

Please do not open a public issue for a vulnerability that could expose selected text, clipboard contents, local files, or network credentials.

Use GitHub's private vulnerability reporting for this repository:

**Security → Advisories → Report a vulnerability**

Include the affected commit, macOS version, reproduction steps, and the smallest non-sensitive log or sample needed to demonstrate the issue. Do not attach real clipboard contents, tokens, private documents, or personal data.

## Scope

Useful reports include:

- selected text appearing in logs, process arguments, URLs, caches, or files;
- clipboard restoration overwriting newer user data;
- non-local access to the Ollama integration;
- focus-stealing or stale result races that expose a previous selection;
- unsafe install, update, or rollback behavior.

Third-party service availability and model translation quality are not security vulnerabilities unless Huayi handles data contrary to [PRIVACY.md](PRIVACY.md).
