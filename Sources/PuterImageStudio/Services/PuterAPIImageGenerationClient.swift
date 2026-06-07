import Foundation

final class PuterAPIImageGenerationClient: ImageGenerationClient {
    private let baseURL: URL
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let imageDownloadClient: ImageDownloadClient

    init(
        baseURL: URL,
        session: URLSession = .shared,
        imageDownloadClient: ImageDownloadClient
    ) {
        self.baseURL = baseURL
        self.session = session
        self.imageDownloadClient = imageDownloadClient
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
    }

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        let endpoint = baseURL.appendingPathComponent("v1/images/generations")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = 125
        urlRequest.httpBody = try jsonEncoder.encode(request)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GenerationError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
            }

            let decoded = try jsonDecoder.decode(ImageGenerationResponse.self, from: data)
            guard let first = decoded.data.first else {
                throw GenerationError.invalidResponse
            }

            let id = UUID()
            let localFileName: String
            if let remoteURL = first.url {
                localFileName = try await imageDownloadClient.downloadImage(
                    from: remoteURL,
                    preferredFileName: "\(id.uuidString).png"
                )
            } else if let base64 = first.b64JSON, let imageData = Data(base64Encoded: base64) {
                localFileName = try imageDownloadClient.writeImageData(
                    imageData,
                    preferredFileName: "\(id.uuidString).png"
                )
            } else {
                throw GenerationError.invalidImageURL
            }

            return GeneratedImage(
                id: id,
                prompt: request.prompt,
                revisedPrompt: first.revisedPrompt,
                model: request.model,
                quality: request.quality,
                width: request.width,
                height: request.height,
                createdAt: Date(timeIntervalSince1970: TimeInterval(decoded.created)),
                remoteURL: first.url,
                localFileName: localFileName
            )
        } catch is CancellationError {
            throw GenerationError.cancelled
        } catch let error as GenerationError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch is DecodingError {
            throw GenerationError.invalidResponse
        } catch {
            throw GenerationError.unknown(error.localizedDescription)
        }
    }

    private func mapHTTPError(statusCode: Int, data: Data) -> GenerationError {
        let errorResponse = try? jsonDecoder.decode(ImageGenerationErrorResponse.self, from: data)
        let message = errorResponse?.error.message ?? ""
        let detail = errorResponse?.error.detail ?? ""
        let combined = "\(message) \(detail)".lowercased()

        if combined.contains("moderation") || combined.contains("blocked") || combined.contains("safety") {
            return .moderationRejected
        }

        if combined.contains("model") && (combined.contains("unsupported") || combined.contains("not available")) {
            return .unsupportedModel(message.isEmpty ? "That model is not available yet." : message)
        }

        switch statusCode {
        case 400:
            return .server(message.isEmpty ? "The image request was not accepted." : message)
        case 401, 403:
            return .unauthorized
        case 408:
            return .requestTimedOut
        case 429:
            return .rateLimited
        case 500:
            return .server(message)
        case 502, 503, 504:
            return .providerUnavailable(message)
        default:
            return .server(message)
        }
    }

    private func mapURLError(_ error: URLError) -> GenerationError {
        switch error.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .requestTimedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .networkUnavailable
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

extension PuterAPIImageGenerationClient: @unchecked Sendable {}
