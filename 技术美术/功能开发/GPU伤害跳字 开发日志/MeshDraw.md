# InstancedMeshRenderer 关键代码分析

## 核心实现思路

这个脚本使用 **GPU Instancing** 技术高效渲染大量雨滴，主要特点：
- 预计算雨滴分布位置（XZ平面网格排列）
- 动态基于摄像机视锥体调整可见范围
- 使用MaterialPropertyBlock高效传递实例数据

## 关键代码解析

### 1. 初始化实例位置（核心数据结构）

```csharp
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
```

**关键点**：
- 创建网格排列的雨滴位置数组（以摄像机为中心）
- 使用Vector4数组存储位置（最后一个w分量可用于其他数据）
- 通过MaterialPropertyBlock将数据传递到GPU

### 2. 视锥体计算（可见性控制）

```csharp
// 计算视锥体角点
Rect rect = new Rect(0, 0, 1, 1);
Vector3[] corners = new Vector3[5];
_camera.CalculateFrustumCorners(rect, _camera.farClipPlane, Camera.MonoOrStereoscopicEye.Mono, corners);
corners[4] = Vector3.zero;

// 计算视锥体包围盒
Bounds frustumBounds = GeometryUtility.CalculateBounds(corners, _camera.transform.localToWorldMatrix);
```

**关键点**：
- 获取摄像机远裁剪平面的四个角点
- 计算世界空间下的视锥体包围盒
- 用于后续在着色器中做剔除判断

### 3. 实例化渲染（核心渲染调用）

```csharp
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
```

**关键参数**：
- `rainMesh`: 每个实例使用的网格（如简单的线段或雨滴模型）
- `rainMaterial`: 必须支持GPU Instancing的材质
- 超大包围盒确保不会被意外剔除
- `_propertyBlock`: 包含实例位置数据的属性块
- 禁用阴影以提高性能

### 4. 着色器参数传递

```csharp
rainMaterial.SetVector("_RainMin", frustumBounds.min);
rainMaterial.SetVector("_RainMax", frustumBounds.max);
rainMaterial.SetInt("_InstanceCount", horizontalCount * verticalCount);
rainMaterial.SetFloat("_RainHeight", height);
```

**关键参数**：
- 将视锥体边界传递给着色器用于剔除
- 传递实例总数和雨高参数
- 这些参数在着色器中用于确定雨滴位置和可见性

## 关键实现技巧

1. **位置预处理**：
   - XZ平面位置在初始化时预计算
   - Y轴位置在着色器中动态计算（基于摄像机高度）

2. **高效数据传输**：
   - 使用MaterialPropertyBlock而不是Material.SetXXX
   - 避免创建材质实例拷贝

3. **视锥体优化**：
   - 在CPU端计算粗略的视锥体范围
   - 精确剔除在着色器中完成

这个实现的关键在于将大部分计算放在初始化阶段，渲染时只更新必要参数，非常适合大量重复对象的渲染。