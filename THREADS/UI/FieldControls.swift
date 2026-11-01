import SwiftUI
import os

struct FieldControlWindow: View {
    @Environment(FieldModel.self) private var model
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        FieldControls(exit: { Task { await leave() } })
            .onAppear { model.controlsAppeared() }
            .onDisappear { model.controlsDisappeared() }
    }
    private func leave() async {
        if !model.welcomeIsOpen { model.welcomeIsOpen = true; openWindow(id: "welcome") }
        await dismissImmersiveSpace()
        dismissWindow(id: "field-dock")
    }
}

struct FieldControlRecovery: View {
    @Environment(FieldModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        if !model.controlsWindowOpen {
            Button { model.requestControls { openWindow(id: "field-dock") } } label: {
                Label(model.controlsWindowRequested ? "Opening controls…" : "Show controls", systemImage: "slider.horizontal.3")
                    .font(.body).frame(minWidth: 180, minHeight: 60)
            }.disabled(model.controlsWindowRequested).buttonStyle(.borderless).padding(16).glassBackgroundEffect(in: Capsule())
                .accessibilityIdentifier("restore-controls-window")
                .task(id: model.controlsWindowRequested) {
                    guard model.controlsWindowRequested else { return }
                    do { try await Task.sleep(for: .seconds(3)) } catch { return }
                    if !model.controlsWindowOpen { model.controlsWindowRequested = false }
                }
        }
    }
}

