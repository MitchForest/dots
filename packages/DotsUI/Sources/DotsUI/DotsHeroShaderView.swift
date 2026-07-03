public import SwiftUI

/// One sample along an active drag; mirrors the 5-float layout
/// (x, y, age, vx, vy) the halftone shader reads from its trail buffer.
private struct TrailSample {
    let point: CGPoint
    let time: Double
    let velocity: CGSize
}

/// Renders a `DotsHeroShader` as a live, full-bleed Metal backdrop.
public struct DotsHeroShaderView: View {
    private let shader: DotsHeroShader
    private let speed: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var touch: CGPoint = .zero
    @State private var touchActive = false
    @State private var pressTime: Double = 0
    @State private var releaseTime: Double = 0
    @State private var trail: [TrailSample] = []
    @State private var taps: [(point: CGPoint, time: Double)] = []
    @State private var life = HalftoneLifeModel()

    /// Trail samples kept for the halftone comet effect; each is 5 floats
    /// (x, y, age, vx, vy) in the shader buffer. The buffer must be long
    /// enough that a fast swipe's tail spans the screen, not just the
    /// last few points at the head.
    private static let maxTrailPoints = 24
    private static let trailLifetime = 1.2

    /// Tap points kept for the halftone ripple effect; each is 3 floats
    /// (x, y, age). A ring takes ~2.5s to cross the panel and fade.
    private static let maxTaps = 8
    private static let tapLifetime = 2.6

    public init(_ shader: DotsHeroShader, speed: Double = 1.0) {
        self.shader = shader
        self.speed = speed
    }

