import SwiftUI

/// Shared track map rendering logic used by both full-screen and dashboard views.
enum TrackMapRenderer {

    /// Calculate a transform function that maps track coordinates to view coordinates.
    static func calculateTransform(
        points: [CGPoint],
        size: CGSize,
        rotation: Double,
        zoom: CGFloat = 1.0
    ) -> (CGPoint) -> CGPoint {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        let angleRad = rotation * .pi / 180.0
        let cosA = cos(angleRad)
        let sinA = sin(angleRad)

        // Rotate all points to find rotated bounds
        let rotated = points.map { p -> CGPoint in
            let dx = p.x - centerX
            let dy = p.y - centerY
            return CGPoint(x: dx * cosA - dy * sinA, y: dx * sinA + dy * cosA)
        }

        let rxs = rotated.map { Double($0.x) }
        let rys = rotated.map { Double($0.y) }
        let rMinX = rxs.min()!, rMaxX = rxs.max()!
        let rMinY = rys.min()!, rMaxY = rys.max()!
        let rWidth = rMaxX - rMinX
        let rHeight = rMaxY - rMinY

        let scaleX = rWidth > 0 ? size.width / rWidth : 1.0
        let scaleY = rHeight > 0 ? size.height / rHeight : 1.0
        let scale = min(scaleX, scaleY) * 0.92 * zoom

        let offsetX = size.width / 2.0
        let offsetY = size.height / 2.0
        let rCenterX = (rMinX + rMaxX) / 2.0
        let rCenterY = (rMinY + rMaxY) / 2.0

        return { (point: CGPoint) -> CGPoint in
            let dx = point.x - centerX
            let dy = point.y - centerY
            let rx = dx * cosA - dy * sinA
            let ry = dx * sinA + dy * cosA
            return CGPoint(
                x: (rx - rCenterX) * scale + offsetX,
                y: (ry - rCenterY) * scale + offsetY
            )
        }
    }

    /// Draw the track outline.
    static func drawTrack(
        context: GraphicsContext,
        size: CGSize,
        map: TrackMap,
        trackStatus: TrackStatus,
        zoom: CGFloat = 1.0,
        trackWidth: CGFloat = 14
    ) {
        let points = map.points
        guard points.count > 1 else { return }

        let transform = calculateTransform(points: points, size: size, rotation: map.effectiveRotation, zoom: zoom)

        var trackPath = Path()
        let transformed = points.map { transform($0) }
        trackPath.move(to: transformed[0])
        for i in 1..<transformed.count {
            trackPath.addLine(to: transformed[i])
        }
        trackPath.closeSubpath()

        context.stroke(trackPath, with: .color(.gray.opacity(0.4)), lineWidth: trackWidth)
        context.stroke(trackPath, with: .color(.gray.opacity(0.6)), lineWidth: 2)

        if trackStatus.status.isHazard {
            context.stroke(trackPath, with: .color(trackStatus.status.color.opacity(0.3)), lineWidth: trackWidth + 4)
        }
    }

    // MARK: - Driver label info for collision resolution

    private struct DriverLabel {
        let driverNumber: String
        let dotCenter: CGPoint
        let color: Color
        let tla: String
        let position: Int  // race position (1 = leader)
        var labelCenter: CGPoint  // will be adjusted
    }

    /// Draw driver positions on the track with collision-free labels.
    static func drawDriverPositions(
        context: GraphicsContext,
        map: TrackMap,
        size: CGSize,
        driverPositions: [String: DriverPosition],
        drivers: [String: Driver],
        dotSize: CGFloat = 12,
        showLabels: Bool = true,
        zoom: CGFloat = 1.0
    ) {
        let transform = calculateTransform(points: map.points, size: size, rotation: map.effectiveRotation, zoom: zoom)
        let effectiveDotSize: CGFloat = max(dotSize, 16)

        // 1. Build label list with screen positions
        var labels: [DriverLabel] = []
        for (driverNumber, position) in driverPositions {
            guard position.isOnTrack else { continue }
            let driver = drivers[driverNumber]
            let point = transform(CGPoint(x: position.x, y: position.y))
            let tla = driver?.tla ?? driverNumber
            let racePos = driver?.line ?? 99

            labels.append(DriverLabel(
                driverNumber: driverNumber,
                dotCenter: point,
                color: driver?.color ?? .gray,
                tla: tla,
                position: racePos,
                labelCenter: CGPoint(x: point.x, y: point.y - effectiveDotSize / 2 - 10)
            ))
        }

        // 2. Resolve label collisions
        let labelHeight: CGFloat = 13
        let labelWidth: CGFloat = 32
        let leaderLineGap: CGFloat = effectiveDotSize / 2 + 3
        resolveCollisions(&labels, labelWidth: labelWidth, labelHeight: labelHeight, leaderLineGap: leaderLineGap)

        // 3. Draw leader lines first (behind dots)
        for label in labels {
            let dist = hypot(label.labelCenter.x - label.dotCenter.x, label.labelCenter.y - label.dotCenter.y)
            if dist > leaderLineGap + 4 {
                // Draw a thin line from dot edge to label
                let dx = label.labelCenter.x - label.dotCenter.x
                let dy = label.labelCenter.y - label.dotCenter.y
                let len = hypot(dx, dy)
                let nx = dx / len
                let ny = dy / len

                let lineStart = CGPoint(
                    x: label.dotCenter.x + nx * leaderLineGap,
                    y: label.dotCenter.y + ny * leaderLineGap
                )
                let lineEnd = CGPoint(
                    x: label.labelCenter.x - nx * 2,
                    y: label.labelCenter.y - ny * 2
                )

                var path = Path()
                path.move(to: lineStart)
                path.addLine(to: lineEnd)
                context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1)
            }
        }

