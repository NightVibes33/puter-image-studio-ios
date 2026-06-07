import XCTest
@testable import PuterImageStudio

final class ImageStudioModelTests: XCTestCase {
    func testGenerationRequestUsesBackendContractKeys() throws {
        let request = ImageGenerationRequest(
            prompt: "A cinematic neon city at night",
            model: "gpt-image-2",
            quality: "low",
            width: 512,
            height: 512
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["prompt"] as? String, "A cinematic neon city at night")
        XCTAssertEqual(object["model"] as? String, "gpt-image-2")
        XCTAssertEqual(object["quality"] as? String, "low")
        XCTAssertEqual(object["width"] as? Int, 512)
        XCTAssertEqual(object["height"] as? Int, 512)
        XCTAssertEqual(object["response_format"] as? String, "url")
    }

    func testStylePresetAppendsPromptModifier() {
        let style = StylePreset.presets.first { $0.id == "logo" }!
        let prompt = style.apply(to: "Coffee shop badge")

        XCTAssertTrue(prompt.hasPrefix("Coffee shop badge,"))
        XCTAssertTrue(prompt.contains("simple logo mark"))
        XCTAssertTrue(prompt.contains("no text"))
    }

    func testModelQualitySupportMatchesSpecification() {
        let auto = ImageModel.preset(id: "auto")
        XCTAssertEqual(auto.backendModel, "gpt-image-2")
        XCTAssertEqual(auto.supportedQualities, [.low])

        let dallE = ImageModel.preset(id: "dall-e-3")
        XCTAssertEqual(dallE.supportedQualities, [.standard, .hd])

        let flux = ImageModel.preset(id: "flux-schnell")
        XCTAssertFalse(flux.supportsQuality)
    }

    func testAspectPresetsUseExpectedDimensions() {
        let wallpaper = AspectPreset.presets.first { $0.id == "wallpaper" }!
        XCTAssertEqual(wallpaper.width, 1024)
        XCTAssertEqual(wallpaper.height, 1792)

        let social = AspectPreset.presets.first { $0.id == "social-4x5" }!
        XCTAssertEqual(social.width, 1024)
        XCTAssertEqual(social.height, 1280)
    }
}
