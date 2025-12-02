// InstancedMeshView.cs

using System;
using UnityEngine;
using UnityEngine.Rendering;

public class InstancedMeshView : IDisposable
{
    // 渲染资源
    public Mesh Mesh { get; set; }
    public Material Material { get; set; }
    
    // 渲染设置
    public bool UseFrustumCulling { get; set; } = true;
    public float BoundsMargin { get; set; } = 5f;
    public ShadowCastingMode ShadowMode { get; set; } = ShadowCastingMode.On;
    public bool ReceiveShadows { get; set; } = true;
    
    // 缓冲区
    private ComputeBuffer matrixBuffer;
    private ComputeBuffer argsBuffer;
    private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
    private Bounds renderBounds;
    
    // 临时数组（避免每帧分配）
    private Matrix4x4[] matrixArray;
    
    public void InitializeBuffers(int maxCount)
    {
        Dispose();
        
        matrixBuffer = new ComputeBuffer(maxCount, 16 * sizeof(float));
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        
        if (Material != null)
        {
            Material.SetBuffer("_MatrixBuffer", matrixBuffer);
            Material.SetBuffer("_InstanceMatrixBuffer", matrixBuffer);
        }
        
        if (Mesh != null)
        {
            args[0] = Mesh.GetIndexCount(0);
            args[1] = (uint)0;
            args[2] = Mesh.GetIndexStart(0);
            args[3] = Mesh.GetBaseVertex(0);
        }
        argsBuffer.SetData(args);
        
        matrixArray = new Matrix4x4[maxCount];
    }
    
    public void UpdateBuffers(InstanceData[] instances, int count)
    {
        if (matrixBuffer == null || count == 0) return;
        
        // 零GC更新矩阵数据
        for (int i = 0; i < count; i++)
        {
            matrixArray[i] = instances[i].GetMatrix();
        }
        
        matrixBuffer.SetData(matrixArray, 0, 0, count);
        args[1] = (uint)count;
        argsBuffer.SetData(args);
        
        // 更新包围盒
        if (count > 0)
        {
            renderBounds = new Bounds(instances[0].position, Vector3.one * BoundsMargin);
            for (int i = 1; i < count; i++)
            {
                renderBounds.Encapsulate(instances[i].position);
            }
        }
    }
    
    public void RenderInstances()
    {
        if (matrixBuffer == null || argsBuffer == null || args[1] == 0) return;
        
        Graphics.DrawMeshInstancedIndirect(
            Mesh,
            0,
            Material,
            renderBounds,
            argsBuffer,
            0,
            null,
            ShadowMode,
            ReceiveShadows
        );
    }
    
    public void Dispose()
    {
        matrixBuffer?.Release();
        argsBuffer?.Release();
        matrixBuffer = null;
        argsBuffer = null;
    }
}