/// A native window provides system placement, scaling, movement and popup focus.
struct FieldControls: View {
    @Environment(FieldModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panel: Panel?
    @State private var confirmReplace = false
    @State private var confirmReset = false
    @State private var confirmExit = false
    var exit: () -> Void

    private enum Panel: String, Identifiable {
        case sound, tools, play, guide
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if model.loopState != .empty || model.canUndoLoopClear { loopStrip }
                else { Color.clear.accessibilityHidden(true) }
            }.frame(height: 84)
            HStack(spacing: 16) {
                if model.showControls {
                    recordButton
                    Button(action: { model.toggleLoop() }) {
                        Label(model.loopState == .playing ? "Pause loop" : "Play loop",
                              systemImage: model.loopState == .playing ? "pause.fill" : "play.fill")
                            .labelStyle(.iconOnly).font(.title3.weight(.medium))
                            .frame(width: 60, height: 60)
                    }
                    .disabled(model.loopState == .empty || model.loopState == .recording)
                    .accessibilityIdentifier("play-loop")
                    .help(model.loopState == .playing ? "Pause loop · Space" : "Play loop · Space")
                    .keyboardShortcut(.space, modifiers: [])
                    separator
                    dockButton("Sound", symbol: "speaker.wave.2", id: "sound-controls") { panel = .sound }
                        .popover(isPresented: soundPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                            panelContent(.sound).presentationCompactAdaptation(.popover).presentationBreakthroughEffect(.prominent)
                        }
                    dockButton("Tools", symbol: "slider.horizontal.3", id: "field-tools") { panel = .tools }
                        .popover(item: toolsPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) { selected in
                            panelContent(selected).presentationCompactAdaptation(.popover).presentationBreakthroughEffect(.prominent)
                        }
                    separator
                } else {
                    dockButton("Controls", symbol: "slider.horizontal.3", id: "expand-controls") { model.showControls = true }
                    separator
                }
                dockButton("Exit", symbol: "door.left.hand.open", id: "exit-field") { requestExit() }
                    .alert("Leave the field?", isPresented: $confirmExit) {
                        Button("Leave field", role: .destructive, action: exit)
                        Button("Stay", role: .cancel) { }
                    } message: { Text("The loop is kept only during this visit and will be cleared when you leave.") }
            }
            .padding(16).buttonStyle(.borderless)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28))
            .accessibilityElement(children: .contain).accessibilityLabel("Field controls")
        }
        .font(.body).fixedSize(horizontal: true, vertical: false)
        .breakthroughEffect(.prominent)
        .onChange(of: panel) { _, value in
            Logger(subsystem: "studio.threads.resonance", category: "Controls").info("Panel: \(value?.rawValue ?? "closed", privacy: .public)")
        }
        .task {
            // Explicit launch-only previews for repeatable simulator visual QA.
            let prefix = "--toolbar-preview="
            guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else { return }
            try? await Task.sleep(for: .seconds(1))
            let value = String(argument.dropFirst(prefix.count))
            if value == "recording" { model.record() }
            else { panel = Panel(rawValue: value) }
        }
    }

    private var soundPresented: Binding<Bool> {
        Binding(get: { panel == .sound }, set: { if !$0 { panel = nil } })
    }
    private var toolsPresented: Binding<Panel?> {
        Binding(get: { panel == .sound ? nil : panel }, set: { panel = $0 })
    }

    private var recordButton: some View {
        Button {
            if model.loopState == .recording { model.record() }
            else if model.loopCount > 0 { confirmReplace = true }
            else { model.record() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: model.loopState == .recording ? "stop.fill" : "record.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(model.loopState == .recording ? Color.red : Color.primary)
                Text(model.loopState == .recording ? "Stop" : "Record").font(.body.weight(.medium))
            }.frame(minWidth: 132, minHeight: 60).contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityLabel(model.loopState == .recording ? "Stop recording" : "Record loop")
        .accessibilityHint(model.loopState == .recording ? "Ends recording and starts playback" : "Records up to twelve seconds")
        .accessibilityIdentifier("record-loop").keyboardShortcut("r", modifiers: [.command])
        .alert("Replace the current loop?", isPresented: $confirmReplace) {
            Button("Replace loop", role: .destructive) { model.record() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Your current loop will be replaced by a new recording.") }
    }

    private func dockButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.body.weight(.medium))
                .frame(minWidth: 112, minHeight: 60).contentShape(RoundedRectangle(cornerRadius: 18))
        }.accessibilityIdentifier(id)
    }

    private var separator: some View {
        Rectangle().fill(Color(uiColor: .separator)).frame(width: 1, height: 32).accessibilityHidden(true)
    }

    private var loopStrip: some View {
        HStack(spacing: 18) {
            if model.canUndoLoopClear {
                Image(systemName: "checkmark.circle").font(.title3).accessibilityHidden(true)
                Text("Loop cleared").font(.body)
                Button { model.undoLoopClear() } label: {
                    Text("Undo").frame(minWidth: 80, minHeight: 60).contentShape(Rectangle())
                }.accessibilityIdentifier("undo-clear-loop")
            } else {
                ZStack {
                    Circle().stroke(.primary.opacity(0.15), lineWidth: 3)
                    Circle().trim(from: 0, to: model.loopProgress)
                        .stroke(model.loopState == .recording ? Color.red : Color.cyan,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: model.loopState == .recording ? "record.circle" : (model.loopState == .playing ? "waveform" : "pause.fill"))
                        .font(.system(size: 15, weight: .medium))
                }.frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loopTitle).font(.body.weight(.medium))
                    Text(model.loopState == .recording ? "\(recordedTime) / 0:12" : "\(model.loopCount) notes · \(String(format: "%.1f", model.loopDuration)) seconds")
                        .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                }.frame(minWidth: 180, alignment: .leading)
                if model.loopState != .recording {
                    Button { model.clearLoopWithUndo() } label: {
                        Label("Clear", systemImage: "trash").frame(minWidth: 86, minHeight: 60)
                    }.accessibilityIdentifier("clear-loop")
                        .accessibilityHint("Clears the loop. Undo remains available for ten seconds")
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6).buttonStyle(.borderless)
        .glassBackgroundEffect(in: Capsule())
        .accessibilityElement(children: .contain).accessibilityLabel("Loop status")
    }

    private var loopTitle: String {
        switch model.loopState {
        case .empty: return "Live instrument"
        case .recording: return "Recording"
        case .playing: return "Loop playing"
        case .paused: return "Loop paused"
        }
    }
    private var recordedTime: String { "0:\(String(format: "%02d", min(12, Int(model.loopProgress * 12))))" }

    private func requestExit() {
        panel = nil
        if model.loopCount > 0 || model.loopState == .recording { confirmExit = true }
        else { exit() }
    }

    @ViewBuilder private func panelContent(_ selected: Panel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if selected == .play || selected == .guide {
                    Button { panel = .tools } label: {
                        Image(systemName: "chevron.left").frame(width: 60, height: 60)
                    }.accessibilityLabel("Back to Tools")
                }
                Text(panelTitle(selected)).font(.title2.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
                Button { panel = nil } label: {
                    Image(systemName: "xmark").font(.title3).frame(width: 60, height: 60)
                }.accessibilityLabel("Close panel").accessibilityIdentifier("close-controls-panel")
            }.padding(.bottom, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selected {
                    case .sound: soundPanel
                    case .tools: toolsPanel
                    case .play: playPanel
                    case .guide: guidePanel
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
            }.scrollBounceBehavior(.basedOnSize)
        }
        .padding(28).frame(width: 500, height: panelHeight(selected))
        .font(.body).buttonStyle(.borderless)
    }

    private func panelTitle(_ selected: Panel) -> String {
        switch selected {
        case .sound: return "Sound"
        case .tools: return "Field tools"
        case .play: return "Play controls"
        case .guide: return "Playing with light"
        }
    }
    private func panelHeight(_ selected: Panel) -> CGFloat {
        switch selected { case .sound: return 650; case .play: return 560; case .tools, .guide: return 650 }
    }

    private var soundPanel: some View {
        @Bindable var model = model
        return Group {
            Text("Musical mood").font(.headline)
            Picker("Musical mood", selection: $model.soundscape) {
                ForEach(Soundscape.allCases) { mood in Text(mood.rawValue).tag(mood) }
            }.pickerStyle(.segmented).accessibilityIdentifier("musical-mood")
            Text(model.soundscape.detail).font(.subheadline).foregroundStyle(.secondary)
            Toggle("Echo trails", isOn: $model.echoEnabled).frame(minHeight: 60).accessibilityIdentifier("echo-trails")
            Text("Two soft echoes follow each note. Your recorded loop keeps its original gestures.").font(.subheadline).foregroundStyle(.secondary)
            Divider()
            HStack {
                Label("Sound level", systemImage: "speaker.wave.2")
                Spacer()
                Text("\(Int((model.volume * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Button { model.volume = max(0, model.volume - 0.05) } label: {
                    Image(systemName: "minus").font(.title3).frame(width: 60, height: 60)
                }.accessibilityLabel("Decrease sound level").disabled(model.volume <= 0)
                Slider(value: $model.volume, in: 0...1).frame(minHeight: 60)
                    .accessibilityLabel("Sound level").accessibilityValue("\(Int((model.volume * 100).rounded())) percent")
                Button { model.volume = min(1, model.volume + 0.05) } label: {
                    Image(systemName: "plus").font(.title3).frame(width: 60, height: 60)
                }.accessibilityLabel("Increase sound level").disabled(model.volume >= 1)
            }
            Divider()
            Toggle(isOn: $model.ambient) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ambient notes")
                    Text("Let the distant field play softly between your gestures.").font(.subheadline).foregroundStyle(.secondary)
                }
            }.frame(minHeight: 60).accessibilityIdentifier("ambient-notes")
            if !model.soundReady {
                Label("Sound is paused", systemImage: "speaker.slash")
                Button { model.resume() } label: { Text("Resume sound").frame(minHeight: 60).contentShape(Rectangle()) }
            }
        }
    }

    private var toolsPanel: some View {
        Group {
            panelAction("Recenter", detail: "Bring the instrument here. Keep your loop.", symbol: "viewfinder", id: "recenter-field") {
                panel = nil; model.recenter()
            }
            panelAction("Play controls", detail: "Play notes and gestures with gaze and pinch.", symbol: "pianokeys", id: "play-controls") { panel = .play }
            Divider()
            Text("Playing distance").font(.headline)
            Picker("Playing distance", selection: Binding(get: { model.reach }, set: { model.setReach($0) })) {
                ForEach(PlayingReach.allCases) { reach in Text(reach.rawValue).tag(reach) }
            }.pickerStyle(.segmented).accessibilityIdentifier("playing-distance")
            Text("Closer brings the strings toward relaxed hands without moving your loop.").font(.subheadline).foregroundStyle(.secondary)
            panelAction(model.guidedPhrase == nil ? "Start guided play" : "Restart guided play", detail: "Follow eight notes on the brighter beads.", symbol: "sparkles", id: "guided-play") {
                model.startGuidedPlay(); panel = nil
            }
            if model.guidedPhrase != nil {
                panelAction("Free play", detail: "Leave the phrase and explore freely.", symbol: "waveform", id: "free-play") { model.stopGuidedPlay(); panel = nil }
            }
            Divider()
            Text(model.handsStatus).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("hands-status")
            Text(model.trackingStatus).font(.caption).foregroundStyle(.secondary)
            panelAction("Restart hand tracking", detail: "Use if open-palm waves stop responding.", symbol: "hand.wave", id: "restart-hands") {
                model.restartTracking()
            }
            panelAction("How to play", detail: "Discover pluck, stretch, wave and resonance.", symbol: "hand.draw", id: "help-field") { panel = .guide }
            Divider()
            panelAction("Minimize controls", detail: "Hide the main controls. Keep Exit available.", symbol: "arrow.down.right.and.arrow.up.left", id: "minimize-controls") {
                panel = nil; model.showControls = false
            }
            panelAction("Reset field", detail: "Silence the field and clear the loop.", symbol: "arrow.counterclockwise", id: "reset-field") {
                if model.loopCount > 0 || model.loopState == .recording { confirmReset = true }
                else { panel = nil; model.reset() }
            }
            .alert("Reset the field?", isPresented: $confirmReset) {
                Button("Reset field", role: .destructive) { panel = nil; model.reset() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("This stops all notes and clears your loop. To change your position without losing the loop, choose Recenter.") }
        }
    }

    private func panelAction(_ title: String, detail: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol).font(.title3).frame(width: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.body.weight(.medium))
                    Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, minHeight: 68, alignment: .leading).contentShape(Rectangle())
        }.accessibilityIdentifier(id)
    }

    private var playPanel: some View {
        Group {
            Text("Each key excites the same strings you can touch in the field.").foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
                ForEach(0..<Instrument.count, id: \.self) { i in
                    Button { model.pluck(i, source: "demo") } label: {
                        Text(model.soundscape.name(i)).font(.body.monospaced().weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }.buttonStyle(.bordered).accessibilityLabel("Play \(model.soundscape.name(i))")
                }
            }
            Divider()
            HStack(spacing: 16) {
                playAction("Stretch") {
                    model.drag(4, displacement: [0.13, 0, 0.04])
                    Task { try? await Task.sleep(for: .seconds(reduceMotion ? 0.15 : 0.65)); model.release(4) }
                }
                playAction("Wave") { model.wave() }
                playAction("Resonate") { model.resonance() }
            }
            Text(model.lastNote).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("last-played-note")
        }
    }

    private func playAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, minHeight: 60).contentShape(Rectangle())
        }
    }

    private var guidePanel: some View {
        Group {
            guideRow("Pluck", symbol: "hand.point.up.left", text: "Brush a fingertip sideways across a nearby thread. A stronger brush creates a stronger note.")
            guideRow("Stretch", symbol: "arrow.left.and.right", text: "Pinch a small light bead and pull gently. Release to let the string return. You can also gaze at a bead and pinch-drag.")
            guideRow("Wave", symbol: "hand.wave", text: "Open your fingers and sweep a palm sideways near the ten foreground strings. A small relaxed sweep is enough; you do not need to hit an exact point.")
            guideRow("Resonance", symbol: "hands.sparkles", text: "Rest both open hands near the center, a comfortable handspan apart, for about a second.")
            Divider()
            Text("Keep your shoulders relaxed. You can use all controls with your hands resting in your lap.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func guideRow(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol).font(.title2).frame(width: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
