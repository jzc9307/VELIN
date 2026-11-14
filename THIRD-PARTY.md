# Third-party services and system frameworks

The macOS app bundles a local whisper.cpp speech worker; it bundles no model weights, font, JavaScript package or Cluely resource. The Mac app uses Apple system frameworks (SwiftUI, AppKit, AVFoundation, Speech, ScreenCaptureKit, Carbon, Security and PDFKit) and SF Symbols supplied by macOS. Provider names and marks identify optional integrations; they do not imply endorsement. Original VELIN artwork and source use the repository license.

Optional OpenAI, Anthropic, Google, OpenRouter, Groq and local model services have independent terms, pricing, processing and retention policies. No credentials, accounts, model weights or API credits are provided. Local models must be installed separately and their licenses respected.

Cluely was inspected as a functional reference. No Cluely code, branding, tutorial images, audio tools or private API endpoints are redistributed.

## Lobe Icons provider marks

Six PNG provider marks are copied from `@lobehub/icons-static-png` version 2.6.0 (LobeHub, MIT). Copyright © 2023 LobeHub. The accompanying license is `Resources/Providers/LICENSE`. Package paths and SHA-256 hashes are recorded in `Resources/Providers/provenance.json`. Only these six assets are bundled; no dependency installation or CDN request occurs at runtime. The provider trademarks remain with their respective owners.

Source: https://github.com/lobehub/lobe-icons

## Windows runtime and audio

The self-contained Windows preview bundles Microsoft .NET 10 / Windows Desktop runtime, System.Speech 10.0.14 and NAudio 2.2.1 with transitive NAudio modules from the pinned NuGet lock file. These components use MIT licenses; .NET also includes third-party notices. Their actual package license and runtime notice files are collected into `THIRD-PARTY-NOTICES.txt` in the Windows ZIP. VELIN’s original ICO is derived from its original logo, not a third-party mark. Windows local speech models are provided by the operating system and are not redistributed.

Sources: [dotnet/runtime](https://github.com/dotnet/runtime), [dotnet/winforms](https://github.com/dotnet/winforms), [NAudio](https://github.com/naudio/NAudio).

## Local multilingual speech worker

Both platforms include VELIN’s pipe-based speech worker linked statically with whisper.cpp / ggml v1.9.5, commit d1be6fde11ac6e0407606b4e42fe72d34add8037 (MIT, copyright © 2023–2026 the ggml authors). The pinned source archive is integrity checked; its actual MIT license is bundled as WHISPER-LICENSE.txt. The worker opens no server and receives no provider credentials. Optional multilingual model weights are downloaded separately from ggerganov/whisper.cpp on Hugging Face, checked against upstream hashes, and not redistributed in source/installers. Whisper model licensing is documented by [OpenAI Whisper](https://github.com/openai/whisper/blob/main/LICENSE).

The prepared Windows cross-build also includes Zig runtime/MIT, LLVM libc++/libc++abi/libunwind (Apache 2.0 with LLVM exceptions and their notices), and MinGW-w64 runtime notices in SpeechWorker/SPEECH-RUNTIME-NOTICES.txt. Actual runtime/dependency/VELIN/Whisper notices are embedded in the portable Windows EXE (About → Licenses and notices) and included in the ZIP.
