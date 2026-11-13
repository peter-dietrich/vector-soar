import AppKit
import SpriteKit

final class SoarScene: SKScene {
    private let arena = SKNode()
    private let effects = SKNode()
    private var player = SoarFighter(x: 550, y: 280)
    private var enemies: [SoarFighter] = []
    private var cores: [(x: CGFloat, y: CGFloat, ttl: CGFloat)] = []
    private var wave = 1
    private var score = 0
    private var highScore = UserDefaults.standard.integer(forKey: "VectorSoar.HighScore")
    private var lives = 3
    private var combo = 0
    private var mode = 0 // 0 ready, 1 playing, 2 paused, 3 game over
    private var left = false
    private var right = false
    private var dive = false
    private var lastTime: TimeInterval = 0
    private var invulnerable: CGFloat = 0
    private var nextWaveDelay: CGFloat = -1
    private var banner = "PRESS RETURN TO LAUNCH"
    private var bannerTimer: CGFloat = 0
    private let cyan = SKColor(red: 0.35, green: 0.92, blue: 1, alpha: 1)
    private let amber = SKColor(red: 1, green: 0.68, blue: 0.27, alpha: 1)

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.012, green: 0.018, blue: 0.052, alpha: 1)
        scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0, y: 0)
        addChild(arena)
        addChild(effects)
        DispatchQueue.main.async { [weak self, weak view] in
            guard let self = self, let view = view else { return }
            view.window?.makeFirstResponder(self)
        }
        redraw()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 0: left = true
        case 124, 2: right = true
        case 49:
            if mode == 1 && !event.isARepeat { flap() }
        case 56, 60: dive = true
        case 36, 76:
            if mode == 0 || mode == 3 { restart() }
            else if mode == 2 { mode = 1 }
        case 35:
            if mode == 1 { mode = 2 }
            else if mode == 2 { mode = 1 }
        default: break
        }
    }
    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 123, 0: left = false
        case 124, 2: right = false
        case 56, 60: dive = false
        default: break
        }
    }
    override func resignFirstResponder() -> Bool {
        left = false; right = false; dive = false
        return super.resignFirstResponder()
    }

    private func restart() {
        score = 0; lives = 3; wave = 1; combo = 0
        player = SoarFighter(x: 550, y: 335)
        cores.removeAll()
        invulnerable = 1.8
        mode = 1
        nextWaveDelay = -1
        spawnWave()
    }
    private func spawnWave() {
        enemies.removeAll()
        let count = min(3 + wave, 11)
        for i in 0..<count {
            let side: CGFloat = i.isMultiple(of: 2) ? 1 : -1
            var enemy = SoarFighter(x: side > 0 ? 75 : 1025,
                                    y: CGFloat(310 + (i % 3) * 105))
            enemy.facing = -side
            enemy.kind = (i + wave) % 5 == 0 ? 2 : ((i + wave) % 3 == 0 ? 1 : 0)
            enemy.vx = -side * CGFloat(65 + wave * 3)
            enemies.append(enemy)
        }
        banner = "WAVE \(wave)  //  AIRSPACE CONTESTED"
        bannerTimer = 2.2
    }
    private func flap() {
        player.vy = min(SoarRules.maxVertical, max(player.vy, -80) + SoarRules.flapImpulse)
        player.flapPhase = 0.24
        spark(at: CGPoint(x: player.x, y: player.y - 16), color: cyan, count: 5)
    }
    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(1.0 / 25.0, max(0, lastTime == 0 ? 0 : currentTime - lastTime)))
        lastTime = currentTime
        if mode == 1 && dt > 0 { step(dt) }
        redraw()
    }
    private func step(_ dt: CGFloat) {
        invulnerable = max(0, invulnerable - dt)
        bannerTimer = max(0, bannerTimer - dt)
        player.flapPhase = max(0, player.flapPhase - dt)
        let steer: CGFloat = (right ? 1 : 0) - (left ? 1 : 0)
        player.vx += steer * SoarRules.horizontalAcceleration * dt
        if steer == 0 { player.vx *= pow(0.12, dt) }
        player.vx = max(-SoarRules.maxHorizontal, min(SoarRules.maxHorizontal, player.vx))
        if steer != 0 { player.facing = steer }
        if dive { player.vy -= 540 * dt }
        move(&player, dt: dt)

        for i in enemies.indices {
            if !enemies[i].alive { continue }
            let dx = player.x - enemies[i].x
            let target: CGFloat = dx > 0 ? 1 : -1
            let acceleration: CGFloat = enemies[i].kind == 2 ? 390 : 260
            enemies[i].vx += target * acceleration * dt
            let topSpeed: CGFloat = CGFloat(95 + min(wave, 20) * 7 + enemies[i].kind * 35)
            enemies[i].vx = max(-topSpeed, min(topSpeed, enemies[i].vx))
            enemies[i].facing = target
            let desired = min(SoarRules.height - 50, player.y + CGFloat(enemies[i].kind == 2 ? 75 : 20))
            if enemies[i].y < desired && enemies[i].vy < 90 &&
                CGFloat.random(in: 0...1) < (enemies[i].kind == 2 ? 2.7 : 1.65) * dt {
                enemies[i].vy = min(300, max(enemies[i].vy, -75) + CGFloat(185 + enemies[i].kind * 30))
                enemies[i].flapPhase = 0.20
            }
            enemies[i].flapPhase = max(0, enemies[i].flapPhase - dt)
            move(&enemies[i], dt: dt)
        }

        for i in enemies.indices where enemies[i].alive {
            let enemy = enemies[i]
            let dx = player.x - enemy.x
            let dy = player.y - enemy.y
            if dx * dx + dy * dy < 42 * 42 {
                if dy > 10 || (abs(dy) < 11 && player.vy < enemy.vy - 80) {
                    enemies[i].alive = false
                    combo += 1
                    let points = (100 + combo * 40) * (enemy.kind + 1)
                    score += points
                    cores.append((enemy.x, enemy.y, 11))
                    player.vy = max(player.vy, 135)
                    spark(at: CGPoint(x: enemy.x, y: enemy.y), color: amber, count: 22)
                    banner = "AIR SUPERIORITY  +\(points)"
                    bannerTimer = 0.85
                } else if invulnerable == 0 {
                    hitPlayer()
                    break
                }
            }
        }
        for i in cores.indices.reversed() {
            cores[i].ttl -= dt
            cores[i].y = max(35, cores[i].y - 58 * dt)
            let dx = cores[i].x - player.x
            let dy = cores[i].y - player.y
            if dx * dx + dy * dy < 30 * 30 {
                score += 150
                spark(at: CGPoint(x: cores[i].x, y: cores[i].y), color: cyan, count: 10)
                cores.remove(at: i)
            } else if cores[i].ttl <= 0 { cores.remove(at: i) }
        }
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "VectorSoar.HighScore")
        }
        if enemies.allSatisfy({ !$0.alive }) {
            if nextWaveDelay < 0 {
                nextWaveDelay = 2.1
                banner = "AIRSPACE SECURED"
                bannerTimer = 2
            }
            nextWaveDelay -= dt
            if nextWaveDelay <= 0 {
                wave += 1
                combo = 0
                nextWaveDelay = -1
                spawnWave()
            }
        }
    }

    private func move(_ fighter: inout SoarFighter, dt: CGFloat) {
        let oldY = fighter.y
        fighter.vy = max(-370, fighter.vy + SoarRules.gravity * dt)
        fighter.x += fighter.vx * dt
        fighter.y += fighter.vy * dt
        if fighter.x < -22 { fighter.x = SoarRules.width + 22 }
        if fighter.x > SoarRules.width + 22 { fighter.x = -22 }
        for platform in SoarRules.platforms {
            if fighter.vy <= 0 &&
                oldY - 19 >= platform.maxY - 4 &&
                fighter.y - 19 <= platform.maxY &&
                fighter.x >= platform.minX - 12 && fighter.x <= platform.maxX + 12 {
                fighter.y = platform.maxY + 19
                fighter.vy = 0
            }
        }
        if fighter.y < 49 {
            fighter.y = 49
            fighter.vy = max(0, fighter.vy)
        }
        if fighter.y > SoarRules.height - 28 {
            fighter.y = SoarRules.height - 28
            fighter.vy = min(0, fighter.vy)
        }
    }

    private func hitPlayer() {
        lives -= 1
        combo = 0
        spark(at: CGPoint(x: player.x, y: player.y), color: .red, count: 30)
        if lives <= 0 {
            mode = 3
            banner = "MISSION ENDED"
        } else {
            player = SoarFighter(x: 550, y: 340)
            invulnerable = 2.3
            banner = "CRAFT LOST  //  RESPAWN"
            bannerTimer = 1.6
        }
    }
    private func spark(at point: CGPoint, color: SKColor, count: Int) {
        for _ in 0..<count {
            let radius = CGFloat.random(in: 1.5...4)
            let s = SKShapeNode(circleOfRadius: radius)
            s.fillColor = color; s.strokeColor = .clear
            s.position = point; s.zPosition = 30
            effects.addChild(s)
            let dx = CGFloat.random(in: -115...115)
            let dy = CGFloat.random(in: -115...115)
            s.run(.sequence([.group([
                .move(by: CGVector(dx: dx, dy: dy), duration: 0.38),
                .fadeOut(withDuration: 0.38)
            ]), .removeFromParent()]))
        }
    }
    private func line(_ points: [CGPoint], color: SKColor, width: CGFloat = 1.5,
                      alpha: CGFloat = 1, closed: Bool = false) {
        guard let first = points.first else { return }
        let path = CGMutablePath()
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        if closed { path.closeSubpath() }
        let node = SKShapeNode(path: path)
        node.strokeColor = color.withAlphaComponent(alpha)
        node.lineWidth = width
        node.lineJoin = .round
        arena.addChild(node)
    }
    private func label(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat = 15,
                       color: SKColor = .white, align: SKLabelHorizontalAlignmentMode = .left) {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = value; node.fontSize = size; node.fontColor = color
        node.horizontalAlignmentMode = align
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: x, y: y)
        arena.addChild(node)
    }
    private func craft(_ fighter: SoarFighter, color: SKColor, isPlayer: Bool) {
        let x = fighter.x, y = fighter.y
        let d = fighter.facing
        let flex: CGFloat = fighter.flapPhase > 0 ? 12 : -5
        // Original geometric mechanical wingcraft, not likenesses of existing game characters.
        line([CGPoint(x:x-26,y:y+flex), CGPoint(x:x-10,y:y+7),
              CGPoint(x:x,y:y+12), CGPoint(x:x+10,y:y+7),
              CGPoint(x:x+26,y:y+flex)], color: color, width: 2.8)
        line([CGPoint(x:x-9,y:y+9),CGPoint(x:x+14*d,y:y+2),
              CGPoint(x:x+2*d,y:y-10), CGPoint(x:x-12*d,y:y-6)],
             color: color, width: 2.5, closed: true)
        line([CGPoint(x:x+11*d,y:y+5),CGPoint(x:x+25*d,y:y+9),
              CGPoint(x:x+14*d,y:y)],color:color,width:2)
        line([CGPoint(x:x-6,y:y-8),CGPoint(x:x-9,y:y-16),
              CGPoint(x:x+4,y:y-16)],color:color,width:1.4)
        if isPlayer {
            line([CGPoint(x:x-4,y:y+11),CGPoint(x:x-3,y:y+23),
                  CGPoint(x:x+5,y:y+23),CGPoint(x:x+6,y:y+12)],color:.white,width:1.5)
        }
    }
    private func redraw() {
        arena.removeAllChildren()
        // Near-black layered horizon and quiet geometric mountain silhouettes.
        for layer in 0..<3 {
            let y: CGFloat = CGFloat(62 + layer * 47)
            let color = cyan.withAlphaComponent(CGFloat(0.055 + Double(layer) * 0.035))
            var points: [CGPoint] = []
            for x in stride(from: 0, through: 1100, by: 55) {
                let yy = y + sin(CGFloat(x) * 0.014 + CGFloat(layer) * 2.3) * CGFloat(13 + layer * 9)
                points.append(CGPoint(x: CGFloat(x), y: yy))
            }
            line(points, color: color, width: 1)
        }
        for x in stride(from: 40, through: 1060, by: 68) {
            line([CGPoint(x:CGFloat(x),y:40),CGPoint(x:CGFloat(x),y:630)],color:cyan,width:0.5,alpha:0.055)
        }
        for y in stride(from: 55, through: 640, by: 68) {
            line([CGPoint(x:20,y:CGFloat(y)),CGPoint(x:1080,y:CGFloat(y))],color:cyan,width:0.5,alpha:0.055)
        }
        for p in SoarRules.platforms {
            line([CGPoint(x:p.minX,y:p.maxY),CGPoint(x:p.maxX,y:p.maxY),
                  CGPoint(x:p.maxX-8,y:p.minY),CGPoint(x:p.minX+8,y:p.minY)],
                 color:cyan,width:2,alpha:0.8,closed:true)
            for n in stride(from: p.minX + 22, to: p.maxX - 10, by: 38) {
                line([CGPoint(x:n,y:p.minY+3),CGPoint(x:n+12,y:p.maxY-3)],
                     color:cyan,width:0.7,alpha:0.28)
            }
        }
        line([CGPoint(x:0,y:31),CGPoint(x:1100,y:31)],color:.red,width:2,alpha:0.42)
        if !(invulnerable > 0 && Int(invulnerable * 10).isMultiple(of: 2)) {
            craft(player, color: cyan, isPlayer: true)
        }
        for e in enemies where e.alive {
            let color: SKColor = e.kind == 2 ? .systemRed : (e.kind == 1 ? amber : .magenta)
            craft(e,color:color,isPlayer:false)
        }
        for core in cores {
            let s = SKShapeNode(circleOfRadius: 9)
            s.position = CGPoint(x: core.x,y:core.y)
            s.strokeColor = amber; s.fillColor = amber.withAlphaComponent(0.15)
            s.lineWidth = 2
            arena.addChild(s)
        }
        // Compact telemetry array at right edge of the gameplay area.
        let hudX: CGFloat = 915
        let hudY: CGFloat = 635
        let bg = SKShapeNode(rect: CGRect(x: hudX - 12,y: 526,width: 187,height: 135),
                             cornerRadius: 8)
        bg.fillColor = SKColor(red:0.02,green:0.055,blue:0.1,alpha:0.79)
        bg.strokeColor = cyan.withAlphaComponent(0.22)
        arena.addChild(bg)
        label("FLIGHT SYSTEMS",x:hudX,y:hudY,size:12,color:cyan)
        label("ALT   \(Int(player.y))",x:hudX,y:hudY-25,size:13)
        label("VEL   \(Int(hypot(player.vx,player.vy)))",x:hudX,y:hudY-49,size:13)
        label("HOSTILES \(enemies.filter{$0.alive}.count)",x:hudX,y:hudY-73,size:13,color:amber)
        label("COMBO x\(max(1,combo))",x:hudX,y:hudY-97,size:13)
        label("SCORE  \(score)",x:28,y:653,size:18,color:cyan)
        label("HI  \(highScore)",x:28,y:629,size:12)
        label("WAVE  \(wave)",x:410,y:653,size:17,color:amber)
        label("LIVES  \(lives)",x:630,y:653,size:17,color:cyan)
        if bannerTimer > 0 && mode == 1 {
            label(banner,x:550,y:582,size:20,color:amber,align:.center)
        }
        if mode != 1 {
            let panel = SKShapeNode(rect: CGRect(x:250,y:246,width:600,height:208),
                                    cornerRadius:15)
            panel.fillColor = SKColor(red:0.025,green:0.05,blue:0.11,alpha:0.95)
            panel.strokeColor = cyan.withAlphaComponent(0.65)
            panel.lineWidth = 2
            arena.addChild(panel)
            label(mode == 2 ? "PAUSED" : (mode == 3 ? "MISSION ENDED" : "VECTOR SOAR"),
                  x:550,y:394,size:32,color:cyan,align:.center)
            label(mode == 3 ? "SCORE  \(score)   /   WAVE  \(wave)" :
                  "DOMINATE THE SKY  //  STRIKE FROM ABOVE",
                  x:550,y:343,size:16,color:amber,align:.center)
            label(mode == 2 ? "RETURN TO RESUME" : "PRESS RETURN TO LAUNCH",
                  x:550,y:293,size:16,align:.center)
        }
    }
}
