import XCTest
import Compression
@testable import F1Dash

final class DecompressorTests: XCTestCase {

    // MARK: - Base64 + DEFLATE round-trip

    func testInflateRoundTrip() throws {
        // Create test data, compress with zlib, then verify inflate works
        let original = "{\"test\":\"hello world\",\"number\":42}"
        let originalData = original.data(using: .utf8)!

        // Compress using Compression framework
        let compressedData = try compress(originalData)

        // Inflate should return the original
        let decompressed = try Decompressor.inflate(compressedData)
        let result = String(data: decompressed, encoding: .utf8)
        XCTAssertEqual(result, original)
    }

    func testDecompressBase64() throws {
        // Create test JSON, compress, base64 encode, then decompress
        let json: [String: Any] = ["Entries": [["Utc": "2026-01-01T12:00:00Z", "Cars": [:]]]]
        let jsonData = try JSONSerialization.data(withJSONObject: json)

        let compressed = try compress(jsonData)
        let base64 = compressed.base64EncodedString()

        let result = try Decompressor.decompress(base64)
        let resultDict = result as? [String: Any]
        XCTAssertNotNil(resultDict)
        XCTAssertNotNil(resultDict?["Entries"])
    }

    func testInvalidBase64Fails() {
        XCTAssertThrowsError(try Decompressor.decompress("!!!NOT_BASE64!!!")) { error in
            XCTAssertTrue(error is Decompressor.DecompressorError)
        }
    }

    func testEmptyDataFails() {
        let emptyBase64 = Data().base64EncodedString()
        XCTAssertThrowsError(try Decompressor.decompress(emptyBase64)) { error in
            XCTAssertTrue(error is Decompressor.DecompressorError)
        }
    }

    // MARK: - Helper

    private func compress(_ data: Data) throws -> Data {
        let destinationSize = data.count + 1024
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                destinationSize,
                baseAddress,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Compression failed"])
        }

        return Data(bytes: destinationBuffer, count: compressedSize)
    }
}
