using UnityEngine;
using System.Collections.Generic;
using UnityEngine.Rendering;

public class DrawMeshInstancedPos : MonoBehaviour
{
    [Header("Main Settings")]
    public Camera _camera;
    public Mesh rainMesh;
    public Material rainMaterial;
    
    [Header("Rain Parameters")]
    public float rainHeight = 30f;
    [Range(1, 5000)] public int horizontalCount = 100;
    [Range(1, 5000)] public int verticalCount = 100;
    public float rainSpacing = 0.5f;
    public bool useFrustumCulling = true;
    public float boundsMargin = 5f; // Added margin for safety

    private ComputeBuffer positionBuffer;
    private Bounds renderBounds;
    private Vector4[] cachedPositions;
    private bool buffersInitialized = false;
    private Vector3[] frustumCorners = new Vector3[8];

    void OnEnable()
    {
        InitializeBuffers();
    }

    void InitializeBuffers()
    {
        int totalCount = horizontalCount * verticalCount;
        
        positionBuffer = new ComputeBuffer(totalCount, 16);
        cachedPositions = new Vector4[totalCount];
        
        UpdatePositions();
        rainMaterial.SetBuffer("_PositionBuffer", positionBuffer);
        
        buffersInitialized = true;
    }

    void UpdateFrustumBounds()
    {
        if (_camera == null) return;

        // Get near and far corners
        _camera.CalculateFrustumCorners(
            new Rect(0, 0, 1, 1),
            _camera.nearClipPlane,
            Camera.MonoOrStereoscopicEye.Mono,
            frustumCorners
        );
        

        // Transform to world space
        for (int i = 0; i < 8; i++)
        {
            frustumCorners[i] = _camera.transform.TransformPoint(frustumCorners[i]);
        }

        // Calculate bounds with margin
        renderBounds = GeometryUtility.CalculateBounds(frustumCorners, Matrix4x4.identity);
        renderBounds.Expand(boundsMargin);
    }

    void UpdatePositions()
    {
        float totalWidth = (horizontalCount - 1) * rainSpacing;
        float totalDepth = (verticalCount - 1) * rainSpacing;
        Vector3 centerOffset = new Vector3(-totalWidth * 0.5f, 0, -totalDepth * 0.5f);

        // 优化4: 并行计算位置(在Burst编译器中效果更好)
        for (int x = 0; x < horizontalCount; x++)
        {
            for (int z = 0; z < verticalCount; z++)
            {
                int index = x * verticalCount + z;
                Vector3 localPos = centerOffset + new Vector3(x * rainSpacing, 0, z * rainSpacing);
                cachedPositions[index] = transform.TransformPoint(localPos);
                cachedPositions[index].w = rainHeight;
            }
        }
        
        positionBuffer.SetData(cachedPositions);
    }

    void Update()
    {
        if (!buffersInitialized) return;
        if (_camera == null) _camera = Camera.main;
        if (rainMaterial == null || rainMesh == null) return;

        // Update frustum bounds every frame
        UpdateFrustumBounds();

        if (transform.hasChanged)
        {
            UpdatePositions();
            transform.hasChanged = false;
        }

        // 优化6: 视锥体裁剪
        if (useFrustumCulling && _camera != null)
        {
            if (!GeometryUtility.TestPlanesAABB(
                GeometryUtility.CalculateFrustumPlanes(_camera), 
                renderBounds))
            {
                return;
            }
        }

        Graphics.DrawMeshInstancedProcedural(
            rainMesh,
            0,
            rainMaterial,
            renderBounds,
            horizontalCount * verticalCount,
            null,
            ShadowCastingMode.Off,
            false,
            0
        );
    }

    void OnDisable()
    {
        // 优化7: 及时释放Buffer
        if (positionBuffer != null)
        {
            positionBuffer.Release();
            positionBuffer = null;
        }
        buffersInitialized = false;
    }
}