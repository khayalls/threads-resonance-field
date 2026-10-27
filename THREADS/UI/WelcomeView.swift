import SwiftUI

struct WelcomeView: View {
    @Environment(FieldModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Canvas { context, size in
                    for i in 0..<38 {
                        let t = Double(i) / 37
                        var path = Path()
                        path.move(to: CGPoint(x: 72 + t * 380, y: 260))
                        path.addCurve(to: CGPoint(x: 480 - t * 380, y: 0),
                                      control1: CGPoint(x: 430 - t * 270, y: 170),
                                      control2: CGPoint(x: 100 + t * 260, y: 80))
                        context.stroke(path, with: .color(Color(red: 0.40, green: 0.76, blue: 1).opacity(i % 4 == 0 ? 0.85 : 0.25)), lineWidth: i % 4 == 0 ? 1.1 : 0.6)
                    }
                }
                .frame(height: 270).padding(.horizontal, 26)
                LinearGradient(colors: [.clear, Color(red: 0.02, green: 0.035, blue: 0.065)], startPoint: .top, endPoint: .bottom)
            }.frame(height: 240).accessibilityHidden(true)
            VStack(spacing: 15) {
                Text("THREADS").font(.system(size: 42, weight: .ultraLight, design: .rounded)).tracking(13).padding(.leading, 13)
                Text("R E S O N A N C E   F I E L D").font(.system(size: 12, weight: .medium)).foregroundStyle(.cyan.opacity(0.8))
                Text("An instrument made of light.").font(.title3.weight(.light)).foregroundStyle(.white.opacity(0.78)).padding(.top, 9)
                Button(action: { Task { await enter() } }) {
                    HStack(spacing: 12) { Text(model.transitioning ? "Opening the field…" : "Enter the Field"); Image(systemName: "arrow.up.right") }
                        .padding(.horizontal, 19).padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent).tint(Color(red: 0.66, green: 0.88, blue: 1)).foregroundStyle(.black)
                .disabled(!model.prepared || model.transitioning || model.immersive)
                .accessibilityIdentifier("enter-field")
                .padding(.top, 15)
                if !model.prepared && model.error == nil {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Tuning the acoustic strings…").font(.caption) }.foregroundStyle(.secondary)
                } else if let error = model.error {
                    Text(error).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center)
                    Button("Try again") { Task { await model.prepare() } }
                } else {
                    Text("Seated or standing · Headphones welcome").font(.caption).foregroundStyle(.secondary)
                }
                Text("01  /  A SPATIAL INSTRUMENT").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.32)).padding(.top, 24)
            }.padding(.horizontal, 40).padding(.bottom, 34)
        }
        .frame(width: 600, height: 620)
        .background(Color(red: 0.02, green: 0.035, blue: 0.065))
        .clipShape(RoundedRectangle(cornerRadius: 36))
        .onAppear { model.welcomeIsOpen = true }
        .onDisappear { model.welcomeIsOpen = false }
        .task {
            await model.prepare()
            if model.automatic && !model.automaticEntryConsumed && !model.immersive && model.prepared {
                model.automaticEntryConsumed = true
                await enter()
            }
        }
    }
    private func enter() async {
        guard !model.transitioning, !model.immersive else { return }
        model.transitioning = true; model.error = nil
        switch await openImmersiveSpace(id: "resonance-field") {
        case .opened: model.immersive = true; dismissWindow(id: "welcome")
        case .userCancelled: break
        case .error: model.error = "The field could not open. Please try again."
        @unknown default: model.error = "The field is temporarily unavailable."
        }
        model.transitioning = false
    }
}
