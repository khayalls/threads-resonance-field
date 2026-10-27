import SwiftUI

@main
struct THREADSApp: App {
    @State private var model = FieldModel()
    var body: some Scene {
        WindowGroup(id: "welcome") { WelcomeView().environment(model) }
            .defaultSize(width: 600, height: 620)
            .windowResizability(.contentSize)
        WindowGroup(id: "field-dock") { FieldControlWindow().environment(model) }
            .windowStyle(.plain)
            .windowResizability(.contentSize)
            .defaultWindowPlacement { content, context in
                let size = content.sizeThatFits(.unspecified)
                if let welcome = context.windows.first(where: { $0.id == "welcome" }) {
                    return WindowPlacement(.replacing(welcome), size: size)
                }
                return WindowPlacement(nil, size: size)
            }
        ImmersiveSpace(id: "resonance-field") { FieldView().environment(model) }
            .immersionStyle(selection: .constant(.full), in: .full)
    }
}
