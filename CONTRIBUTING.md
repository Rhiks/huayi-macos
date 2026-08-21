# Contributing

Thanks for helping improve Huayi.

## Before opening a pull request

1. Keep the app native AppKit/Swift unless a change clearly requires another dependency.
2. Never log selected text, translated text, clipboard contents, tokens, or local absolute paths.
3. Do not add an online service without documenting its data flow in README.md and PRIVACY.md.
4. Preserve the non-activating panel behavior and cancellation generations for capture, translation, and speech.
5. Run:

~~~bash
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Huayi"
"$BIN" --filter-self-test
"$BIN" --routing-self-test
"$BIN" --clipboard-self-test
~~~

If you change Ollama streaming and have translategemma:12b installed, also run:

~~~bash
"$BIN" --ai-self-test
~~~

## Pull requests

Keep each pull request focused. Explain user-visible behavior changes, privacy impact, and the exact verification performed. Use synthetic text in tests and screenshots.
