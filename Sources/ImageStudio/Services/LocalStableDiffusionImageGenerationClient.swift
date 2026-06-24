#if canImport(CoreML)
import CoreML
#endif
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(StableDiffusion)
import StableDiffusion
#endif

final class LocalStableDiffusionImageGenerationClient: ImageGenerationClient {
    private let modelStore: LocalStableDiffusionModelStore
    private let imageDownloadClient: ImageDownloadClient

    init(
        modelStore: LocalStableDiffusionModelStore = LocalStableDiffusionModelStore(),
        imageDownloadClient: ImageDownloadClient
    ) {
        self.modelStore = modelStore
        self.imageDownloadClient = imageDownloadClient
    }

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        #if canImport(StableDiffusion) && canImport(UIKit) && canImport(CoreML)
        guard let resourceURL = modelStore.installedResourceURL() else {
            throw GenerationError.localModelMissing
        }

        let seed = UInt32.random(in: UInt32.min...UInt32.max)
        let prompt = request.prompt
        let generationTask = Task.detached(priority: .userInitiated) {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndNeuralEngine

            let pipeline = try StableDiffusionPipeline(
                resourcesAt: resourceURL,
                controlNet: [],
                configuration: configuration,
                disableSafety: true,
                reduceMemory: true
            )
            try pipeline.loadResources()
            defer { pipeline.unloadResources() }

            var pipelineConfig = StableDiffusionPipeline.Configuration(prompt: prompt)
            pipelineConfig.imageCount = 1
            pipelineConfig.seed = seed
            pipelineConfig.stepCount = 8
            pipelineConfig.guidanceScale = 7.5
            pipelineConfig.disableSafety = true

            guard let image = try pipeline.generateImages(
                configuration: pipelineConfig,
                progressHandler: { _ in !Task.isCancelled }
            ).first ?? nil else {
                throw GenerationError.invalidResponse
            }
            guard let imageData = UIImage(cgImage: image).pngData() else {
                throw GenerationError.downloadFailed
            }
            return imageData
        }
        let imageData = try await generationTask.value

        let id = UUID()
        let localFileName = try imageDownloadClient.writeImageData(
            imageData,
            preferredFileName: "\(id.uuidString).png"
        )

        return GeneratedImage(
            id: id,
            prompt: request.prompt,
            revisedPrompt: nil,
            model: request.model,
            quality: request.quality,
            width: 768,
            height: 768,
            createdAt: Date(),
            remoteURL: nil,
            localFileName: localFileName
        )
        #else
        throw GenerationError.localEngineUnavailable
        #endif
    }
}

extension LocalStableDiffusionImageGenerationClient: @unchecked Sendable {}
