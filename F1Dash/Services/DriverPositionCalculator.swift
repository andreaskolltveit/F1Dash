import Foundation

/// Calculates driver position on the track map using mini-sector data.
///
/// Uses the Position.z topic (X/Y coordinates) when available.
/// Falls back to segment status data from TimingData to estimate position ratio.
enum DriverPositionCalculator {

    /// Calculate position as a ratio (0.0 to 1.0) along the track
    /// based on the last active segment across all sectors.
    static func positionRatio(sectors: [[SegmentStatus]]) -> Double? {
        // Flatten all segments across sectors
        let allSegments = sectors.flatMap { $0 }
        guard !allSegments.isEmpty else { return nil }

        // Find the last segment with active status
        var lastActiveIndex = -1
        for (i, segment) in allSegments.enumerated() {
            if segment.isActive {
                lastActiveIndex = i
            }
        }

        guard lastActiveIndex >= 0 else { return nil }

        // Return ratio of position through the lap
        return Double(lastActiveIndex + 1) / Double(allSegments.count)
    }

    /// Get the point on the track for a given ratio (0.0 to 1.0).
    static func pointOnTrack(ratio: Double, trackPoints: [CGPoint]) -> CGPoint? {
        guard !trackPoints.isEmpty else { return nil }
        let index = Int(ratio * Double(trackPoints.count - 1)).clamped(to: 0...(trackPoints.count - 1))
        return trackPoints[index]
    }

    /// Get the point on the track from raw X/Y position data.
    /// The position data from F1 uses a different coordinate system than the track map,
    /// so we find the nearest track point.
    static func nearestTrackPoint(
        driverX: Double,
        driverY: Double,
        trackPoints: [CGPoint]
    ) -> CGPoint? {
        guard !trackPoints.isEmpty else { return nil }

        // Find the nearest point on the track polyline
        var minDist = Double.greatestFiniteMagnitude
        var nearest = trackPoints[0]

        for point in trackPoints {
            let dx = point.x - driverX
            let dy = point.y - driverY
            let dist = dx * dx + dy * dy  // No need for sqrt, just compare
            if dist < minDist {
                minDist = dist
                nearest = point
            }
        }

        return nearest
    }
}

// MARK: - Clamped

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
