import Foundation
import CoreGraphics

enum SoarBird: Int, CaseIterable {
    case eagle, falcon, hawk, owl
}

struct SoarFighter {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var facing: CGFloat = 1
    var flapPhase: CGFloat = 0
    var alive = true
    var kind: Int = 0
    var bird: SoarBird = .falcon
}

struct SoarRules {
    static let width: CGFloat = 1100
    static let height: CGFloat = 690
    static let gravity: CGFloat = -460
    static let flapImpulse: CGFloat = 225
    static let maxVertical: CGFloat = 310
    static let horizontalAcceleration: CGFloat = 880
    static let maxHorizontal: CGFloat = 285
    static let playerRadius: CGFloat = 24
    static let platforms: [CGRect] = [
        CGRect(x: 90, y: 172, width: 235, height: 16),
        CGRect(x: 430, y: 282, width: 240, height: 16),
        CGRect(x: 775, y: 172, width: 235, height: 16),
        CGRect(x: 110, y: 465, width: 225, height: 16),
        CGRect(x: 755, y: 465, width: 225, height: 16)
    ]
}
