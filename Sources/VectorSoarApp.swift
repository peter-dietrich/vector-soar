import SwiftUI
import SpriteKit

@main
struct VectorSoarApp: App {
    var body: some Scene {
        WindowGroup("Vector Soar") {
            SoarView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 950, minHeight: 650)
        }
        .defaultSize(width: 1300, height: 790)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

struct SoarView: View {
    @State private var scene = SoarScene(size: CGSize(width: SoarRules.width, height: SoarRules.height))
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VECTOR SOAR").font(.system(size: 21, weight: .black, design: .monospaced))
                    .tracking(3).foregroundStyle(.cyan)
                Spacer()
                Text("FLIGHT COMBAT   //   FUN CITY ARCADE")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 24).padding(.vertical, 15)
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .background(Color(red: 0.015, green: 0.025, blue: 0.07))
            HStack {
                Text("← →  STEER     SPACE  FLAP     F  FIRE     SHIFT  DIVE     RETURN  START     P  PAUSE")
                Spacer()
                Text("ALTITUDE WINS")
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .background(Color(red: 0.025, green: 0.035, blue: 0.08))
    }
}
