import Foundation

struct PaddleLicenseResponse: Codable {
    let success: Bool
    let response: PaddleLicenseData?

    struct PaddleLicenseData: Codable {
        let productId: Int?
        let licenseCode: String?
        let expires: String?

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case licenseCode = "license_code"
            case expires
        }
    }
}

enum PaddleError: Error, LocalizedError {
    case invalidKey
    case networkError
    case serverError(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Invalid license key"
        case .networkError: return "Network error. Please check your connection."
        case .serverError(let msg): return msg
        case .notConfigured: return "Paddle is not configured yet"
        }
    }
}

enum PaddleService {

    /// Activate and verify a license key via Paddle API
    static func activate(licenseKey: String) async -> Result<String, PaddleError> {
        // Skip API call if not configured
        guard PaddleConfig.vendorID != "YOUR_VENDOR_ID" else {
            // DEV MODE: accept any non-empty key for testing
            if !licenseKey.isEmpty {
                return .success(licenseKey)
            }
            return .failure(.notConfigured)
        }

        let params = [
            "vendor_id": PaddleConfig.vendorID,
            "vendor_auth_code": PaddleConfig.vendorAuthCode,
            "product_id": PaddleConfig.productID,
            "license_code": licenseKey
        ]

        guard let url = URL(string: PaddleConfig.activateURL) else {
            return .failure(.networkError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .failure(.serverError("Server returned an error"))
            }

            let decoded = try JSONDecoder().decode(PaddleLicenseResponse.self, from: data)

            if decoded.success {
                return .success(licenseKey)
            } else {
                return .failure(.invalidKey)
            }
        } catch is DecodingError {
            return .failure(.serverError("Unexpected server response"))
        } catch {
            return .failure(.networkError)
        }
    }

    /// Verify an existing license key
    static func verify(licenseKey: String) async -> Result<Bool, PaddleError> {
        guard PaddleConfig.vendorID != "YOUR_VENDOR_ID" else {
            // DEV MODE: always valid
            return .success(true)
        }

        let params = [
            "vendor_id": PaddleConfig.vendorID,
            "vendor_auth_code": PaddleConfig.vendorAuthCode,
            "product_id": PaddleConfig.productID,
            "license_code": licenseKey
        ]

        guard let url = URL(string: PaddleConfig.verifyURL) else {
            return .failure(.networkError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .failure(.serverError("Server returned an error"))
            }

            let decoded = try JSONDecoder().decode(PaddleLicenseResponse.self, from: data)
            return .success(decoded.success)
        } catch {
            return .failure(.networkError)
        }
    }
}
