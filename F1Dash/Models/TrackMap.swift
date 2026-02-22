import Foundation

/// Track map geometry from MultiViewer API.
struct TrackMap: Decodable {
    let x: [Double]
    let y: [Double]
    let rotation: Double
    let marshalLights: [MarshalLight]?
    let marshalSectors: [MarshalSector]?

    /// Rotation to apply (API rotation + 90°, matching f1-dash behavior)
    var effectiveRotation: Double {
        rotation + 90
    }

    struct MarshalLight: Decodable {
        let trackPosition: TrackPosition?

        struct TrackPosition: Decodable {
            let x: Double
            let y: Double
        }
    }

    struct MarshalSector: Decodable {
        let trackPosition: TrackPosition?

        struct TrackPosition: Decodable {
            let x: Double
            let y: Double
        }
    }

    /// Convert x,y arrays to array of CGPoints.
    var points: [CGPoint] {
        zip(x, y).map { CGPoint(x: $0, y: $1) }
    }
}
