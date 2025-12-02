using UnityEngine;

[RequireComponent(typeof(Camera))]
public class HeightCameraController : MonoBehaviour
{
    [SerializeField] private Material targetMaterial; // 需要设置参数的材质
    private Camera heightCamera; // 正交相机引用
    
    private void Start()
    {
        heightCamera = GetComponent<Camera>();
        
        // 确保这是正交相机
        if (!heightCamera.orthographic)
        {
            Debug.LogError("Camera must be orthographic!");
            return;
        }
    }

    private void Update()
    {
        if (targetMaterial == null || heightCamera == null) return;

        // 获取正交相机的size和位置
        float orthoSize = heightCamera.orthographicSize;
        Vector3 cameraPos = heightCamera.transform.position;

        // 创建偏移向量
        // x: 正交size
        // y: 正交size
        // z: 世界空间x坐标
        // w: 世界空间z坐标
        Vector4 heightCameraOffset = new Vector4(
            orthoSize,
            orthoSize,
            cameraPos.x,
            cameraPos.z
        );

        // 设置到shader
        targetMaterial.SetVector("_HeightCameraOffset", heightCameraOffset);
        targetMaterial.SetFloat("_CameraHeight", cameraPos.y);
        
    }

    // 可选：在Scene视图中显示相机范围
    private void OnDrawGizmos()
    {
        if (!heightCamera) return;

        Gizmos.color = Color.yellow;
        Vector3 pos = transform.position;
        float size = heightCamera.orthographicSize;
        
        // 绘制相机视锥范围
        Vector3 p1 = pos + new Vector3(-size, 0, -size);
        Vector3 p2 = pos + new Vector3(size, 0, -size);
        Vector3 p3 = pos + new Vector3(size, 0, size);
        Vector3 p4 = pos + new Vector3(-size, 0, size);

        Gizmos.DrawLine(p1, p2);
        Gizmos.DrawLine(p2, p3);
        Gizmos.DrawLine(p3, p4);
        Gizmos.DrawLine(p4, p1);
    }
}
