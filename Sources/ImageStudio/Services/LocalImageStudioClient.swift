// LocalImageStudioClient.swift
// This wrapper is intentionally removed — LocalStableDiffusionLocalImageGenerator
// now conforms directly to LocalImageGenerator & Sendable, so the passthrough
// wrapper is no longer needed. This file is kept as a tombstone to prevent
// accidental re-introduction of the redundant wrapper.
//
// If a future use-case requires dispatching to multiple on-device generators, introduce
// a proper LocalModelRouter instead of a single-method passthrough.
