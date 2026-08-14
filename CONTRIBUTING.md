# Contributing

Thanks for helping improve DSH Island. Please keep the app small, read-only, and honest about progress.

## Before opening a pull request

1. Open an issue for a material feature or protocol change so its scope can be agreed first.
2. Keep wire decoding in `DSHIslandCore` and presentation decisions in the state engine or app target, as described in `docs/architecture.md`.
3. Add tests for state transitions, privacy behavior, or protocol fields that change.
4. Update the affected design or user documentation.
5. Run:

```sh
swift test
xcrun swift-format lint --recursive Sources Tests Package.swift
swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
./scripts/build-app.sh
codesign --verify --deep --strict "dist/DSH Island.app"
```

Do not add telemetry, credentials, model-facing tools, fabricated progress, or write access to DSH without an explicit product-design discussion.
