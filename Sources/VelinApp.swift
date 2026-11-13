import AppKit
import SwiftUI
import Carbon
import Combine

final class AssistantPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var onDismiss: () -> Void = {}
    override func cancelOperation(_ sender: Any?) { onDismiss() }
}

struct OverlayView: View {
    @ObservedObject var model: AppModel
    var close: () -> Void
    var latestAnswer: ChatMessage? { model.session.messages.last(where: { $0.role == "assistant" }) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                TextField("Ask anything about your screen or conversation…", text: $model.prompt, axis: .vertical)
                    .textFieldStyle(.plain).font(.system(size: 14, weight: .medium)).lineLimit(1...2)
                    .onSubmit { model.ask() }
                    .accessibilityLabel("Ask VELIN")
                Button { if model.generating { model.cancelAnswer() } else { model.ask() } } label: {
                    Image(systemName: model.generating ? "stop.fill" : "return").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.background).frame(width: 34, height: 34).background(Ink.mint, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(IconPress()).help(model.generating ? "Stop response" : "Ask VELIN")
            }.padding(.horizontal, 18).padding(.top, 15).padding(.bottom, 13)
            Rectangle().fill(Ink.line).frame(height: 1)
            HStack(spacing: 7) {
                VelinMark().frame(width: 21, height: 21).help("Drag here to move VELIN")
                Button { model.capture() } label: { Image(systemName: model.pendingImage == nil ? "photo" : "photo.fill").font(.system(size: 14)).foregroundStyle(model.pendingImage == nil ? Ink.muted : Ink.mint) }.buttonStyle(IconPress()).help("Attach screenshot · ⌃⌥S").disabled(model.generating)
                Button { model.toggleListening() } label: { HStack(spacing: 5) { Image(systemName: "waveform").font(.system(size: 14)); Text(model.recording ? clockText(model.elapsed) : "Listen").font(.system(size: 10)) }.foregroundStyle(model.recording ? Ink.mint : Ink.muted) }.buttonStyle(IconPress()).disabled(model.startingAudio).help("Start / stop listening · ⌃⌥L")
                Menu { ForEach(AssistantMode.allCases) { mode in Button(mode.rawValue) { model.config.mode = mode; model.session.mode = mode; model.saveConfig() } } } label: { Label(model.config.mode.rawValue, systemImage: "square.grid.2x2").font(.system(size: 10)) }.menuStyle(.borderlessButton).fixedSize()
                Menu { ForEach(model.config.profiles) { profile in Button("\(profile.name) · \(profile.provider.rawValue)") { model.config.activeProfileID = profile.id; model.saveConfig() } }; Divider(); Button("AI Connections…") { model.page = "AI Connections"; model.openMain() } } label: { Text(model.activeProfile?.provider.rawValue ?? "Connect AI").font(.system(size: 10)) }.menuStyle(.borderlessButton).fixedSize()
                Spacer(minLength: 0)
                Button("History") { model.page = "History"; model.openMain() }.font(.system(size: 10, weight: .medium)).buttonStyle(IconPress()).help("Open session history")
                Button { model.page = "AI Connections"; model.openMain() } label: { Image(systemName: "gearshape").font(.system(size: 12)) }.buttonStyle(IconPress()).help("AI settings")
                if latestAnswer != nil || model.generating {
                    Button { model.overlayExpanded.toggle() } label: { Image(systemName: model.overlayExpanded ? "chevron.up" : "chevron.down").font(.system(size: 12)) }.buttonStyle(IconPress()).help(model.overlayExpanded ? "Collapse answer" : "Show latest answer")
                }
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 11)) }.buttonStyle(IconPress()).help("Hide assistant · ⌃⌥Space")
            }.foregroundStyle(Ink.muted).padding(.horizontal, 18).frame(height: 42)
            if let image = model.pendingImage, let nsImage = NSImage(data: image) {
                Rectangle().fill(Ink.line).frame(height: 1)
                HStack(spacing: 12) {
                    Image(nsImage: nsImage).resizable().scaledToFit().frame(width: 94, height: 58).clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 5) { Text("Screenshot attached").font(.system(size: 11, weight: .semibold)); Text("Sent with your next question to \(model.endpointHost).").font(.system(size: 9)).foregroundStyle(Ink.muted) }
                    Spacer(); Button { model.pendingImage = nil } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(Ink.muted) }.buttonStyle(IconPress()).help("Remove screenshot")
                }.padding(12)
            }
            if model.overlayExpanded {
                Rectangle().fill(Ink.line).frame(height: 1)
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("VELIN").font(.system(size: 9, weight: .bold)).tracking(1.7).foregroundStyle(Ink.mint); if model.generating { ProgressView().controlSize(.mini) }; Spacer(); if let answer = latestAnswer, !answer.text.isEmpty { Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(answer.text, forType: .string); model.notice = "Copied response." } label: { Label("Copy", systemImage: "doc.on.doc").font(.system(size: 10)) }.buttonStyle(IconPress()).foregroundStyle(Ink.muted) } }
                    ScrollViewReader { proxy in
                        ScrollView { VStack(alignment: .leading, spacing: 0) {
                            Text(.init(latestAnswer?.text.isEmpty == false ? latestAnswer!.text : "Thinking with your selected AI…")).font(.system(size: 14)).lineSpacing(6).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            Color.clear.frame(height: 1).id("answer-bottom")
                        } }.onChange(of: latestAnswer?.text) { _, _ in proxy.scrollTo("answer-bottom", anchor: .bottom) }
                    }
                }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error = model.error { HStack { Image(systemName: "exclamationmark.circle"); Text(error).lineLimit(2).truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading); Button("Dismiss") { model.error = nil }.buttonStyle(IconPress()) }.font(.system(size: 10)).foregroundStyle(Color(hex: 0xF1BA9E)).padding(10).background(.white.opacity(0.025)) }
        }.background(Ink.background.opacity(model.config.overlayOpacity)).clipShape(RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(LinearGradient(colors: [Ink.mint.opacity(0.3), .white.opacity(0.08), Ink.lilac.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .foregroundStyle(.white.opacity(0.95)).preferredColorScheme(.dark).onExitCommand { close() }
    }
}

final class Hotkeys {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var movementRefs: [EventHotKeyRef] = []
    var action: (UInt32) -> Void = { _ in }
    func register() -> [String] {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            let hotkeys = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { hotkeys.action(key.id) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        var failed: [String] = []
        let codes: [(UInt32, UInt32, String)] = [(1, UInt32(kVK_Space), "⌃⌥Space"), (2, UInt32(kVK_Return), "⌃⌥Return"), (3, UInt32(kVK_ANSI_L), "⌃⌥L"), (4, UInt32(kVK_ANSI_S), "⌃⌥S")]
        for (id, code, name) in codes {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(code, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x56454C4E, id: id), GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) } else { failed.append(name) }
        }
        return failed
    }
    func registerMovement() -> [String] {
        guard movementRefs.isEmpty else { return [] }
        var failed: [String] = []
        for (id, code, name) in [(UInt32(5), UInt32(kVK_LeftArrow), "⌘←"), (6, UInt32(kVK_RightArrow), "⌘→"), (7, UInt32(kVK_UpArrow), "⌘↑"), (8, UInt32(kVK_DownArrow), "⌘↓")] {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(code, UInt32(cmdKey), EventHotKeyID(signature: 0x56454C4E, id: id), GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { movementRefs.append(ref) } else { failed.append(name) }
        }
        return failed
    }
    func releaseMovement() { for ref in movementRefs { UnregisterEventHotKey(ref) }; movementRefs.removeAll() }
    deinit { for ref in refs + movementRefs { UnregisterEventHotKey(ref) }; if let handler { RemoveEventHandler(handler) } }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = AppModel()
    var window: NSWindow!
    var panel: AssistantPanel!
    var status: NSStatusItem!
    let hotkeys = Hotkeys()
    var permissionTimer: Timer?
    var terminating = false
    private var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1220, height: 840), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "VELIN"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 0.047, green: 0.063, blue: 0.078, alpha: 1)
        window.minSize = NSSize(width: 1050, height: 720); window.delegate = self
        let workspaceHost = NSHostingView(rootView: MainView(model: model).ignoresSafeArea(.container, edges: .top).background(Ink.sidebar))
        workspaceHost.sizingOptions = []
        workspaceHost.autoresizingMask = [.width, .height]
        window.contentView = workspaceHost
        window.setFrameAutosaveName("VELINWorkspace"); window.center()
        panel = AssistantPanel(contentRect: NSRect(x: 0, y: 0, width: 660, height: 120), styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.onDismiss = { [weak self] in self?.hidePanel() }; panel.title = "VELIN Assistant"; panel.isFloatingPanel = true; panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.minSize = NSSize(width: 540, height: 118); panel.maxSize = NSSize(width: 900, height: 760)
        panel.setFrameAutosaveName("VELINAssistant")
        if let screen = NSScreen.main { panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 330, y: screen.visibleFrame.maxY - 158)) }
        let panelHost = NSHostingView(rootView: OverlayView(model: model, close: { [weak self] in self?.hidePanel() }).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top))
        panelHost.sizingOptions = []
        panelHost.autoresizingMask = [.width, .height]
        panel.contentView = panelHost
        model.openMain = { [weak self] in self?.showMain() }
        model.showOverlay = { [weak self] in self?.showPanel() }
        model.toggleOverlay = { [weak self] in self?.togglePanel() }
        model.updateProtection = { [weak self] in self?.applyProtection() }
        model.$overlayExpanded.combineLatest(model.$pendingImage, model.$error).sink { [weak self] _, _, _ in
            DispatchQueue.main.async { self?.resizePanel() }
        }.store(in: &subscriptions)
        applyProtection(); installMenus()
        hotkeys.action = { [weak self] id in
            guard let self else { return }
            switch id {
            case 1: self.togglePanel()
            case 2: self.showPanel(); self.model.ask()
            case 3: self.model.toggleListening()
            case 4: self.model.capture()
            case 5: self.movePanel(dx: -36, dy: 0)
            case 6: self.movePanel(dx: 36, dy: 0)
            case 7: self.movePanel(dx: 0, dy: 36)
            case 8: self.movePanel(dx: 0, dy: -36)
            default: break
            }
        }
        let conflicts = hotkeys.register()
        if !conflicts.isEmpty { model.notice = "Shortcut unavailable: \(conflicts.joined(separator: ", ")). Use the menu bar controls." }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in Task { @MainActor in self?.model.refreshPermissions() } }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func resizePanel() {
        guard panel != nil else { return }
        let old = panel.frame
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(660, screen.width - 32)
        let targetHeight = min(CGFloat(120 + (model.overlayExpanded ? 300 : 0) + (model.pendingImage != nil ? 84 : 0) + (model.error != nil ? 56 : 0)), screen.height - 32)
        let x = min(max(old.minX, screen.minX + 16), screen.maxX - width - 16)
        let y = min(max(old.maxY - targetHeight, screen.minY + 16), screen.maxY - targetHeight - 16)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: targetHeight), display: true, animate: false)
    }
    func applyProtection() { guard window != nil, panel != nil else { return }; window.sharingType = model.config.captureProtection ? .none : .readOnly; panel.sharingType = model.config.captureProtection ? .none : .readOnly }
    func showMain() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func showPanel() {
        panel.orderFrontRegardless()
        let conflicts = hotkeys.registerMovement()
        if !conflicts.isEmpty { model.notice = "Move shortcut unavailable: \(conflicts.joined(separator: ", ")). Drag the VELIN emblem instead." }
    }
    func hidePanel() { panel.orderOut(nil); hotkeys.releaseMovement() }
    func togglePanel() { if panel.isVisible { hidePanel() } else { showPanel() } }
    func movePanel(dx: CGFloat, dy: CGFloat) {
        guard panel.isVisible, let first = NSScreen.screens.first else { return }
        let desktop = NSScreen.screens.dropFirst().reduce(first.visibleFrame) { $0.union($1.visibleFrame) }
        var frame = panel.frame.offsetBy(dx: dx, dy: dy)
        frame.origin.x = min(max(frame.minX, desktop.minX), desktop.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, desktop.minY), desktop.maxY - frame.height)
        guard NSScreen.screens.contains(where: { let overlap = $0.visibleFrame.intersection(frame); return overlap.width >= 80 && overlap.height >= 50 }) else { return }
        panel.setFrame(frame, display: true)
    }
    func installMenus() {
        let main = NSMenu(), appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About VELIN", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "AI Connections…", action: #selector(connections), keyEquivalent: ",")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Hide VELIN", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit VELIN", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); let edit = NSMenu(title: "Edit"); editItem.submenu = edit; main.addItem(editItem)
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] { edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: ""); let menu = NSMenu(title: "Window"); windowItem.submenu = menu; main.addItem(windowItem)
        menu.addItem(withTitle: "Workspace", action: #selector(workspace), keyEquivalent: "0")
        menu.addItem(withTitle: "Show / Hide Assistant", action: #selector(assistant), keyEquivalent: "")
        NSApp.mainMenu = main; NSApp.windowsMenu = menu
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = menuBarMark()
        status.button?.toolTip = "VELIN"
        let tray = NSMenu(); tray.delegate = self; status.menu = tray; menuNeedsUpdate(tray)
    }
    func menuBarMark() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor.black.setStroke(); NSColor.black.setFill()
            let a = NSBezierPath(); a.move(to: NSPoint(x: 2.5, y: 15)); a.curve(to: NSPoint(x: 10, y: 3), controlPoint1: NSPoint(x: 3.5, y: 8), controlPoint2: NSPoint(x: 7, y: 5)); a.lineWidth = 2.6; a.lineCapStyle = .round; a.stroke()
            let b = NSBezierPath(); b.move(to: NSPoint(x: 10, y: 3)); b.curve(to: NSPoint(x: 18, y: 16), controlPoint1: NSPoint(x: 12, y: 10), controlPoint2: NSPoint(x: 15.5, y: 14.5)); b.lineWidth = 2.6; b.lineCapStyle = .round; b.stroke()
            NSBezierPath(ovalIn: NSRect(x: 9, y: 15, width: 2.2, height: 2.2)).fill(); return true
        }; image.isTemplate = true; image.accessibilityDescription = "VELIN"; return image
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func item(_ title: String, _ action: Selector) { let row = menu.addItem(withTitle: title, action: action, keyEquivalent: ""); row.target = self }
        item(model.recording ? "Stop Listening" : "Start Listening", #selector(listen))
        item(panel.isVisible ? "Hide VELIN" : "Show VELIN", #selector(assistant))
        item(model.config.captureProtection ? "Disable Capture Exclusion" : "Request Capture Exclusion", #selector(captureExclusion))
        menu.items.last?.state = model.config.captureProtection ? .on : .off
        menu.addItem(.separator())
        item("View Sessions", #selector(history)); item("Preferences…", #selector(connections))
        item("Open Workspace", #selector(workspace)); item("Attach Screenshot    ⌃⌥S", #selector(screenshot))
        menu.addItem(.separator())
        let row = menu.addItem(withTitle: "Quit VELIN", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); row.target = NSApp
    }
    @objc func history() { model.page = "History"; showMain() }
    @objc func captureExclusion() { model.config.captureProtection.toggle(); model.saveConfig(); model.notice = "Capture exclusion is best effort. Verify the actual shared view; invisibility is not guaranteed." }

    @objc func workspace() { showMain() }
    @objc func assistant() { togglePanel() }
    @objc func listen() { model.toggleListening() }
    @objc func screenshot() { model.capture() }
    @objc func connections() { model.page = "AI Connections"; showMain() }
    @objc func about() { model.page = "About"; showMain() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminating { return .terminateNow }
        terminating = true; permissionTimer?.invalidate()
        Task { await model.terminate(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

@main struct VelinMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: "app.velin.assistant").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: []); return
        }
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
