import Foundation
import Compression

/// Decompresses F1 .z topic data: Base64 → raw DEFLATE inflate → JSON
enum Decompressor {

    enum DecompressorError: Error, LocalizedError {
        case base64DecodeFailed
        case decompressionFailed
        case jsonParseFailed

        var errorDescription: String? {
            switch self {
            case .base64DecodeFailed: "Failed to decode Base64 data"
            case .decompressionFailed: "Failed to decompress DEFLATE data"
            case .jsonParseFailed: "Failed to parse decompressed JSON"
            }
        }
    }

    /// Decompress a .z topic value (Base64-encoded raw DEFLATE) to parsed JSON.
    static func decompress(_ base64String: String) throws -> Any {
        // 1. Base64 decode
        guard let compressedData = Data(base64Encoded: base64String) else {
            throw DecompressorError.base64DecodeFailed
        }

        // 2. Raw DEFLATE inflate
        let decompressedData = try inflate(compressedData)

        // 3. JSON parse
        let json = try JSONSerialization.jsonObject(with: decompressedData)
        return json
    }

    /// Inflate raw DEFLATE data using Apple's Compression framework.
    static func inflate(_ data: Data) throws -> Data {
        // Allocate destination buffer — F1 data typically expands 5-20x
        let destinationSize = data.count * 20
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                destinationSize,
                baseAddress,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else {
            throw DecompressorError.decompressionFailed
        }

        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
