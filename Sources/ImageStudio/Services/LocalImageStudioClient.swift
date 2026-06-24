// LocalImageStudioClient.swift
// This wrapper is intentionally removed — LocalStableDiffusionImageGenerationClient
// now conforms directly to ImageGenerationClient & Sendable, so the passthrough
// wrapper is no longer needed. This file is kept as a tombstone to prevent
// accidental re-introduction of the redundant wrapper.
//
// If a future use-case requires dispatching to multiple local backends, introduce
// a proper LocalModelRouter instead of a single-method passthrough.