    public var body: some View {
        Group {
            if reduceMotion {
                canvas(
                    time: 18.0,
                    touch: touch,
                    strength: touchActive ? 1 : 0,
                    trail: [],
                    taps: [],
                    board: [],
                    boardCols: 0
                )
            } else {
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let elapsed = now * speed
                    canvas(
                        time: elapsed.truncatingRemainder(dividingBy: 4096.0),
                        touch: touch,
                        strength: touchStrength(now: now),
                        trail: trailFloats(now: now),
                        taps: tapFloats(now: now),
                        board: shader == .halftone ? life.advance(now: now) : [],
                        boardCols: life.cols
                    )
                }
            }
        }
        .background(baseColor)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            guard shader == .halftone, newSize.width > 0, newSize.height > 0 else { return }
            life.configure(size: newSize, gridRows: gridRows(for: newSize))
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let now = Date().timeIntervalSinceReferenceDate
                    if !touchActive {
                        pressTime = now
                        touchActive = true
                    }
                    touch = value.location
                    recordTrailPoint(value.location, now: now)
                    if shader == .halftone {
                        life.kill(around: value.location)
                    }
                }
                .onEnded { value in
                    let now = Date().timeIntervalSinceReferenceDate
                    touch = value.location
                    touchActive = false
                    releaseTime = now
                    // A short press that barely moved is a tap: drop a
                    // ripple into the pond and plant life where it lands.
                    let travel = hypot(value.translation.width, value.translation.height)
                    if travel < 12, now - pressTime < 0.3 {
                        recordTap(value.location, now: now)
                        if shader == .halftone {
                            life.plant(at: value.location)
                        }
                    }
                }
        )
        .accessibilityHidden(true)
    }

    /// Sample the drag path into a short ring buffer with velocities: the
    /// halftone shader rubber-bands tiles along the motion direction and
    /// lets them spring back as each sample ages. A resting finger adds
    /// nothing — the response is velocity-driven.
    private func recordTrailPoint(_ point: CGPoint, now: Double) {
        trail.removeAll { now - $0.time > Self.trailLifetime }
        var velocity = CGSize.zero
        if let last = trail.last {
            let dx = point.x - last.point.x
            let dy = point.y - last.point.y
            guard dx * dx + dy * dy > 100 else { return }
            let dt = max(now - last.time, 1.0 / 120.0)
            if dt < 0.15 {
                velocity = CGSize(width: dx / dt, height: dy / dt)
            }
        }
        trail.append(TrailSample(point: point, time: now, velocity: velocity))
        if trail.count > Self.maxTrailPoints {
            trail.removeFirst(trail.count - Self.maxTrailPoints)
        }
    }

    private func recordTap(_ point: CGPoint, now: Double) {
        taps.removeAll { now - $0.time > Self.tapLifetime }
        taps.append((point, now))
        if taps.count > Self.maxTaps {
            taps.removeFirst(taps.count - Self.maxTaps)
        }
    }

    /// Flat [x, y, age, …] buffer; never empty so the shader's pointer
    /// argument always has backing storage.
    private func tapFloats(now: Double) -> [Float] {
        let live = taps.filter { now - $0.time <= Self.tapLifetime }
        guard live.isEmpty == false else { return [-4096, -4096, 99] }
        return live.flatMap { tap in
            [Float(tap.point.x), Float(tap.point.y), Float(now - tap.time)]
        }
    }

    /// Flat [x, y, age, vx, vy, …] buffer; never empty so the shader's
    /// pointer argument always has backing storage.
    private func trailFloats(now: Double) -> [Float] {
        let live = trail.filter { now - $0.time <= Self.trailLifetime }
        guard live.isEmpty == false else { return [-4096, -4096, 99, 0, 0] }
        return live.flatMap { sample in
            [
                Float(sample.point.x),
                Float(sample.point.y),
                Float(now - sample.time),
                Float(sample.velocity.width),
                Float(sample.velocity.height)
            ]
        }
    }

    private func touchStrength(now: Double) -> Double {
        if touchActive {
            return min(1, (now - pressTime) * 6)
        }
        return max(0, 1 - (now - releaseTime) * 3.5)
    }

    private var baseColor: Color {
        switch shader {
        case .halftone: DotsColor.Hero.ink
        case .mosaic: DotsColor.Hero.blueDeep
        }
    }

    private func canvas(
        time: Double,
        touch: CGPoint,
        strength: Double,
        trail: [Float],
        taps: [Float],
        board: [Float],
        boardCols: Int
    ) -> some View {
        Rectangle()
            .fill(baseColor)
            .visualEffect { content, proxy in
                content.colorEffect(
                    effect(
                        size: proxy.size,
                        time: time,
                        touch: touch,
                        strength: strength,
                        trail: trail,
                        taps: taps,
                        board: board,
                        boardCols: boardCols
                    )
                )
            }
            .drawingGroup()
    }

    nonisolated private func effect(
        size: CGSize,
        time: Double,
        touch: CGPoint,
        strength: Double,
        trail: [Float],
        taps: [Float],
        board: [Float],
        boardCols: Int
    ) -> Shader {
        switch shader {
        case .halftone:
            ShaderLibrary.bundle(.module).dotsHalftone(
                .float2(size),
                .float(time),
                .color(DotsColor.Hero.ink),
                .color(DotsColor.Hero.paper),
                .float(gridRows(for: size)),
                .float2(touch),
                .float(strength),
                .floatArray(trail.isEmpty ? [-4096, -4096, 99, 0, 0] : trail),
                .floatArray(taps.isEmpty ? [-4096, -4096, 99] : taps),
                .float(Double(boardCols)),
                .floatArray(board.isEmpty ? [0] : board)
            )
        case .mosaic:
            ShaderLibrary.bundle(.module).dotsMosaic(
                .float2(size),
                .float(time),
                .color(DotsColor.Hero.blueDeep),
                .color(DotsColor.brand),
                .color(DotsColor.Hero.paper),
                .float(mosaicRows(for: size)),
                .float2(touch),
                .float(strength)
            )
        }
    }

    nonisolated private func mosaicRows(for size: CGSize) -> Double {
        let rows = size.height / 11.0
        return min(max(rows.rounded(), 40), 140)
    }

    nonisolated private func gridRows(for size: CGSize) -> Double {
        let rows = size.height / 21.0
        return min(max(rows.rounded(), 22), 64)
    }
}

/// Conway's Game of Life on the halftone's white-capable lattice. The
/// checkerboard tiles form a square grid rotated 45°, so the standard
/// 8-neighbour rules run on diagonal steps (±1, ±1) and double steps
/// (±2, 0)/(0, ±2) in tile space. Cells carry a smoothed energy the
/// shader renders, so births swell in and deaths fade away instead of
/// blinking. Taps plant an R-pentomino (a long-lived methuselah); drags
/// kill cells along the path like a finger wiped through a petri dish.
private final class HalftoneLifeModel {
    private(set) var cols = 0
    private var rows = 0
    private var cellSize: CGFloat = 1
    private var alive: [Bool] = []
    private var energy: [Float] = []
    private var beforePrevious: [Bool] = []
    private var previous: [Bool] = []
    private var staleGenerations = 0
    private var lastStepTime: Double = 0
    private var lastFrameTime: Double = 0

