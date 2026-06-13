import Cocoa

struct Particle {
    let baseX: CGFloat
    let baseY: CGFloat
    let baseZ: CGFloat
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var vz: CGFloat
    let size: CGFloat
    let baseAlpha: CGFloat
    let twinkleSpeed: CGFloat
    let twinklePhase: CGFloat
}

final class ParticleSphereRenderer {
    private var particles: [Particle] = []
    private var rotY: CGFloat = 0
    private let rotX: CGFloat = 0.3

    // State effects
    private(set) var isPulsing = false
    private var pulseStartTime: TimeInterval = 0
    private var colorOverride: NSColor?
    private var colorFlashTimer: Timer?

    // Smooth pulse via lerp
    private var smoothRadiusFactor: CGFloat = 1.0

    // Explode state
    private(set) var isExploding = false
    private var explodeReformTimer: Timer?

    init() {
        buildParticles()
    }

    func rebuild(count: Int) {
        buildParticles(count: count)
    }

    // MARK: - State Effects

    func startPulse() {
        isPulsing = true
        pulseStartTime = CACurrentMediaTime()
    }

    func stopPulse() {
        isPulsing = false
        // smoothRadiusFactor will lerp back to 1.0 in draw()
    }

    /// Explode particles outward, then auto-reform after 1.5s
    func explode() {
        isExploding = true
        for i in particles.indices {
            let p = particles[i]
            let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
            let safeDist = dist > 0 ? dist : 1
            let force: CGFloat = 1.2 + CGFloat.random(in: 0...1.8)
            particles[i].vx = (p.x / safeDist) * force * 0.3 + CGFloat.random(in: -2...2)
            particles[i].vy = (p.y / safeDist) * force * 0.3 + CGFloat.random(in: -2...2)
            particles[i].vz = (p.z / safeDist) * force * 0.3 + CGFloat.random(in: -2...2)
        }
        explodeReformTimer?.invalidate()
        explodeReformTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.isExploding = false
            self?.explodeReformTimer = nil
        }
    }

    /// Flash green or red for `duration` seconds, then restore.
    func flashColor(_ color: NSColor, duration: TimeInterval = 3.0) {
        colorOverride = color
        colorFlashTimer?.invalidate()
        colorFlashTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.colorOverride = nil
            self?.colorFlashTimer = nil
        }
    }

    // MARK: - Build Fibonacci Sphere

    private func buildParticles(count: Int = Constants.particleCount) {
        particles = []
        particles.reserveCapacity(count)
        let n = CGFloat(count)
        for i in 0..<count {
            let fi = CGFloat(i)
            let phi = acos(1 - 2 * (fi + 0.5) / n)
            let theta = CGFloat.pi * (1 + sqrt(5)) * fi

            let r = Constants.particleSphereRadiusFactor * Constants.defaultRingSize
            let x = r * sin(phi) * cos(theta)
            let y = r * sin(phi) * sin(theta)
            let z = r * cos(phi)

            let size = Constants.particleSizeMin
                + CGFloat.random(in: 0...(Constants.particleSizeMax - Constants.particleSizeMin))
            let alpha = Constants.particleBaseAlphaMin
                + CGFloat.random(in: 0...(Constants.particleBaseAlphaMax - Constants.particleBaseAlphaMin))

            particles.append(Particle(
                baseX: x, baseY: y, baseZ: z,
                x: x, y: y, z: z,
                vx: 0, vy: 0, vz: 0,
                size: size,
                baseAlpha: alpha,
                twinkleSpeed: 0.5 + CGFloat.random(in: 0...2),
                twinklePhase: CGFloat.random(in: 0...(2 * .pi))
            ))
        }
    }

    // MARK: - Draw

    func draw(in bounds: CGRect, context: CGContext, ringSize: CGFloat, time: TimeInterval) {
        var sphereRadius = Constants.particleSphereRadiusFactor * ringSize
        let fov = Constants.particlePerspectiveFOV
        let cx = bounds.midX
        let cy = bounds.midY

        // Update rotation
        rotY += Constants.particleRotationSpeed

        // Pulse effect (breathing: ~2s cycle like demo, 0.08 amplitude, with lerp)
        let targetFactor: CGFloat
        if isPulsing {
            let elapsed = CGFloat(CACurrentMediaTime() - pulseStartTime)
            targetFactor = 1.0 + 0.092 * sin(elapsed * 3.0)
        } else {
            targetFactor = 1.0
        }
        // Lerp toward target (same as demo: 0.08 lerp factor)
        smoothRadiusFactor += (targetFactor - smoothRadiusFactor) * 0.08
        sphereRadius *= smoothRadiusFactor

        // Resolve color (override or default)
        let cr: CGFloat
        let cg: CGFloat
        let cb: CGFloat
        if let override = colorOverride {
            let rgb = override.usingColorSpace(.genericRGB) ?? override
            cr = rgb.redComponent
            cg = rgb.greenComponent
            cb = rgb.blueComponent
        } else {
            cr = Constants.particleColorR
            cg = Constants.particleColorG
            cb = Constants.particleColorB
        }

        // Update particle physics (explode or reform)
        let scaleFactor = ringSize / Constants.defaultRingSize
        for i in particles.indices {
            if isExploding {
                particles[i].x += particles[i].vx
                particles[i].y += particles[i].vy
                particles[i].z += particles[i].vz
                particles[i].vx *= 0.97
                particles[i].vy *= 0.97
                particles[i].vz *= 0.97
            } else {
                // Lerp back to sphere surface (same as demo: 0.08)
                let bx = particles[i].baseX * scaleFactor
                let by = particles[i].baseY * scaleFactor
                let bz = particles[i].baseZ * scaleFactor
                let dist = sqrt(bx * bx + by * by + bz * bz)
                let safeDist = dist > 0 ? dist : 1
                let tx = (bx / safeDist) * sphereRadius
                let ty = (by / safeDist) * sphereRadius
                let tz = (bz / safeDist) * sphereRadius
                particles[i].x += (tx - particles[i].x) * 0.08
                particles[i].y += (ty - particles[i].y) * 0.08
                particles[i].z += (tz - particles[i].z) * 0.08
                particles[i].vx = 0
                particles[i].vy = 0
                particles[i].vz = 0
            }
        }

        // Prepare sorted indices by Z (far first)
        struct ProjectedParticle {
            let index: Int
            let sx: CGFloat
            let sy: CGFloat
            let scale: CGFloat
            let alpha: CGFloat
            let size: CGFloat
        }

        var projected: [ProjectedParticle] = []
        projected.reserveCapacity(particles.count)

        for (i, p) in particles.enumerated() {
            // Use current particle position (updated by physics)
            let px = p.x
            let py = p.y
            let pz = p.z

            // Rotate around Y axis
            let cosY = cos(rotY), sinY = sin(rotY)
            let rx1 = px * cosY - pz * sinY
            let rz1 = px * sinY + pz * cosY

            // Rotate around X axis
            let cosX = cos(rotX), sinX = sin(rotX)
            let ry1 = py * cosX - rz1 * sinX
            let rz2 = py * sinX + rz1 * cosX

            // Perspective projection
            let projScale = fov / (fov + rz2)
            let sx = cx + rx1 * projScale
            let sy = cy - ry1 * projScale  // flip Y

            // Depth-based alpha
            let depthAlpha: CGFloat = 0.3 + 0.7 * projScale
            let twinkle: CGFloat = 0.6 + 0.4 * sin(CGFloat(time) * p.twinkleSpeed + p.twinklePhase)
            let alpha = p.baseAlpha * depthAlpha * twinkle
            let size = p.size * projScale * scaleFactor

            projected.append(ProjectedParticle(
                index: i, sx: sx, sy: sy, scale: projScale,
                alpha: alpha, size: size
            ))
        }

        // Sort far-to-near (lowest scale = farthest)
        projected.sort { $0.scale < $1.scale }

        // Draw — optimized: skip glow for dim/back particles
        let glowThreshold: CGFloat = 0.5  // only draw glow for brighter particles

        for pp in projected {
            // Glow layer (only for front/bright particles)
            if pp.alpha > glowThreshold {
                let glowSize = pp.size * 3
                context.setFillColor(CGColor(
                    red: cr, green: cg, blue: cb,
                    alpha: pp.alpha * 0.15
                ))
                context.fillEllipse(in: CGRect(
                    x: pp.sx - glowSize,
                    y: pp.sy - glowSize,
                    width: glowSize * 2,
                    height: glowSize * 2
                ))
            }

            // Core dot
            let coreAlpha = min(1.0, pp.alpha)
            context.setFillColor(CGColor(
                red: min(1, cr + 0.3),
                green: min(1, cg + 0.16),
                blue: min(1, cb + 0.16),
                alpha: coreAlpha
            ))
            context.fillEllipse(in: CGRect(
                x: pp.sx - pp.size,
                y: pp.sy - pp.size,
                width: pp.size * 2,
                height: pp.size * 2
            ))
        }
    }

    // MARK: - Draw with custom color (for permission buttons, no rotation update)

    func drawColored(in bounds: CGRect, context: CGContext, ringSize: CGFloat, time: TimeInterval, color: NSColor) {
        let rgb = color.usingColorSpace(.genericRGB) ?? color
        let cr = rgb.redComponent
        let cg = rgb.greenComponent
        let cb = rgb.blueComponent

        let sphereRadius = Constants.particleSphereRadiusFactor * ringSize
        let fov = Constants.particlePerspectiveFOV
        let cx = bounds.midX
        let cy = bounds.midY
        let scaleFactor = ringSize / Constants.defaultRingSize

        struct ProjP {
            let sx: CGFloat; let sy: CGFloat
            let scale: CGFloat; let alpha: CGFloat; let size: CGFloat
        }

        var projected: [ProjP] = []
        projected.reserveCapacity(particles.count)

        for p in particles {
            let bx = p.baseX * scaleFactor
            let by = p.baseY * scaleFactor
            let bz = p.baseZ * scaleFactor
            let dist = sqrt(bx * bx + by * by + bz * bz)
            let safeDist = dist > 0 ? dist : 1
            let px = (bx / safeDist) * sphereRadius
            let py = (by / safeDist) * sphereRadius
            let pz = (bz / safeDist) * sphereRadius

            let cosY = cos(rotY), sinY = sin(rotY)
            let rx1 = px * cosY - pz * sinY
            let rz1 = px * sinY + pz * cosY
            let cosX = cos(rotX), sinX = sin(rotX)
            let ry1 = py * cosX - rz1 * sinX
            let rz2 = py * sinX + rz1 * cosX

            let projScale = fov / (fov + rz2)
            let sx = cx + rx1 * projScale
            let sy = cy - ry1 * projScale

            let depthAlpha: CGFloat = 0.3 + 0.7 * projScale
            let twinkle: CGFloat = 0.6 + 0.4 * sin(CGFloat(time) * p.twinkleSpeed + p.twinklePhase)
            let alpha = p.baseAlpha * depthAlpha * twinkle
            let size = p.size * projScale * scaleFactor

            projected.append(ProjP(sx: sx, sy: sy, scale: projScale, alpha: alpha, size: size))
        }

        projected.sort { $0.scale < $1.scale }

        for pp in projected {
            if pp.alpha > 0.5 {
                let glowSize = pp.size * 3
                context.setFillColor(CGColor(red: cr, green: cg, blue: cb, alpha: pp.alpha * 0.15))
                context.fillEllipse(in: CGRect(x: pp.sx - glowSize, y: pp.sy - glowSize, width: glowSize * 2, height: glowSize * 2))
            }
            let coreAlpha = min(1.0, pp.alpha)
            context.setFillColor(CGColor(red: min(1, cr + 0.3), green: min(1, cg + 0.16), blue: min(1, cb + 0.16), alpha: coreAlpha))
            context.fillEllipse(in: CGRect(x: pp.sx - pp.size, y: pp.sy - pp.size, width: pp.size * 2, height: pp.size * 2))
        }
    }
}
