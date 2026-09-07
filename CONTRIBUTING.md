# Contributing to Nudgie

Thanks for helping. Please read this before opening a pull request.

## Licence of contributions

Nudgie is licensed under the PolyForm Shield License 1.0.0. By submitting a contribution (code, docs, artwork, copy) you agree that:

1. You wrote it, or you have the right to contribute it.
2. Your contribution is licensed to the project under the PolyForm Shield License 1.0.0, and
3. You grant Gourav Kakkar a perpetual, worldwide, irrevocable, royalty-free licence to use, modify, sublicense, relicense and sell your contribution as part of Nudgie or derived products.

Point 3 is what keeps Nudgie free for everyone while letting one person, the author, offer paid versions later. If you are not comfortable with that, please open an issue instead of a pull request.

## How to contribute

- Open an issue first for anything bigger than a typo.
- Run `make test` before pushing. Core logic changes need tests in `Tests/NudgieCoreTests`.
- Keep the app free of network calls and third-party dependencies.
- Follow the spec in `docs/superpowers/specs/` for behaviour and the "sticker buddy" look.
- Releases are signed and notarised: see `docs/releasing.md`. You do not need a certificate to build or send a change.
