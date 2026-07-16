import SwiftUI
import Metal
import MetalKit

// BeautyOfFractals
//
// MetalMandelbrotView.swift
//
// Metal-backed live preview surface for interactive fractal exploration.
//
// Provides the fast GPU preview used during navigation while deeper and more
// precise CPU rendering is scheduled separately when required.
struct MetalMandelbrotView: NSViewRepresentable {
    let fractalMode: FractalMode
    let fractalPalette: FractalPalette
    let centerX: Double
    let centerY: Double
    let scale: Double
    let maxIterations: Int
    let colorNormalizationIterations: Int?
    /// Shared with SwiftUI navigation and CPU refinement. This must not be derived
    /// independently from the rounded MTK drawable size.
    let viewportAspectRatio: Double
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return mtkView
        }
        
        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
        mtkView.preferredFramesPerSecond = 60
        
        context.coordinator.setup(
            device: device,
            pixelFormat: mtkView.colorPixelFormat
        )
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.fractalMode = UInt32(fractalMode.rawValue)
        context.coordinator.fractalPalette = UInt32(fractalPalette.rawValue)
        context.coordinator.centerX = Float(centerX)
        context.coordinator.centerY = Float(centerY)
        context.coordinator.scale = Float(scale)
        context.coordinator.maxIterations = UInt32(maxIterations)
        context.coordinator.colorNormalizationIterations = colorNormalizationIterations.map {
            UInt32(max($0, 1))
        } ?? 0
        context.coordinator.viewportAspectRatio = Float(viewportAspectRatio)
        
        nsView.setNeedsDisplay(nsView.bounds)
    }
    
    final class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        
        var fractalMode: UInt32 = 0
        var fractalPalette: UInt32 = 0
        var centerX: Float = -0.5
        var centerY: Float = 0.0
        var scale: Float = 3.0
        var maxIterations: UInt32 = 300
        /// Zero selects the normal flowing scale; a positive value selects a
        /// fixed, cyclic scale for Iteration Journey's Stable mode.
        var colorNormalizationIterations: UInt32 = 0
        var viewportAspectRatio: Float = 1.0
        
        struct Uniforms {
            var centerX: Float
            var centerY: Float
            var scale: Float
            var maxIterations: UInt32
            var colorNormalizationIterations: UInt32
            var aspectRatio: Float
            var fractalMode: UInt32
            var fractalPalette: UInt32
        }
        
        func setup(device: MTLDevice, pixelFormat: MTLPixelFormat) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            guard let library = device.makeDefaultLibrary() else {
                print("Metal: Default Library nicht gefunden")
                return
            }
            
            guard let vertexFunction = library.makeFunction(name: "fullscreen_vertex"),
                  let fragmentFunction = library.makeFunction(name: "fractal_fragment") else {
                print("Metal: Shader-Funktionen nicht gefunden")
                return
            }
            
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            
            do {
                self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                print("Metal Pipeline Fehler:", error)
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            view.setNeedsDisplay(view.bounds)
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandQueue = commandQueue,
                  let pipelineState = pipelineState else {
                return
            }
            
            // The SwiftUI geometry value is deliberately used here instead of
            // drawableSize. On Retina displays drawableSize may be rounded by a pixel,
            // which used to make the Metal and CPU viewports subtly diverge at deep zoom.
            let aspectRatio = max(viewportAspectRatio, 0.000_001)
            
            var uniforms = Uniforms(
                centerX: centerX,
                centerY: centerY,
                scale: scale,
                maxIterations: maxIterations,
                colorNormalizationIterations: colorNormalizationIterations,
                aspectRatio: aspectRatio,
                fractalMode: fractalMode,
                fractalPalette: fractalPalette
            )
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }
            
            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBytes(
                &uniforms,
                length: MemoryLayout<Uniforms>.stride,
                index: 0
            )
            
            encoder.drawPrimitives(
                type: .triangle,
                vertexStart: 0,
                vertexCount: 3
            )
            
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
