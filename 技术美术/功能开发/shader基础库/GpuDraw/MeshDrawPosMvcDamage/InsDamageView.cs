// InsDamageView.cs

using System;
using UnityEngine;
using UnityEngine.Rendering;

public class InsDamageView : IDisposable
{
    public Mesh Mesh { get; set; }
    public Material Material { get; set; }
    public ShadowCastingMode ShadowMode { get; set; } = ShadowCastingMode.On;
    public bool ReceiveShadows { get; set; } = true;

    private ComputeBuffer positionBuffer;
    private ComputeBuffer spawnTimeBuffer;
    private ComputeBuffer damageBuffer;
    private ComputeBuffer colorBuffer;
    private ComputeBuffer argsBuffer;
    private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
    private Bounds renderBounds;
    
    public void InitializeBuffers(int maxCount)
    {
        Dispose();
        
        positionBuffer = new ComputeBuffer(maxCount, 3 * sizeof(float));
        spawnTimeBuffer = new ComputeBuffer(maxCount, sizeof(float));
        damageBuffer = new ComputeBuffer(maxCount, sizeof(uint));
        colorBuffer = new ComputeBuffer(maxCount, 3 * sizeof(float));
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        
        if (Material != null)
        {
            Material.SetBuffer("_Positions", positionBuffer);
            Material.SetBuffer("_SpawnTimes", spawnTimeBuffer);
            Material.SetBuffer("_Damages", damageBuffer);
            Material.SetBuffer("_Colors", colorBuffer);
        }
        
        if (Mesh != null)
        {
            args[0] = Mesh.GetIndexCount(0);
            args[1] = (uint)0;
            args[2] = Mesh.GetIndexStart(0);
            args[3] = Mesh.GetBaseVertex(0);
        }
        argsBuffer.SetData(args);
    }
    // Helper methods used by UpdateBuffers:

    private Vector3[] tempPositions;
    private float[] tempSpawnTimes;
    private uint[] tempDamages;
    private Vector3[] tempColors;
    public void UpdateBuffers(InsDamageData[] instances, int count)
    {
        // Early exit if buffers aren't initialized or there's nothing to render
        if (positionBuffer == null || count == 0 || instances == null) 
            return;

        // Ensure our temporary arrays are properly sized
        EnsureTempArraySizes(count);

        // Extract instance data into parallel arrays for GPU upload
        for (int i = 0; i < count; i++)
        {
            tempPositions[i] = instances[i].position;
            tempSpawnTimes[i] = instances[i].spawnTime;
            tempDamages[i] = instances[i].damage;
            tempColors[i] = instances[i].Color;
        }

        // Upload data to GPU buffers
        positionBuffer.SetData(tempPositions, 0, 0, count);
        spawnTimeBuffer.SetData(tempSpawnTimes, 0, 0, count);
        damageBuffer.SetData(tempDamages, 0, 0, count);
        colorBuffer.SetData(tempColors, 0, 0, count);
        // Update indirect draw arguments
        UpdateDrawArguments(count*10);

        // Calculate dynamic bounds for frustum culling
        UpdateRenderBounds(instances, count);
    }
    
    private void EnsureTempArraySizes(int requiredSize)
    {
        // Only reallocate if necessary to avoid GC pressure
        if (tempPositions == null || tempPositions.Length < requiredSize)
        {
            tempPositions = new Vector3[requiredSize];
            tempSpawnTimes = new float[requiredSize];
            tempDamages = new uint[requiredSize];
            tempColors = new Vector3[requiredSize];
        }
    }

    private void UpdateDrawArguments(int instanceCount)
    {
        if (argsBuffer == null || Mesh == null) return;

        // Args layout:
        // [0] = index count per instance
        // [1] = instance count
        // [2] = start index location
        // [3] = base vertex location
        // [4] = start instance location (always 0)
        args[0] = Mesh.GetIndexCount(0);
        args[1] = (uint)instanceCount;
        args[2] = Mesh.GetIndexStart(0);
        args[3] = Mesh.GetBaseVertex(0);
        args[4] = 0; // Start instance location
    
        argsBuffer.SetData(args);
    }
    
    private void UpdateRenderBounds(InsDamageData[] instances, int count)
    {
        if (count == 0) 
        {
            // Default bounds when no instances exist
            renderBounds = new Bounds(Vector3.zero, Vector3.one * 10f);
            return;
        }

        // Find min/max extents of all instances
        Vector3 min = instances[0].position;
        Vector3 max = instances[0].position;

        for (int i = 1; i < count; i++)
        {
            Vector3 pos = instances[i].position;
            min = Vector3.Min(min, pos);
            max = Vector3.Max(max, pos);
        }

        // Calculate center and size with margin
        Vector3 center = new Vector3(0,0,0);
        Vector3 size = max - min + Vector3.one * 1000;
    
        renderBounds = new Bounds(center, size);
    }
    
    public void RenderInstances()
    {
        if ( argsBuffer == null || args[1] == 0) return;
        
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
        positionBuffer?.Release();
        spawnTimeBuffer?.Release();
        damageBuffer?.Release();
        argsBuffer?.Release();
        positionBuffer = null;
        spawnTimeBuffer = null;
        damageBuffer = null;
        argsBuffer = null;
    }
}