# Third-party notices

Huayi's MIT license covers this repository's source code only. The following optional or external components are not vendored or redistributed here and remain subject to their own licenses and terms.

## Apple system frameworks and tools

Huayi uses AppKit, ApplicationServices, AVFoundation, NaturalLanguage, Translation, /usr/bin/say, and /usr/bin/afplay provided by macOS. Their use is governed by Apple's applicable agreements. Translation language resources are downloaded and managed by macOS rather than bundled with Huayi.

## edge-tts

edge-tts is an optional external CLI used only when the user enables Microsoft Neural online speech. It is not installed or bundled by Huayi.

- Project: <https://github.com/rany2/edge-tts>
- License: <https://github.com/rany2/edge-tts/blob/master/LICENSE> (primarily LGPLv3, with the exception described upstream)

Use of the online service is also subject to the relevant service terms and privacy policy.

## Google translation endpoint

The fast path calls an undocumented Google translation endpoint. It is not an official Google Cloud Translation SDK integration and carries no availability guarantee. This repository does not include Google credentials or API keys.
