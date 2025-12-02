// InsDamageController.cs
using UnityEngine;

public class InsDamageController : MonoBehaviour
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
    private InsDamageModel model;
    private InsDamageView view;
    
    // 临时数组（避免GC分配）
    private InsDamageData[] renderInstances;
    
    private void Awake()
    {
        // 初始化模型
        model = new InsDamageModel(maxInstances)
        {
            DefaultLifetime = instanceLifetime
        };
        if (mesh == null) mesh = CreateDefaultQuadMesh();
        // 初始化视图
        view = new InsDamageView
        {
            Mesh = mesh ,
            Material = material,
            // UseFrustumCulling = useFrustumCulling,
            // BoundsMargin = boundsMargin
        };
        
        // 预分配数组
        renderInstances = new InsDamageData[maxInstances];
        
        // 注册事件
        model.OnInstanceActivated += OnInstanceActivated;
        model.OnInstanceDeactivated += OnInstanceDeactivated;
    }
    private Mesh CreateDefaultQuadMesh()
    {
        Mesh mesh = new Mesh();
        mesh.name = "DefaultDamageQuad";
    
        // 顶点坐标 (面向 -Z 轴)
        Vector3[] vertices = new Vector3[4]
        {
            new Vector3(-0.5f, -0.5f, 0),  // 左下
            new Vector3(0.5f, -0.5f, 0),   // 右下
            new Vector3(-0.5f, 0.5f, 0),   // 左上
            new Vector3(0.5f, 0.5f, 0)     // 右上
        };
    
        // 三角形索引 (2个三角形组成四边形)
        int[] triangles = new int[6]
        {
            0, 2, 1, // 第一个三角形
            1, 2, 3  // 第二个三角形
        };
    
        // UV 坐标
        Vector2[] uv = new Vector2[4]
        {
            new Vector2(0, 0),  // 左下
            new Vector2(1, 0),  // 右下
            new Vector2(0, 1),  // 左上
            new Vector2(1, 1)   // 右上
        };
    
        // 法线 (全部朝向 -Z 轴)
        Vector3[] normals = new Vector3[4]
        {
            -Vector3.forward,
            -Vector3.forward,
            -Vector3.forward,
            -Vector3.forward
        };
    
        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.uv = uv;
        mesh.normals = normals;
    
        return mesh;
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
    public int AddInstance(Vector3 position, uint damage)
    {
        return model.AddInstance(position, damage,new Vector3(1,1,1));
    }
    public int AddInstance(Vector3 position, uint damage,Vector3 Color)
    {
        return model.AddInstance(position, damage,Color);
    }
    
    public int AddInstance(Vector3 position, uint damage,Color Color)
    {
        return model.AddInstance(position, damage,new Vector3(Color.r, Color.g, Color.b));
    }
    
    public void UpdateInstance(int index, Vector3 position, Quaternion rotation, Vector3 scale)
    {
        ref var instance = ref model.GetInstance(index);
        instance.position = position;
    }
    
    public void ClearAllInstances()
    {
        model.ClearAllInstances();
    }
}