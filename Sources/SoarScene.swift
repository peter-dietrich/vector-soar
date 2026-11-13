import AppKit
import SpriteKit

final class SoarScene: SKScene {
    private let arena = SKNode()
    private let effects = SKNode()
    private var player = SoarFighter(x: 550, y: 280, bird: .eagle)
    private var enemies: [SoarFighter] = []
    private struct Bolt { var x: CGFloat; var y: CGFloat; var vx: CGFloat; var ttl: CGFloat }
    private var bolts: [Bolt] = []
    private var firing = false
    private var shotCooldown: CGFloat = 0
    private var worldClock: CGFloat = 0
    private var nextDripAt: CGFloat = 7
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
        case 3: firing = true; if mode == 1 { fire() }
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
        case 3: firing = false
        default: break
        }
    }
    override func resignFirstResponder() -> Bool {
        left = false; right = false; dive = false; firing = false
        return super.resignFirstResponder()
    }

    private func restart() {
        score = 0; lives = 3; wave = 1; combo = 0
        player = SoarFighter(x: 550, y: 335, bird: .eagle)
        cores.removeAll(); bolts.removeAll(); shotCooldown = 0; worldClock = 0
        nextDripAt = CGFloat.random(in: 5...10)
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
            enemy.bird = [.falcon, .hawk, .owl][(i + wave) % 3]
            enemies.append(enemy)
        }
        banner = "WAVE \(wave)  //  AIRSPACE CONTESTED"
        bannerTimer = 2.2
        SoarAudio.shared.play(.wave)
    }
    private func flap() {
        player.vy = min(SoarRules.maxVertical, max(player.vy, -80) + SoarRules.flapImpulse)
        player.flapPhase = 0.24
        SoarAudio.shared.play(.flap)
        spark(at: CGPoint(x: player.x, y: player.y - 16), color: cyan, count: 5)
    }
    private func fire() {
        guard mode == 1 && shotCooldown <= 0 && bolts.count < 14 else { return }
        shotCooldown = 0.17
        bolts.append(Bolt(x: player.x + player.facing * 27, y: player.y + 2,
                          vx: player.facing * 610 + player.vx * 0.24, ttl: 0.90))
        spark(at: CGPoint(x: player.x + player.facing * 27, y: player.y + 2),
              color: cyan, count: 3)
        SoarAudio.shared.play(.shoot)
    }
    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(1.0 / 25.0, max(0, lastTime == 0 ? 0 : currentTime - lastTime)))
        lastTime = currentTime
        if mode == 1 && dt > 0 { step(dt) }
        redraw()
    }
    private func step(_ dt: CGFloat) {
        worldClock += dt
        if worldClock >= nextDripAt {
            SoarAudio.shared.play(.drip)
            nextDripAt = worldClock + CGFloat.random(in: 7...17)
        }
        shotCooldown = max(0, shotCooldown - dt)
        if firing && shotCooldown <= 0 { fire() }
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
            let acceleration: CGFloat = enemies[i].bird == .falcon ? 395 : (enemies[i].bird == .owl ? 210 : 275)
            enemies[i].vx += target * acceleration * dt
            let topSpeed: CGFloat = CGFloat(95 + min(wave, 20) * 7 + enemies[i].kind * 35) * (enemies[i].bird == .falcon ? 1.22 : (enemies[i].bird == .owl ? 0.80 : 1.0))
            enemies[i].vx = max(-topSpeed, min(topSpeed, enemies[i].vx))
            enemies[i].facing = target
            let desired = min(SoarRules.height - 80, player.y + CGFloat(enemies[i].bird == .owl ? 95 : (enemies[i].bird == .falcon ? 10 : 40)))
            if enemies[i].y < desired && enemies[i].vy < 90 &&
                CGFloat.random(in: 0...1) < (enemies[i].kind == 2 ? 2.7 : 1.65) * dt {
                enemies[i].vy = min(300, max(enemies[i].vy, -75) + CGFloat(185 + enemies[i].kind * 30))
                enemies[i].flapPhase = 0.20
            }
            enemies[i].flapPhase = max(0, enemies[i].flapPhase - dt)
            move(&enemies[i], dt: dt)
        }

        for index in bolts.indices.reversed() {
            bolts[index].x += bolts[index].vx * dt
            bolts[index].ttl -= dt
            if bolts[index].ttl <= 0 || bolts[index].x < -30 || bolts[index].x > SoarRules.width + 30 {
                bolts.remove(at: index)
                continue
            }
            var impact = false
            for i in enemies.indices where enemies[i].alive {
                let dx = bolts[index].x - enemies[i].x
                let dy = bolts[index].y - enemies[i].y
                if dx * dx + dy * dy < 27 * 27 {
                    enemies[i].alive = false
                    let points = 130 * (enemies[i].kind + 1)
                    score += points
                    cores.append((enemies[i].x, enemies[i].y, 11))
                    spark(at: CGPoint(x: enemies[i].x, y: enemies[i].y),
                          color: amber, count: 25)
                    SoarAudio.shared.play(.destroy)
                    banner = "TARGET DOWN  +\(points)"
                    bannerTimer = 0.7
                    impact = true
                    break
                }
            }
            if impact { bolts.remove(at: index) }
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
                    SoarAudio.shared.play(.destroy)
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
                SoarAudio.shared.play(.pickup)
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
        SoarAudio.shared.play(.hurt)
        if lives <= 0 {
            mode = 3
            banner = "MISSION ENDED"
        } else {
            player = SoarFighter(x: 550, y: 340, bird: .eagle)
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
        let x = fighter.x, y = fighter.y, direction = fighter.facing
        let scale: CGFloat = isPlayer ? 1.16 : 1
        let flap: CGFloat = fighter.flapPhase > 0 ? 17 : -9
        func p(_ a: CGFloat, _ b: CGFloat) -> CGPoint {
            CGPoint(x: x + a * direction * scale, y: y + b * scale)
        }
        func detail(_ points: [(CGFloat, CGFloat)], width: CGFloat = 1.4,
                    alpha: CGFloat = 0.75, closed: Bool = false) {
            line(points.map { p($0.0, $0.1) }, color: color, width: width,
                 alpha: alpha, closed: closed)
        }
        switch fighter.bird {
        case .eagle:
            // Large hooked beak, heavy chest, powerful spread primaries and fan tail.
            detail([(-15,8),(-28,flap+4),(-40,flap+12),(-37,flap-2),(-27,flap-9),(-8,3)],
                   width: 3.2,closed:true)
            detail([(0,10),(17,flap+9),(38,flap+17),(36,flap+2),(23,flap-8),(6,1)],
                   width: 3.2,closed:true)
            detail([(-15,5),(-4,14),(12,11),(23,5),(12,-8),(-2,-16),(-17,-9)],
                   width: 3.1,closed:true)
            detail([(22,5),(34,6),(31,-1),(25,-4)],width:2.4)
            detail([(-14,-8),(-26,-16),(-16,-20),(-4,-17),(2,-12)],width:2,closed:true)
            detail([(-28,flap+4),(-22,2),(-37,flap-2)],alpha:0.65)
            detail([(17,flap+9),(10,3),(36,flap+2)],alpha:0.65)
            detail([(-5,-12),(-8,-22),(3,-24)],width:1.5)
        case .falcon:
            // Sleek and sharply swept wings for the fastest attack bird.
            detail([(-10,6),(-31,flap+13),(-36,flap+2),(-21,flap-7),(-1,5)],
                   width:2.4,closed:true)
            detail([(2,8),(24,flap+13),(36,flap+10),(22,flap-7),(7,1)],
                   width:2.4,closed:true)
            detail([(-13,5),(4,10),(21,5),(15,-5),(0,-12),(-15,-4)],
                   width:2.2,closed:true)
            detail([(20,4),(28,3),(23,-2)],width:1.7)
            detail([(-14,-4),(-25,-15),(-8,-11)],width:1.6)
        case .hawk:
            // Medium broad-shouldered hunter.
            detail([(-14,8),(-29,flap+7),(-34,flap-1),(-20,flap-9),(-4,3)],
                   width:2.7,closed:true)
            detail([(0,9),(17,flap+11),(31,flap+5),(25,flap-8),(8,3)],
                   width:2.7,closed:true)
            detail([(-13,7),(3,12),(19,6),(21,-3),(5,-13),(-13,-8)],
                   width:2.6,closed:true)
            detail([(20,3),(29,4),(23,-3)],width:1.9)
            detail([(-13,-8),(-24,-17),(-7,-18),(2,-11)],width:1.7)
        case .owl:
            // Round face, ear tufts, short beak, and wide rounded wings.
            detail([(-10,7),(-23,flap+10),(-32,flap+6),(-29,flap-7),(-8,1)],
                   width:2.7,closed:true)
            detail([(1,8),(16,flap+12),(28,flap+9),(29,flap-4),(8,0)],
                   width:2.7,closed:true)
            let body = SKShapeNode(ellipseOf: CGSize(width:28*scale,height:29*scale))
            body.position = p(0,-1); body.strokeColor = color
            body.fillColor = color.withAlphaComponent(0.10)
            body.lineWidth = 2.4; arena.addChild(body)
            let face = SKShapeNode(ellipseOf: CGSize(width:20*scale,height:18*scale))
            face.position = p(12,8); face.strokeColor = color
            face.fillColor = color.withAlphaComponent(0.13)
            face.lineWidth = 2; arena.addChild(face)
            detail([(5,14),(7,22),(12,16),(18,22),(20,12)],width:1.8)
            detail([(20,6),(25,4),(20,2)],width:1.6)
            detail([(-8,-12),(-13,-21),(2,-21),(8,-12)],width:1.7)
            let secondEye = SKShapeNode(circleOfRadius: 2*scale)
            secondEye.position = p(8,10)
            secondEye.fillColor = .white; secondEye.strokeColor = .clear
            arena.addChild(secondEye)
        }
        let eye = SKShapeNode(circleOfRadius: isPlayer ? 3.1 : 2.5)
        eye.position = p(fighter.bird == .owl ? 16 : 10, 7)
        eye.fillColor = isPlayer ? .white : color
        eye.strokeColor = .clear
        arena.addChild(eye)
        if isPlayer {
            // Muzzle stays outside the bird silhouette.
            detail([(19,0),(31,0)],width:2,alpha:0.7)
        }
    }
    private func redraw() {
        arena.removeAllChildren()
        // Quiet cave depth: receding rock formations and a distant blue grotto.
        let grotto = SKShapeNode(ellipseOf: CGSize(width:390,height:240))
        grotto.position = CGPoint(x:555,y:335)
        grotto.fillColor = SKColor(red:0.06,green:0.17,blue:0.25,alpha:0.16)
        grotto.strokeColor = cyan.withAlphaComponent(0.08)
        grotto.lineWidth = 3
        arena.addChild(grotto)
        for layer in 0..<4 {
            let depth = CGFloat(layer + 1)
            let tint = layer.isMultiple(of: 2) ? cyan : SKColor.systemPurple
            let alpha: CGFloat = 0.055 + depth * 0.026
            var ceiling = [CGPoint(x:0,y:SoarRules.height)]
            var floor = [CGPoint(x:0,y:0)]
            for x in stride(from: 0, through: 1100, by: 32) {
                let xx = CGFloat(x)
                let upper = CGFloat(690 - 25 - layer*24) -
                    sin(xx*0.011+depth*1.7)*CGFloat(11+layer*5) -
                    cos(xx*0.027+depth)*12
                let lower = CGFloat(18 + layer*14) +
                    sin(xx*0.013+depth*2.2)*CGFloat(8+layer*5)
                ceiling.append(CGPoint(x:xx,y:upper))
                floor.append(CGPoint(x:xx,y:lower))
            }
            ceiling.append(CGPoint(x:1100,y:SoarRules.height))
            floor.append(CGPoint(x:1100,y:0))
            line(ceiling,color:tint,width:1.2,alpha:alpha,closed:true)
            line(floor,color:tint,width:1.2,alpha:alpha,closed:true)
        }
        // Hanging mineral teeth are silhouettes, not collidable obstacles.
        for n in 0..<15 {
            let x = CGFloat(24 + n*76)
            let width = CGFloat(13 + (n*7)%23)
            let top = CGFloat(668 - (n*13)%33)
            let point = top - CGFloat(24 + (n*19)%53)
            line([CGPoint(x:x,y:top),CGPoint(x:x+width*0.46,y:point),
                  CGPoint(x:x+width,y:top)],color:cyan,width:1.1,alpha:0.16,closed:true)
        }
        // Very subtle mineral seams and occasional glow in the far cavern.
        for n in 0..<22 {
            let x = CGFloat((n*143+41)%1050)
            let y = CGFloat(90+(n*227)%480)
            let glow = SKShapeNode(circleOfRadius:n.isMultiple(of:5) ? 2.1 : 0.9)
            glow.position = CGPoint(x:x,y:y)
            glow.fillColor = amber.withAlphaComponent(0.09 + 0.05*sin(worldClock*0.5+CGFloat(n)))
            glow.strokeColor = .clear
            arena.addChild(glow)
        }
        for (index, platform) in SoarRules.platforms.enumerated() {
            let p = platform
            let teeth = 7 + index % 3
            let step = p.width / CGFloat(teeth)
            let path = CGMutablePath()
            path.move(to: CGPoint(x:p.minX,y:p.maxY))
            path.addLine(to: CGPoint(x:p.maxX,y:p.maxY))
            path.addLine(to: CGPoint(x:p.maxX-7,y:p.minY+1))
            for n in stride(from: teeth-1, through:0, by:-1) {
                let xx = p.minX + CGFloat(n)*step
                let depth = CGFloat(15 + (n*17 + index*11)%31)
                path.addLine(to: CGPoint(x:xx+step*0.67,y:p.minY-depth*0.25))
                path.addLine(to: CGPoint(x:xx+step*0.42,y:p.minY-depth))
                path.addLine(to: CGPoint(x:xx+step*0.12,y:p.minY-4))
            }
            path.closeSubpath()
            let rock = SKShapeNode(path:path)
            rock.fillColor = SKColor(red:0.045,green:0.073,blue:0.092,alpha:0.94)
            rock.strokeColor = cyan.withAlphaComponent(0.62)
            rock.lineWidth = 1.45
            arena.addChild(rock)
            // The only collision surface remains a clear, perfectly flat ledge top.
            line([CGPoint(x:p.minX,y:p.maxY),CGPoint(x:p.maxX,y:p.maxY)],
                 color:cyan,width:3,alpha:0.95)
            for n in 0..<5 {
                let xx = p.minX + CGFloat(n+1)*p.width/6
                line([CGPoint(x:xx-6,y:p.minY-5),CGPoint(x:xx+10,y:p.minY-11-CGFloat((n+index)%3)*2)],
                     color:amber,width:0.8,alpha:0.32)
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
        for b in bolts {
            let tip = CGPoint(x:b.x,y:b.y)
            line([CGPoint(x:b.x-(b.vx >= 0 ? 19 : -19),y:b.y),tip],
                 color:cyan,width:3.5)
            let tipGlow = SKShapeNode(circleOfRadius:4.5)
            tipGlow.position = tip; tipGlow.fillColor = .white
            tipGlow.strokeColor = cyan
            arena.addChild(tipGlow)
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
