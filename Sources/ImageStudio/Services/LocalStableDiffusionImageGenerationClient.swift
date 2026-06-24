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

// Default inference parameters — exposed here so SettingsView can surface them
enum LocalSDXLDefaults {
    static let stepCount: Int = 20
    static let guidanceScale: Float = 7.5
    static let negativePrompt: String = "blurry, low quality, cropped, worst quality, artifacts"
}

final class LocalStableDiffusionImageGenerationClient: ImageGenerationClient {
    private let modelStore: LocalManifestModelStore
    private let imageDownloadClient: ImageDownloadClient

    // Cached pipeline — loaded once, unloaded on memory warning / background
    #if canImport(StableDiffusion) && canImport(UIKit) && canImport(CoreML)
    private var cachedPipeline: StableDiffusionPipeline?
    private var cachedResourceURL: URL?
    #endif

    init(
        entry: LocalModelEntry,
        imageDownloadClient: ImageDownloadClient
    ) {
        self.modelStore = LocalManifestModelStore(entry: entry)
        self.imageDownloadClient = imageDownloadClient
        #if canImport(UIKit)
        // Unload pipeline when memory is constrained
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.unloadPipeline()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.unloadPipeline()
        }
        #endif
    }

    // MARK: - ImageGenerationClient

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        #if canImport(StableDiffusion) && canImport(UIKit) && canImport(CoreML)
        guard let resourceURL = modelStore.installedResourceURL() else {
            throw GenerationError.localModelMissing
        }

        let resolvedSeed = request.seed ?? UInt32.random(in: UInt32.min...UInt32.max)
        let resolvedSteps = request.stepCount ?? LocalSDXLDefaults.stepCount
        let resolvedGuidance = request.guidanceScale ?? LocalSDXLDefaults.guidanceScale
        let negPrompt = request.negativePrompt ?? LocalSDXLDefaults.negativePrompt
        let prompt = request.prompt

        let imageData: Data = try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { throw GenerationError.localEngineUnavailable }

            let pipeline = try await self.loadPipeline(at: resourceURL)

            var config = StableDiffusionPipeline.Configuration(prompt: prompt)
            config.negativePrompt = negPrompt
            config.imageCount = 1
            config.seed = resolvedSeed
            config.stepCount = resolvedSteps
            config.guidanceScale = resolvedGuidance
            config.disableSafety = true

            guard let cgImage = try pipeline.generateImages(
                configuration: config,
                progressHandler: { _ in !Task.isCancelled }
            ).first ?? nil else {
                throw GenerationError.invalidResponse
            }

            let uiImage = UIImage(cgImage: cgImage)
            guard let data = uiImage.pngData() else {
                throw GenerationError.downloadFailed
            }
            return data
        }.value

        let id = UUID()
        let localFileName = try imageDownloadClient.writeImageData(
            imageData,
            preferredFileName: "\(id.uuidString).png"
        )

        // Read actual image dimensions from written data
        var width = request.width
        var height = request.height
        if let img = UIImage(data: imageData) {
            width  = Int(img.size.width  * img.scale)
            height = Int(img.size.height * img.scale)
        }

        return GeneratedImage(
            id: id,
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            revisedPrompt: nil,
            model: request.model,
            quality: request.quality,
            width: width,
            height: height,
            createdAt: Date(),
            remoteURL: nil,
            localFileName: localFileName,
            seed: resolvedSeed,
            stepCount: resolvedSteps,
            guidanceScale: resolvedGuidance,
            modelVersion: modelStore.installedVersion()
        )
        #else
        throw GenerationError.localEngineUnavailable
        #endif
    }

    // MARK: - Pipeline lifecycle

    #if canImport(StableDiffusion) && canImport(UIKit) && canImport(CoreML)
    /// Returns the cached pipeline, loading it if needed. Retries with .cpuOnly on failure.
    private func loadPipeline(at resourceURL: URL) async throws -> StableDiffusionPipeline {
        if let cached = cachedPipeline, cachedResourceURL == resourceURL {
            return cached
        }

        let pipeline = try loadPipelineAttempt(at: resourceURL, computeUnits: .cpuAndNeuralEngine)
        cachedPipeline = pipeline
        cachedResourceURL = resourceURL
        return pipeline
    }

    private func loadPipelineAttempt(
        at resourceURL: URL,
        computeUnits: MLComputeUnits
    ) throws -> StableDiffusionPipeline {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = computeUnits
            let pipeline = try StableDiffusionPipeline(
                resourcesAt: resourceURL,
                controlNet: [],
                configuration: config,
                disableSafety: true,
                reduceMemory: true
            )
            try pipeline.loadResources()
            return pipeline
        } catch {
            if computeUnits != .cpuOnly {
                return try loadPipelineAttempt(at: resourceURL, computeUnits: .cpuOnly)
            }
            throw error
        }
    }
    #endif

    func unloadPipeline() {
        #if canImport(StableDiffusion)
        cachedPipeline?.unloadResources()
        cachedPipeline = nil
        cachedResourceURL = nil
        #endif
    }
}

extension LocalStableDiffusionImageGenerationClient: @unchecked Sendable {}
