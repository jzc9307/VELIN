# Speech engines and model downloads

**Listen** captures computer audio into the lower editable question. **Mic** independently dictates into the top question field. Both start inactive; neither automatically sends a chat question.

## Optional Soniox cloud speech

Select **Soniox cloud · mixed languages** in Audio & Permissions, paste a Soniox API key privately into the speech key field, save it, enable the audio-streaming consent switch and save speech settings. Then start Listen or Mic normally. No local model download is needed. Chat-provider keys, including Gemini keys, do not work as Soniox speech keys.

Audio from each started control streams to `wss://stt-rt.soniox.com/transcribe-websocket` using STT v6, English/Malay/Chinese language hints, no translation and endpoint detection. Stopping a control cancels its connection; failures do not reconnect or switch providers automatically. Both controls at once create two speech streams. Soniox charges and processing/retention policies apply. Keys stay in Keychain/Credential Manager; no keys enter settings JSON. Biography, screenshots and chat messages are not sent to the speech service.

The implementation follows the official [streaming API](https://docs.soniox.com/api-reference/stt/websocket-api), [language support](https://docs.soniox.com/stt/concepts/supported-languages), and [models](https://docs.soniox.com/stt/models). Provider support does not establish real-call accuracy; no live Soniox accuracy or billing test has been run without a supplied speech key.

## Offline model state

These downloads are speech-recognition weights, separate from the chat AI you choose. **Download** installs and validates the file once; **Use installed** selects an existing verified file without a network download; **Selected ✓** is disabled. Installation is checked again when this page opens. Corrupt files are not marked installed. Choosing a custom `.bin` remains available.

Base (142 MB) is lightweight but can be very poor for English/Chinese code-switching. Small (466 MB) and Turbo (large-v3-turbo-q5_0, 547 MB) provide larger options with higher memory costs. A model upgrade is not a reliable fix for Malaysian slang. Local output remains editable and experimental. The optional cloud path is available separately, never as a silent fallback.

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
