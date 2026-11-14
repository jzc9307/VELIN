# Listening languages and Malaysian mixed speech

Listen uses **computer audio by default**. It transcribes the interviewer or meeting playing on the same device. The separate mic button adds your own voice only when enabled. Updating from the original two-input default turns the mic off once; later explicit choices are preserved. Existing transcripts remain intact.

## Two speech engines

| Engine | Best use | Processing |
| --- | --- | --- |
| Apple on Mac / Windows Speech on Windows | Fast live words in one selected language | Native recognition; installed language/assets determine support. Mac defaults to requiring on-device processing. |
| Local multilingual · experimental | Malay, Mandarin, English and mixed-language speech | Bundled whisper.cpp worker, downloaded multilingual model, all audio processed locally. No audio uploads. |

A language menu alone does not make the native recognizer multilingual. Select **Audio & Permissions → Local multilingual**, download **Base (142 MiB)** or **Small (466 MiB)**, then save/start Listen. Models download from Hugging Face; they are not included in Git, DMGs or EXEs. Downloads are checked against the upstream model hash. A local multilingual `.bin` can also be selected; English-only `.en` models are rejected. Model files must remain available at their selected path.

The worker keeps its model loaded for the listening session. Speech is decoded after a pause (roughly 0.65 seconds) or in approximately six-second chunks during continuous speech, so there is buffering before words appear. It does not translate deliberately. The language/spelling hint is optional and can help with names, but is not a guarantee. Base uses less memory; Small can improve some errors at greater resource cost. Choose the native engine when lowest live-text delay matters most.

**Malaysian code-switching remains experimental.** Malay, English and Mandarin may be kept in the same output, but accents, dialects, colloquial particles such as “lah,” rapid language changes, names, background music and short phrases can still be wrong or romanized. Editable transcript correction remains available. No guarantee of perfect multilingual transcription, universal Malaysian dialect support or zero latency is made.

Native language choices include Bahasa Melayu (Malaysia), Mandarin, traditional Chinese, Cantonese, English (Malaysia/US/UK), Indonesian and Tamil, plus the existing languages. Actual local support is checked by the OS. A language name in the list does not guarantee an installed recognizer.

## What was checked

A native Swift PCM-to-worker-to-text probe passed without device capture. The Mac worker also decoded the upstream public English JFK fixture, synthetic Malay, synthetic Mandarin, and a combined Malay/Mandarin clip without a network transcription service. Both languages appeared in the combined result, with observed spelling and romanization errors. Base and Small were checked; these are synthetic spot checks, not a benchmark or a real Malaysian call acceptance test. No microphone or private meeting was recorded for these tests. Windows x64 compilation/PE checks do not establish Windows runtime accuracy or device behavior.

The worker exchanges bounded PCM/text over anonymous pipes with VELIN. It opens no network port, receives no API key, and writes no audio recording files. Backlog is bounded; processing failures are reported rather than silently accumulating indefinitely. Stopping Listen terminates its worker. Text already in the session remains local until you explicitly ask AI, export it, or share it yourself. Pausing/stopping can discard a short undecoded audio tail; it does not flush audio to an external service.

## Building the worker

Python 3.12+, CMake 3.22+ and a C++17 compiler are needed. The source is pinned to whisper.cpp **v1.9.5**, commit `d1be6fde11ac6e0407606b4e42fe72d34add8037`, with archive SHA-256 `645445da884df6dbd52b30f82d7be7c01d1767c938714e477e786b88d529e9f4`. Build scripts fetch only that verified source into ignored cache. No audio or model weights are needed to compile.

Mac builds call this automatically:

```bash
python3 scripts/build-speech.py --destination ../work/speech-worker.noindex
```

Native Windows builds call it from `scripts/build-windows.py`. The portable Windows EXE embeds the worker and extracts its exact SHA-256 bytes to the user’s local VELIN Workers directory on first use. The ZIP also includes a separate worker and MIT license. It is not a service or startup item. The optional worker-path override is for trusted local builds.

For a Windows cross-build on an Apple Silicon Mac, install a verified official Zig toolchain, then:

```bash
python3 scripts/build-speech.py --windows --zig /path/to/zig --destination ../work/speech-worker-windows.noindex
python3 scripts/build-windows.py --dotnet /path/to/dotnet
```

The prepared cross-build used official Zig 0.17.1 for aarch64 macOS. Native and cross-build cache paths in a fresh clone are under ignored `dist/work/` rather than the canonical workspace’s outer `work/`. Runtime recognition and microphone/device tests still require the target operating system.

References: [Apple SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber), [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [multilingual model list](https://github.com/ggml-org/whisper.cpp/blob/master/models/README.md), [Whisper license](https://github.com/openai/whisper/blob/main/LICENSE).