    private static let stepInterval = 0.6
    private static let neighborOffsets: [(Int, Int)] = [
        (-1, -1), (-1, 1), (1, -1), (1, 1), (-2, 0), (2, 0), (0, -2), (0, 2)
    ]
    /// Shape coordinates are in the rotated lattice's basis: u steps along
    /// the (+1, +1) tile diagonal, v along (-1, +1).
    private static let rPentomino: [(Int, Int)] = [(1, 0), (2, 0), (0, 1), (1, 1), (1, 2)]

    func configure(size: CGSize, gridRows: Double) {
        let cell = size.height / gridRows
        let newCols = Int((size.width / cell).rounded(.up)) + 2
        let newRows = Int(gridRows) + 2
        cellSize = cell
        guard newCols != cols || newRows != rows else { return }
        cols = newCols
        rows = newRows
        alive = Array(repeating: false, count: cols * rows)
        energy = Array(repeating: 0, count: cols * rows)
        previous = alive
        beforePrevious = alive
        plantRandomSeed()
    }

    /// Steps a generation when due, eases every cell's energy toward its
    /// alive/dead target, and returns the energy board for the shader.
    func advance(now: Double) -> [Float] {
        guard cols > 0 else { return [] }
        if lastStepTime == 0 { lastStepTime = now }
        let dt = lastFrameTime == 0 ? 1.0 / 60.0 : min(now - lastFrameTime, 0.1)
        lastFrameTime = now
        if now - lastStepTime >= Self.stepInterval {
            lastStepTime = now
            step()
            tendToStaleBoard()
        }
        for i in alive.indices {
            let target: Float = alive[i] ? 1 : 0
            let rate = alive[i] ? 7.0 : 3.5
            energy[i] += (target - energy[i]) * Float(min(dt * rate, 1))
        }
        return energy
    }

    func plant(at point: CGPoint) {
        guard cols > 0 else { return }
        var tx = Int(point.x / cellSize)
        let ty = Int(point.y / cellSize)
        // The shader's white-capable lattice is the odd-parity checkerboard.
        if (tx + ty) % 2 != 1 { tx += 1 }
        place(Self.rPentomino, atX: tx, y: ty)
    }

    func kill(around point: CGPoint) {
        guard cols > 0 else { return }
        let tx = Int(point.x / cellSize)
        let ty = Int(point.y / cellSize)
        for dy in -2...2 {
            for dx in -2...2 where abs(dx) + abs(dy) <= 3 {
                let x = tx + dx
                let y = ty + dy
                guard x >= 0, y >= 0, x < cols, y < rows else { continue }
                alive[y * cols + x] = false
            }
        }
    }

    private func step() {
        var next = alive
        for y in 0..<rows {
            for x in 0..<cols where (x + y) % 2 == 1 {
                var count = 0
                for (dx, dy) in Self.neighborOffsets {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, ny >= 0, nx < cols, ny < rows else { continue }
                    if alive[ny * cols + nx] { count += 1 }
                }
                let i = y * cols + x
                next[i] = alive[i] ? (count == 2 || count == 3) : count == 3
            }
        }
        beforePrevious = previous
        previous = alive
        alive = next
    }

    /// Still lifes and period-2 oscillators repeat every other generation;
    /// after a stretch of that (or extinction), sow fresh life.
    private func tendToStaleBoard() {
        staleGenerations = alive == beforePrevious ? staleGenerations + 1 : 0
        let extinct = alive.contains(true) == false
        if extinct || staleGenerations >= 8 {
            staleGenerations = 0
            plantRandomSeed()
        }
    }

    private func plantRandomSeed() {
        guard cols > 8, rows > 8 else { return }
        var x = Int.random(in: 4..<(cols - 4))
        let y = Int.random(in: 4..<(rows - 4))
        if (x + y) % 2 != 1 { x += 1 }
        place(Self.rPentomino, atX: x, y: y)
    }

    private func place(_ shape: [(Int, Int)], atX x0: Int, y y0: Int) {
        for (u, v) in shape {
            let x = x0 + u - v
            let y = y0 + u + v
            guard x >= 0, y >= 0, x < cols, y < rows else { continue }
            alive[y * cols + x] = true
        }
    }
}

#Preview("Halftone") {
    DotsHeroShaderView(.halftone)
        .ignoresSafeArea()
}
