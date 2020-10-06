import Foundation
import MetalKit
import ModelIO

import simd

//MARK: MATRICES

extension float4x4 {
    init(scaleBy s: Float) {
        self.init(float4(s, 0, 0, 0),
                  float4(0, s, 0, 0),
                  float4(0, 0, s, 0),
                  float4(0, 0, 0, 1))
    }
 
    init(rotationAbout axis: float3, by angleRadians: Float) {
        let x = axis.x, y = axis.y, z = axis.z
        let c = cosf(angleRadians)
        let s = sinf(angleRadians)
        let t = 1 - c
        self.init(float4( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
                  float4( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
                  float4( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
                  float4(                 0,                 0,                 0, 1))
    }
 
    init(translationBy t: float3) {
        self.init(float4(   1,    0,    0, 0),
                  float4(   0,    1,    0, 0),
                  float4(   0,    0,    1, 0),
                  float4(t[0], t[1], t[2], 1))
    }
 
    init(perspectiveProjectionFov fovRadians: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) {
        let yScale = 1 / tan(fovRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange
 
        let xx = xScale
        let yy = yScale
        let zz = zScale
        let zw = Float(-1)
        let wz = wzScale
 
        self.init(float4(xx,  0,  0,  0),
                  float4( 0, yy,  0,  0),
                  float4( 0,  0, zz, zw),
                  float4( 0,  0, wz,  0))
    }
}

//MARK: SHADER CLASS

struct Uniforms {
    var modelViewMatrix: float4x4
    var projectionMatrix: float4x4
}


//MARK: RENDERER CLASS

class Rendering: NSObject, MTKViewDelegate {
    
    var rotation: Float = 0
    public var position: float3 = float3(0,0,-45)
    public let speed: Float = 2
    
    let device: MTLDevice
    let mtkView: MTKView
    let commandQueue: MTLCommandQueue
        
    var vertexDescriptor: MTLVertexDescriptor!
    var renderPipeline: MTLRenderPipelineState!
    
    var meshes: [MTKMesh] = []
    
    init(view: MTKView, device: MTLDevice) {
        self.mtkView = view
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        super.init()
        loadModel()
        buildPipeline()
    }    
    
    //MARK: MODEL LOADER
    func loadModel() {
        let modelURL = Bundle.main.url(forResource: "container", withExtension: "obj")
        
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size * 6, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        
        self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        
        do {
            (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
        }
        catch {
            fatalError("Could not extract meshes from Model I/O asset")
        }
    }
    
    //MARK: PIPELINE
    func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else { fatalError("cannot make library") }
        
        let vertexFunc = library.makeFunction(name: "vertex_main")
        let fragmentFunc = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    //MARK: RENDERING
    func draw(in view: MTKView) {
        
        rotation += 0.5/Float(mtkView.preferredFramesPerSecond)
        let angle = -rotation
        
        let modelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by: angle) *  float4x4(scaleBy: 2)
        let viewMatrix = float4x4(translationBy: position)
        let modelViewMatrix = viewMatrix * modelMatrix
                
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
        
        var uniforms = Uniforms(modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            for mesh in meshes {
                let vertexBuffer = mesh.vertexBuffers.first!
                commandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                commandEncoder?.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
                commandEncoder?.setRenderPipelineState(renderPipeline)
                
                for submesh in mesh.submeshes {
                    let indexBuffer = submesh.indexBuffer
                    commandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType,
                                                         indexCount: submesh.indexCount,
                                                         indexType: submesh.indexType,
                                                         indexBuffer: indexBuffer.buffer,
                                                         indexBufferOffset: indexBuffer.offset)
                }
            }
            commandEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
