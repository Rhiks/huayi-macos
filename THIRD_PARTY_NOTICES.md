# Third-party notices

Huayi's MIT license covers this repository's source code only. The following optional or external components are not vendored or redistributed here and remain subject to their own licenses and terms.

## Apple system frameworks and tools

Huayi uses AppKit, ApplicationServices, AVFoundation, NaturalLanguage, /usr/bin/say, and /usr/bin/afplay provided by macOS. Their use is governed by Apple's applicable agreements.

## Ollama

Ollama is an external local model runtime. Huayi communicates only with its loopback API at 127.0.0.1:11434.

- Project: <https://github.com/ollama/ollama>
- License: <https://github.com/ollama/ollama/blob/main/LICENSE>

## TranslateGemma and Gemma

Huayi expects users to download translategemma:12b themselves. No model weights or upstream chat templates are included in this repository; Huayi sends its own text-only translation prompt to the Ollama-packaged model.

- Official model card: <https://huggingface.co/google/translategemma-12b-it>
- Gemma Terms: <https://ai.google.dev/gemma/terms>

The model and weights are not relicensed under Huayi's MIT license.

## edge-tts

edge-tts is an optional external CLI used only when the user enables Microsoft Neural online speech. It is not installed or bundled by Huayi.

- Project: <https://github.com/rany2/edge-tts>
- License: <https://github.com/rany2/edge-tts/blob/master/LICENSE> (primarily LGPLv3, with the exception described upstream)

Use of the online service is also subject to the relevant service terms and privacy policy.

## Google translation endpoint

The fast path calls an undocumented Google translation endpoint. It is not an official Google Cloud Translation SDK integration and carries no availability guarantee. This repository does not include Google credentials or API keys.
