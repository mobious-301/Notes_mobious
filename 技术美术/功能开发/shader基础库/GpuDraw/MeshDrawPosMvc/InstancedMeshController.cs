// InstancedMeshController.cs
using UnityEngine;

public class InstancedMeshController : MonoBehaviour
{
    [Header("Settings")]
    public int maxInstances = 10000;
    public float instanceLifetime = 10f;
    
    [Header("Rendering")]
    public Mesh mesh;
    public Material material;
    public bool useFrustumCulling = true;
    public float boundsMargin = 5f;
    
    // 模型和视图
    private InstancedMeshModel model;
    private InstancedMeshView view;
    
    // 临时数组（避免GC分配）
    private InstanceData[] renderInstances;
    
    private void Awake()
    {
        // 初始化模型
        model = new InstancedMeshModel(maxInstances)
        {
            DefaultLifetime = instanceLifetime
        };
        
        // 初始化视图
        view = new InstancedMeshView
        {
            Mesh = mesh,
            Material = material,
            UseFrustumCulling = useFrustumCulling,
            BoundsMargin = boundsMargin
        };
        
        // 预分配数组
        renderInstances = new InstanceData[maxInstances];
        
        // 注册事件
        model.OnInstanceActivated += OnInstanceActivated;
        model.OnInstanceDeactivated += OnInstanceDeactivated;
    }
    
    private void OnEnable()
    {
        view.InitializeBuffers(maxInstances);
    }
    
    private void Update()
    {
        model.RemoveExpiredInstances();
        
        // 零GC获取活动实例
        model.GetAllActiveInstances(renderInstances);
        view.UpdateBuffers(renderInstances, model.ActiveInstanceCount);
        view.RenderInstances();
    }
    
    private void OnDisable()
    {
        if (view != null)
        {
            view.Dispose();
        }
    }
    
    private void OnDestroy()
    {
        model.OnInstanceActivated -= OnInstanceActivated;
        model.OnInstanceDeactivated -= OnInstanceDeactivated;
        view.Dispose();
    }
    
    // 事件处理
    private void OnInstanceActivated(int index)
    {
        // 可以在这里处理新实例的特殊效果
    }
    
    private void OnInstanceDeactivated(int index)
    {
        // 可以在这里处理实例消失的效果
    }
    
    // 公开API
    public int AddInstance(Vector3 position, Quaternion rotation, Vector3 scale)
    {
        return model.AddInstance(position, rotation, scale);
    }
    
    public void UpdateInstance(int index, Vector3 position, Quaternion rotation, Vector3 scale)
    {
        ref var instance = ref model.GetInstance(index);
        instance.position = position;
        instance.rotation = rotation;
        instance.scale = scale;
    }
    
    public void ClearAllInstances()
    {
        model.ClearAllInstances();
    }
}