import Foundation

struct GeminiVisionService {
    private let apiKey = "PASTE_GEMINI_API_KEY_HERE"
    private let model = "gemini-2.5-flash"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func describeImage(jpegData: Data, prompt: String) async throws -> String {
        guard apiKey != "PASTE_GEMINI_API_KEY_HERE", !apiKey.isEmpty else {
            throw GeminiVisionError.missingAPIKey
        }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(
            GenerateContentRequest(
                contents: [
                    Content(
                        parts: [
                            Part(
                                inlineData: InlineData(
                                    mimeType: "image/jpeg",
                                    data: jpegData.base64EncodedString()
                                )
                            ),
                            Part(text: prompt)
                        ]
                    )
                ]
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiVisionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(GeminiAPIErrorResponse.self, from: data)
            throw GeminiVisionError.apiError(
                apiError?.error.message ?? "Gemini request failed with status \(httpResponse.statusCode)."
            )
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        let text = decoded.candidates?
            .flatMap { $0.content.parts }
            .compactMap(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw GeminiVisionError.emptyResponse
        }

        return text
    }
}

enum GeminiVisionError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case .emptyResponse:
            return "Gemini did not return any description."
        case .apiError(let message):
            return message
        }
    }
}

private struct GenerateContentRequest: Encodable {
    let contents: [Content]
}

private struct Content: Encodable {
    let parts: [Part]
}

private struct Part: Encodable {
    let inlineData: InlineData?
    let text: String?

    init(inlineData: InlineData) {
        self.inlineData = inlineData
        self.text = nil
    }

    init(text: String) {
        self.inlineData = nil
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case inlineData = "inline_data"
        case text
    }
}

private struct InlineData: Encodable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]?
}

private struct Candidate: Decodable {
    let content: ResponseContent
}

private struct ResponseContent: Decodable {
    let parts: [ResponsePart]
}

private struct ResponsePart: Decodable {
    let text: String?
}

private struct GeminiAPIErrorResponse: Decodable {
    let error: GeminiAPIError
}

private struct GeminiAPIError: Decodable {
    let message: String
}
