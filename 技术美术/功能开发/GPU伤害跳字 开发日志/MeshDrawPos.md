# DrawMeshInstancedPos 关键代码分析

## 核心优化与改进

这个版本相比前一个实现有几个重要改进：
1. **使用ComputeBuffer替代MaterialPropertyBlock** - 更高效的GPU数据传输
2. **完整的视锥体裁剪系统** - 包括近/远平面计算和边界扩展
3. **自动检测变换更新** - 只在位置变化时更新缓冲区
4. **更完善的资源管理** - 显式释放ComputeBuffer

## 关键代码解析

### 1. ComputeBuffer初始化（核心数据结构）

```csharp
void InitializeBuffers()
{
    int totalCount = horizontalCount * verticalCount;
    
    positionBuffer = new ComputeBuffer(totalCount, 16); // 16 bytes = sizeof(Vector4)
    cachedPositions = new Vector4[totalCount];
    
    UpdatePositions();
    rainMaterial.SetBuffer("_PositionBuffer", positionBuffer);
    
    buffersInitialized = true;
}
```

**关键点**：
- 创建ComputeBuffer存储所有实例位置(每个位置是16字节的Vector4)
- 同时维护CPU端的缓存数组`cachedPositions`
- 将buffer绑定到材质

### 2. 位置更新逻辑

```csharp
void UpdatePositions()
{
    float totalWidth = (horizontalCount - 1) * rainSpacing;
    float totalDepth = (verticalCount - 1) * rainSpacing;
    Vector3 centerOffset = new Vector3(-totalWidth * 0.5f, 0, -totalDepth * 0.5f);

    for (int x = 0; x < horizontalCount; x++)
    {
        for (int z = 0; z < verticalCount; z++)
        {
            int index = x * verticalCount + z;
            Vector3 localPos = centerOffset + new Vector3(x * rainSpacing, 0, z * rainSpacing);
            cachedPositions[index] = transform.TransformPoint(localPos);
            cachedPositions[index].w = rainHeight; // 使用w分量存储高度
        }
    }
    
    positionBuffer.SetData(cachedPositions); // 上传到GPU
}
```

**优化点**：
- 使用w分量存储雨高信息，减少需要传递的数据量
- 只在transform变化时更新(通过`transform.hasChanged`检测)
- 中心点自动计算确保对称分布

### 3. 视锥体计算与裁剪

```csharp
void UpdateFrustumBounds()
{
    // 获取8个视锥体角点(近平面4个+远平面4个)
    _camera.CalculateFrustumCorners(
        new Rect(0, 0, 1, 1),
        _camera.nearClipPlane,
        Camera.MonoOrStereoscopicEye.Mono,
        frustumCorners
    );

    // 变换到世界空间
    for (int i = 0; i < 8; i++)
    {
        frustumCorners[i] = _camera.transform.TransformPoint(frustumCorners[i]);
    }

    // 计算带安全边界的包围盒
    renderBounds = GeometryUtility.CalculateBounds(frustumCorners, Matrix4x4.identity);
    renderBounds.Expand(boundsMargin); // 添加安全边界
}
```

**关键改进**：
- 同时考虑近/远平面的完整视锥体
- 添加边界margin防止边缘裁剪
- 每帧更新确保准确性

### 4. 渲染调用（核心渲染路径）

```csharp
Graphics.DrawMeshInstancedProcedural(
    rainMesh,
    0,
    rainMaterial,
    renderBounds, // 使用动态计算的视锥体边界
    horizontalCount * verticalCount,
    null, // 使用材质中的buffer而不是property block
    ShadowCastingMode.Off,
    false,
    0
);
```

**关键参数**：
- 使用ComputeBuffer而不是MaterialPropertyBlock
- 动态边界框提高裁剪效率
- 禁用阴影投射

### 5. 资源清理

```csharp
void OnDisable()
{
    if (positionBuffer != null)
    {
        positionBuffer.Release(); // 必须显式释放ComputeBuffer
        positionBuffer = null;
    }
    buffersInitialized = false;
}
```

**重要事项**：
- ComputeBuffer必须手动释放
- 避免GPU内存泄漏

## 着色器关键配合

这个实现需要着色器中包含以下关键部分：
1. 声明`StructuredBuffer<float4> _PositionBuffer`接收位置数据
2. 使用实例ID索引缓冲区获取位置
3. 利用w分量中的高度信息计算最终位置

这种实现方式特别适合超大规模实例渲染(数万+实例)，在保持高性能的同时提供精确的视锥体裁剪。