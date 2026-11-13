# Third-party services and system frameworks

The macOS app bundles no third-party runtime executable, model, font, JavaScript package or Cluely resource. The Mac app uses Apple system frameworks (SwiftUI, AppKit, AVFoundation, Speech, ScreenCaptureKit, Carbon, Security and PDFKit) and SF Symbols supplied by macOS. Provider names and marks identify optional integrations; they do not imply endorsement. Original VELIN artwork and source use the repository license.

Optional OpenAI, Anthropic, Google, OpenRouter, Groq and local model services have independent terms, pricing, processing and retention policies. No credentials, accounts, model weights or API credits are provided. Local models must be installed separately and their licenses respected.

Cluely was inspected as a functional reference. No Cluely code, branding, tutorial images, audio tools or private API endpoints are redistributed.

## Lobe Icons provider marks

Six PNG provider marks are copied from `@lobehub/icons-static-png` version 2.6.0 (LobeHub, MIT). Copyright © 2023 LobeHub. The accompanying license is `Resources/Providers/LICENSE`. Package paths and SHA-256 hashes are recorded in `Resources/Providers/provenance.json`. Only these six assets are bundled; no dependency installation or CDN request occurs at runtime. The provider trademarks remain with their respective owners.

Source: https://github.com/lobehub/lobe-icons

## Windows runtime and audio

The self-contained Windows preview bundles Microsoft .NET 10 / Windows Desktop runtime, System.Speech 10.0.14 and NAudio 2.2.1 with transitive NAudio modules from the pinned NuGet lock file. These components use MIT licenses; .NET also includes third-party notices. Their actual package license and runtime notice files are collected into `THIRD-PARTY-NOTICES.txt` in the Windows ZIP. VELIN’s original ICO is derived from its original logo, not a third-party mark. Windows local speech models are provided by the operating system and are not redistributed.

Sources: [dotnet/runtime](https://github.com/dotnet/runtime), [dotnet/winforms](https://github.com/dotnet/winforms), [NAudio](https://github.com/naudio/NAudio).
