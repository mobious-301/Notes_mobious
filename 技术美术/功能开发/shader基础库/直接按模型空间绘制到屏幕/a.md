# Unity Shader 裁剪空间与屏幕空间转换分析

## 代码解析

```hlsl
output.positionCS = mul(UNITY_MATRIX_VP, float4(worldPos, 1.0));
                
output.positionCS.xyz = input.positionOS.xyz;
output.positionCS.xyz *= output.positionCS.w;

output.positionCS.z = 1;
```

## 坐标空间转换流程

1. **默认处理流程**：
   - Unity 将顶点从模型空间转换到裁剪空间(Clip Space)
   - GPU 自动执行透视除法：`(x/w, y/w, z/w)`
   - 转换为标准化设备坐标(NDC)：范围[-1,1]或[0,1]

2. **代码中的特殊处理**：
   - 首先计算标准的裁剪空间坐标
   - 然后用模型空间坐标(input.positionOS)替换裁剪空间坐标
   - 通过乘以w分量(`*= output.positionCS.w`)抵消后续的透视除法
   - 强制z值为1确保通过深度测试

## 效果说明

这种处理方式会导致：
1. 模型空间坐标直接映射到屏幕空间
2. 绘制结果在0-1空间范围内
3. 绘制效果会随屏幕分辨率变化而变化
4. 本质上是在屏幕空间直接绘制模型几何形状
```
float aspectRatio = _ScreenParams.y / _ScreenParams.x;

output.positionCS.x *= _ScreenParams.y / _ScreenParams.x;
```
5. 通过乘以屏幕横宽比，抵消幕分辨率对模型的拉伸
## 数学原理

标准转换：
```
裁剪空间 → 透视除法 → NDC → 视口变换 → 屏幕空间
```

修改后的转换：
```
模型空间坐标 * w → (模拟裁剪空间) → 透视除法 → 模型空间坐标 → 屏幕空间
```

## 应用场景

这种技术可以用于：
- 屏幕空间特效
- UI元素的特殊渲染
- 需要忽略透视的2D渲染效果
- 特殊后处理效果

## 注意事项

1. 绘制结果会随分辨率变化
2. 深度值被固定为1，可能影响混合和深度测试
3. 需要谨慎处理坐标系转换
4. 在VR/多摄像机场景中可能有意外行为