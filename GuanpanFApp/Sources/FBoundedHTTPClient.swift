import Foundation

enum FBoundedHTTPClientError: Error, LocalizedError {
    case invalidLimit
    case responseTooLarge(maximumBytes: Int)

    var errorDescription: String? {
        switch self {
        case .invalidLimit:
            return "HTTP 响应大小上限无效。"
        case let .responseTooLarge(maximumBytes):
            return "HTTP 响应超过\(maximumBytes)字节限制，已停止读取。"
        }
    }
}

/// Reads response bodies incrementally and stops before buffering beyond the
/// caller's endpoint-specific limit.
enum FBoundedHTTPClient {
    static func data(for request: URLRequest, maximumResponseBytes: Int) async throws -> (Data, URLResponse) {
        guard maximumResponseBytes > 0 else { throw FBoundedHTTPClientError.invalidLimit }
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse,
           http.expectedContentLength > Int64(maximumResponseBytes) {
            throw FBoundedHTTPClientError.responseTooLarge(maximumBytes: maximumResponseBytes)
        }
        var data = Data()
        if let http = response as? HTTPURLResponse, http.expectedContentLength > 0 {
            data.reserveCapacity(min(Int(http.expectedContentLength), maximumResponseBytes))
        }
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else {
                throw FBoundedHTTPClientError.responseTooLarge(maximumBytes: maximumResponseBytes)
            }
            data.append(byte)
        }
        return (data, response)
    }
}
