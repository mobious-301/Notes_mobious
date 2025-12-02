using UnityEngine;

public class InstancedMeshRenderer : MonoBehaviour
{
    public Camera _camera;
    public Mesh rainMesh;
    public Material rainMaterial;
    public float height = 30f;

    [Range(1, 1000)]
    public int horizontalCount = 10;
    [Range(1, 1000)]
    public int verticalCount = 10;

    public Vector2 rainAreaSize = new Vector2(10, 10);
    public float rainSpacing = 1f;

    private MaterialPropertyBlock _propertyBlock;
    private Vector4[] _instancePositions;

    private void OnEnable()
    {
        _camera = Camera.main;
        _propertyBlock = new MaterialPropertyBlock();
        InitializeInstances();
    }

    private void InitializeInstances()
    {
        _instancePositions = new Vector4[horizontalCount * verticalCount];
        
        for (int x = 0; x < horizontalCount; x++)
        {
            for (int z = 0; z < verticalCount; z++)
            {
                int index = x * verticalCount + z;
                float xPos = (x - horizontalCount * 0.5f) * rainSpacing;
                float zPos = (z - verticalCount * 0.5f) * rainSpacing;
                _instancePositions[index] = new Vector4(xPos, 0, zPos, 0);
            }
        }
        
        _propertyBlock.SetVectorArray("_InstancePositions", _instancePositions);
    }

    private void Update()
    {
        if ((Object)_camera == null)
        {
            _camera = Camera.main;
        }
        if ( (Object)rainMaterial == null || (Object)rainMesh == null) return;

        // Calculate frustum bounds
        Rect rect = new Rect(0, 0, 1, 1);
        Vector3[] corners = new Vector3[5];
        _camera.CalculateFrustumCorners(rect, _camera.farClipPlane, Camera.MonoOrStereoscopicEye.Mono, corners);
        corners[4] = Vector3.zero;
        
        Bounds frustumBounds = GeometryUtility.CalculateBounds(corners, _camera.transform.localToWorldMatrix);

        // Update Y positions based on camera height
        float cameraHeight = _camera.transform.position.y;
        float rainHeightOffset = height - cameraHeight;

        // Set shader properties
        rainMaterial.SetVector("_RainMin", frustumBounds.min);
        rainMaterial.SetVector("_RainMax", frustumBounds.max);
        rainMaterial.SetInt("_InstanceCount", horizontalCount * verticalCount);
        rainMaterial.SetFloat("_RainHeight", height);

        // Draw instances
        Graphics.DrawMeshInstancedProcedural(
            rainMesh,
            0,
            rainMaterial,
            new Bounds(Vector3.zero, Vector3.one * 1000f),
            horizontalCount * verticalCount,
            _propertyBlock,
            UnityEngine.Rendering.ShadowCastingMode.Off,
            false,
            0
        );
    }
}