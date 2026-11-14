import SwiftUI

struct UpdateCard: View {
    @ObservedObject var updates: AppUpdates
    var busy: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let release = updates.available {
                HStack(spacing: 6) { Image(systemName: "arrow.down.circle.fill"); Text("Update available").lineLimit(1).fontWeight(.semibold) }.font(.system(size: 11)).foregroundStyle(Ink.mint)
                Text("VELIN " + release.version).font(.system(size: 13, weight: .semibold))
                Text(release.notes).font(.system(size: 10)).foregroundStyle(Ink.muted).lineLimit(3)
                Button { updates.downloadAndRestart() } label: { Text(updates.ready ? "Install & restart" : "Download & restart").font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity) }.buttonStyle(Press(primary: true)).disabled(busy || updates.downloading)
                if busy { Text("Stop audio and finish or clear your draft to restart.").font(.system(size: 9)).foregroundStyle(Ink.muted) }
            } else {
                Button { updates.check() } label: { HStack(spacing: 8) { Image(systemName: updates.checking ? "arrow.triangle.2.circlepath" : "arrow.down.circle"); Text(updates.checking ? "Checking for updates…" : "Check for updates").font(.system(size: 11)); Spacer() } }.buttonStyle(.plain).foregroundStyle(Ink.muted).disabled(updates.checking)
            }
            if let error = updates.failure { Text(error).font(.system(size: 9)).foregroundStyle(Ink.muted).lineLimit(3) }
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(updates.available == nil ? .clear : Ink.mint.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(updates.available == nil ? .clear : Ink.mint.opacity(0.15)))
            .padding(.horizontal, 14).padding(.top, 10)
    }
}
struct UpdatePresentation: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        Group {
            if updates.launching { UpdateLaunchScreen(updates: updates).transition(.opacity) }
            else if updates.presentingDownload { UpdateDownloadScreen(updates: updates).transition(.opacity) }
        }.animation(.easeOut(duration: 0.25), value: updates.launching).animation(.easeOut(duration: 0.2), value: updates.presentingDownload)
    }
}
private struct SignalOrbit: View {
    @ViewState private var rotate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().stroke(Ink.mint.opacity(0.08), lineWidth: 1).frame(width: 128, height: 128)
            Circle().trim(from: 0.02, to: 0.4).stroke(AngularGradient(colors: [Ink.mint.opacity(0.05), Ink.mint, Ink.lilac], center: .center), style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 128, height: 128).rotationEffect(.degrees(rotate && !reduceMotion ? 360 : 0))
            VelinMark().frame(width: 62, height: 62)
        }.frame(width: 150, height: 150).onAppear { withAnimation(reduceMotion ? nil : .linear(duration: 2.5).repeatForever(autoreverses: false)) { rotate = true } }
    }
}
struct UpdateLaunchScreen: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        VStack(spacing: 18) {
            Spacer(); SignalOrbit()
            Text("VELIN").font(.system(size: 27, weight: .semibold)).tracking(7)
            Text("A quieter kind of clarity.").font(.system(size: 13)).foregroundStyle(Ink.muted)
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Finding your latest version…").font(.system(size: 11)).foregroundStyle(Ink.muted) }.padding(.top, 10)
            Button("Continue to VELIN") { updates.launching = false }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Ink.muted.opacity(0.7))
            Spacer(); Text("Checking public GitHub Releases · no account needed").font(.system(size: 10)).foregroundStyle(Ink.muted.opacity(0.6)).padding(.bottom, 28)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Ink.background).foregroundStyle(.white)
    }
}
struct UpdateDownloadScreen: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        VStack(spacing: 18) {
            Spacer(); SignalOrbit()
            Text(updates.ready ? "Ready for your next moment." : "A little upgrade. More clarity.").font(.system(size: 24, weight: .semibold))
            Text(updates.status).font(.system(size: 13)).foregroundStyle(Ink.muted)
            VStack(spacing: 8) { GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.08)); Capsule().fill(LinearGradient(colors: [Ink.mint, Ink.lilac], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * max(0, min(1, updates.progress))) } }.frame(height: 5).accessibilityLabel("Update download progress").accessibilityValue(String(Int(updates.progress * 100)) + "%"); HStack { Text(updates.progress >= 1 ? "Verifying before installation" : "Downloading securely from GitHub"); Spacer(); Text(updates.progress, format: .percent.precision(.fractionLength(0))).monospacedDigit() }.font(.system(size: 10)).foregroundStyle(Ink.muted) }.frame(maxWidth: 340).padding(.vertical, 8)
            Text("Your keys, settings, models and conversations stay here.").font(.system(size: 11)).foregroundStyle(Ink.muted)
            if let failure = updates.failure { Text(failure).font(.system(size: 12)).foregroundStyle(Ink.lilac).multilineTextAlignment(.center).frame(maxWidth: 400) }
            HStack {
                if updates.downloading && !updates.installed { Button("Cancel download") { updates.cancelDownload() }.buttonStyle(Press()) }
                else if !updates.installed { Button("Back to VELIN") { updates.presentingDownload = false }.buttonStyle(Press()); if updates.ready { Button("Install & restart") { updates.downloadAndRestart() }.buttonStyle(Press(primary: true)) } }
            }
            Spacer(); Text("VELIN " + (updates.available?.version ?? updates.currentVersion)).font(.system(size: 10)).foregroundStyle(Ink.muted.opacity(0.6)).padding(.bottom, 28)
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Ink.background).foregroundStyle(.white)
    }
}

struct AboutUpdateStatus: View {
    @ObservedObject var updates: AppUpdates
    var busy: Bool
    var body: some View {
        Card { VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Installed version").font(.system(size: 11)).foregroundStyle(Ink.muted)
                    Text("VELIN " + updates.currentVersion).font(.system(size: 23, weight: .semibold))
                    Text("Build " + String(updates.currentBuild)).font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
                Spacer()
                Button { updates.check() } label: { Label(updates.checking ? "Checking…" : "Refresh", systemImage: "arrow.clockwise").lineLimit(1) }.buttonStyle(Press()).disabled(updates.checking || updates.downloading || updates.ready)
            }
            Divider()
            HStack(alignment: .top, spacing: 10) {
                if updates.checking { ProgressView().controlSize(.small) }
                else { Image(systemName: updates.available == nil ? "info.circle" : "arrow.down.circle.fill").foregroundStyle(Ink.mint) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(updates.versionStatus).font(.system(size: 13, weight: .medium))
                    if let latest = updates.latestPublishedVersion { Text("Latest on GitHub: v" + latest + (updates.latestPublishedBuild.map { " · Build " + String($0) } ?? "")).font(.system(size: 11)).foregroundStyle(Ink.muted) }
                    if let date = updates.lastChecked { Text("Last checked " + date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(Ink.muted) }
                }
            }
            if let failure = updates.failure { Text(failure).font(.system(size: 11)).foregroundStyle(Ink.lilac).fixedSize(horizontal: false, vertical: true) }
            if updates.available != nil {
                Button(updates.ready ? "Install & restart" : "Download & restart") { updates.downloadAndRestart() }.buttonStyle(Press(primary: true)).disabled(busy || updates.downloading)
                if busy { Text("Stop audio and finish or clear your draft before restarting.").font(.system(size: 10)).foregroundStyle(Ink.muted) }
            }
            Link("View release history on GitHub ↗", destination: URL(string: "https://github.com/jzc9307/VELIN/releases")!).font(.system(size: 11)).foregroundStyle(Ink.mint)
        } }
    }
}
