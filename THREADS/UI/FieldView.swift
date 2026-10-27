import SwiftUI
import RealityKit

struct FieldView: View {
    @Environment(FieldModel.self) private var model
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        RealityView { content, attachments in
            do {
                try model.build(); content.add(model.chamber.root)
                if let controls = attachments.entity(for: "controls") {
                    model.chamber.instrument.findEntity(named: "field-dock")?.removeFromParent()
                    controls.name = "field-dock"
                    controls.position = [0, -0.60, -1.25]
                    model.chamber.instrument.addChild(controls)
                }
                if let hint = attachments.entity(for: "hint") {
                    model.chamber.instrument.findEntity(named: "field-hint")?.removeFromParent()
                    hint.name = "field-hint"
                    hint.position = [0, 0.21, -1.35]
                    model.chamber.instrument.addChild(hint)
                }
                model.chamber.reducedMotion = reduceMotion
                model.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    model.frame(delta: event.deltaTime)
                }
                model.onVerificationExit = { await leave() }
                model.start()
            } catch { model.error = "The chamber could not be created: \(error.localizedDescription)" }
        } attachments: {
            Attachment(id: "controls") { FieldControlRecovery().environment(model) }
            Attachment(id: "hint") {
                VStack(spacing: 9) {
                    Text("T H R E A D S").font(.system(size: 15, weight: .light)).foregroundStyle(.white.opacity(0.85))
                    Text(model.hint).font(.system(size: 12, weight: .light)).foregroundStyle(.white.opacity(0.65))
                }.padding(18).allowsHitTesting(false)
            }
        }
        .gesture(DragGesture(minimumDistance: 6).targetedToAnyEntity()
            .onChanged { value in
                guard let i = index(value.entity) else { return }
                let displacement = value.convert(value.translation3D, from: .local, to: model.chamber.instrument)
                model.drag(i, displacement: displacement)
            }
            .onEnded { value in if let i = index(value.entity) { model.release(i) } })
        .simultaneousGesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            if let i = index(value.entity) { model.pluck(i) }
        })
        .upperLimbVisibility(.visible)
        .onAppear { openWindow(id: "field-dock") }
        .onChange(of: reduceMotion) { _, value in model.chamber.reducedMotion = value }
        .onChange(of: scenePhase) { _, value in
            if value == .active { model.resume() }
            else if value == .background { model.pause() }
        }
        .onDisappear {
            model.stop()
            dismissWindow(id: "field-dock")
            if !model.welcomeIsOpen { model.welcomeIsOpen = true; openWindow(id: "welcome") }
        }
    }
    private func index(_ entity: Entity) -> Int? {
        guard entity.name.hasPrefix("string-") else { return nil }
        return Int(entity.name.dropFirst(7))
    }
    private func leave() async {
        if !model.welcomeIsOpen { model.welcomeIsOpen = true; openWindow(id: "welcome") }
        await dismissImmersiveSpace()
    }
}
