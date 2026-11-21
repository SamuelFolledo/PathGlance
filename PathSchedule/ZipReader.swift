import Foundation
import Compression

enum ZipError: LocalizedError {
    case notAZip
    case unsupported(String)
    case corrupt(String)

    var errorDescription: String? {
        switch self {
        case .notAZip: return "The downloaded file is not a zip archive."
        case .unsupported(let detail): return "Unsupported zip archive: \(detail)."
        case .corrupt(let detail): return "The zip archive is damaged: \(detail)."
        }
    }
}

/// Minimal zip reader (stored and deflate entries, no zip64). Enough for a GTFS feed
/// without pulling in a package dependency.
enum ZipReader {
    /// Returns the contents of the named entries. Folder prefixes inside the archive are ignored.
    static func entries(named wanted: Set<String>, in data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { throw ZipError.notAZip }

        func u16(_ offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
        }
        func u32(_ offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
        }

        // End of central directory record: search backwards past any archive comment.
        var eocd = -1
        var probe = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 65_535)
        while probe >= lowest {
            if u32(probe) == 0x0605_4b50 {
                eocd = probe
                break
            }
            probe -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }

        let entryCount = u16(eocd + 10)
        var cursor = u32(eocd + 16)
        var result: [String: Data] = [:]

        for _ in 0..<entryCount {
            guard cursor + 46 <= bytes.count, u32(cursor) == 0x0201_4b50 else {
                throw ZipError.corrupt("bad central directory")
            }
            let method = u16(cursor + 10)
            let compressedSize = u32(cursor + 20)
            let uncompressedSize = u32(cursor + 24)
            let nameLength = u16(cursor + 28)
            let extraLength = u16(cursor + 30)
            let commentLength = u16(cursor + 32)
            let localOffset = u32(cursor + 42)
            guard cursor + 46 + nameLength <= bytes.count else {
                throw ZipError.corrupt("bad entry name")
            }
            let fullName = String(decoding: bytes[(cursor + 46)..<(cursor + 46 + nameLength)], as: UTF8.self)
            cursor += 46 + nameLength + extraLength + commentLength

            let name = fullName.split(separator: "/").last.map(String.init) ?? fullName
            guard wanted.contains(name) else { continue }

            guard localOffset + 30 <= bytes.count, u32(localOffset) == 0x0403_4b50 else {
                throw ZipError.corrupt("bad local header for \(name)")
            }
            let start = localOffset + 30 + u16(localOffset + 26) + u16(localOffset + 28)
            guard start + compressedSize <= bytes.count else {
                throw ZipError.corrupt("\(name) is truncated")
            }

            switch method {
            case 0:
                result[name] = Data(bytes[start..<(start + compressedSize)])
            case 8:
                if uncompressedSize == 0 {
                    result[name] = Data()
                    break
                }
                var output = [UInt8](repeating: 0, count: uncompressedSize)
                let written = output.withUnsafeMutableBufferPointer { destination -> Int in
                    bytes.withUnsafeBufferPointer { source -> Int in
                        guard let destinationBase = destination.baseAddress, let sourceBase = source.baseAddress else {
                            return 0
                        }
                        // COMPRESSION_ZLIB is raw deflate, which is what zip stores.
                        return compression_decode_buffer(
                            destinationBase, uncompressedSize,
                            sourceBase + start, compressedSize,
                            nil, COMPRESSION_ZLIB
                        )
                    }
                }
                guard written == uncompressedSize else {
                    throw ZipError.corrupt("could not inflate \(name)")
                }
                result[name] = Data(output)
            default:
                throw ZipError.unsupported("compression method \(method) for \(name)")
            }
        }
        return result
    }
}