        // 4. Draw dots
        for label in labels {
            let rect = CGRect(
                x: label.dotCenter.x - effectiveDotSize / 2,
                y: label.dotCenter.y - effectiveDotSize / 2,
                width: effectiveDotSize,
                height: effectiveDotSize
            )
            let outlineRect = CGRect(
                x: label.dotCenter.x - (effectiveDotSize + 4) / 2,
                y: label.dotCenter.y - (effectiveDotSize + 4) / 2,
                width: effectiveDotSize + 4,
                height: effectiveDotSize + 4
            )
            context.fill(Circle().path(in: outlineRect), with: .color(.white.opacity(0.9)))
            context.fill(Circle().path(in: rect), with: .color(label.color))
        }

        // 5. Draw labels
        if showLabels {
            for label in labels {
                let text = Text(label.tla)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                context.draw(context.resolve(text), at: label.labelCenter)
            }
        }
    }

    // MARK: - Position Interpolation

    /// Linearly interpolate driver positions for smooth animation between updates.
    static func interpolatePositions(
        from: [String: DriverPosition],
        to: [String: DriverPosition],
        progress: Double
    ) -> [String: DriverPosition] {
        let t = max(0, min(1, progress))
        var result: [String: DriverPosition] = [:]
        for (key, toPos) in to {
            if let fromPos = from[key], fromPos.isOnTrack && toPos.isOnTrack {
                result[key] = DriverPosition(
                    x: fromPos.x + (toPos.x - fromPos.x) * t,
                    y: fromPos.y + (toPos.y - fromPos.y) * t,
                    z: toPos.z,
                    status: toPos.status
                )
            } else {
                result[key] = toPos
            }
        }
        return result
    }

    // MARK: - Collision Resolution

    /// Group nearby labels and fan them out so they don't overlap.
    /// P1 gets the topmost position in each group.
    private static func resolveCollisions(
        _ labels: inout [DriverLabel],
        labelWidth: CGFloat,
        labelHeight: CGFloat,
        leaderLineGap: CGFloat
    ) {
        guard labels.count > 1 else { return }

        // Proximity threshold: labels whose dots are within this distance
        // are considered a cluster and need to be fanned out.
        let clusterRadius: CGFloat = 40

        // Mark which labels have been assigned to a cluster
        var assigned = Set<Int>()
        var clusters: [[Int]] = []

        // Build clusters by proximity
        for i in 0..<labels.count {
            guard !assigned.contains(i) else { continue }
            var cluster = [i]
            assigned.insert(i)

            for j in (i + 1)..<labels.count {
                guard !assigned.contains(j) else { continue }
                let dist = hypot(
                    labels[i].dotCenter.x - labels[j].dotCenter.x,
                    labels[i].dotCenter.y - labels[j].dotCenter.y
                )
                if dist < clusterRadius {
                    cluster.append(j)
                    assigned.insert(j)
                }
            }

            if cluster.count > 1 {
                clusters.append(cluster)
            }
        }

        // For each cluster, sort by race position and fan labels out vertically
        for cluster in clusters {
            // Sort: P1 first (lowest position number = leader)
            let sorted = cluster.sorted { labels[$0].position < labels[$1].position }

            // Find the centroid of the cluster's dot positions
            let cx = sorted.map { labels[$0].dotCenter.x }.reduce(0, +) / CGFloat(sorted.count)
            let cy = sorted.map { labels[$0].dotCenter.y }.reduce(0, +) / CGFloat(sorted.count)

            // Stack labels above the cluster centroid, P1 on top
            let totalHeight = CGFloat(sorted.count) * labelHeight
            let topY = cy - leaderLineGap - totalHeight

            for (rank, idx) in sorted.enumerated() {
                labels[idx].labelCenter = CGPoint(
                    x: cx,
                    y: topY + CGFloat(rank) * labelHeight + labelHeight / 2
                )
            }
        }
    }
}
