在Unity的URP（Universal Render Pipeline）中，两种PBR（Physically Based Rendering）工作流（**金属/粗糙度工作流**和**高光/光泽度工作流**）主要通过以下宏和Shader代码实现：

### 1. **工作流选择宏**
URP的PBR Shader（如`Lit.shader`）通过宏定义来区分不同的PBR工作流：
- **金属/粗糙度工作流（Metallic/Roughness）**：
  - 使用 `_METALLICSPECGLOSSMAP` 宏判断是否使用金属度贴图。
  - 粗糙度通常存储在金属度贴图的Alpha通道（`_MetallicGlossMap.a`）。
- **高光/光泽度工作流（Specular/Glossiness）**：
  - 使用 `_SPECGLOSSMAP` 宏判断是否使用高光贴图。
  - 光滑度（Glossiness）存储在高光贴图的Alpha通道（`_SpecGlossMap.a`）。

### 2. **关键Shader代码**
在URP的`LitInput.hlsl`中，通过以下逻辑选择不同的PBR参数计算方式：
```hlsl
#ifdef _METALLICSPECGLOSSMAP
    // 金属/粗糙度工作流
    metallic = SAMPLE_METALLICSPECULAR(metallicSpecGlossMap, uv).r;
    smoothness = SAMPLE_METALLICSPECULAR(metallicSpecGlossMap, uv).a;
#elif defined(_SPECGLOSSMAP)
    // 高光/光泽度工作流
    specColor = SAMPLE_SPECULAR(specGlossMap, uv).rgb;
    smoothness = SAMPLE_SPECULAR(specGlossMap, uv).a;
#endif
```

### 3. **材质面板控制**
在Shader的`Properties`中，URP提供了选项让用户选择工作流：
```hlsl
[KeywordEnum(Metallic, Specular)] _WorkflowMode("Workflow Mode", Float) = 0.0
```
- `_WorkflowMode` 为 `0` 时使用金属/粗糙度工作流。
- `_WorkflowMode` 为 `1` 时使用高光/光泽度工作流。

### 4. **URP内置实现**
URP的`Lit.shader`默认支持两种工作流，并通过以下方式切换：
- **金属工作流**：读取 `_Metallic` 和 `_Smoothness` 参数。
- **高光工作流**：读取 `_SpecColor` 和 `_Glossiness` 参数。

### 总结
URP通过宏（如`_METALLICSPECGLOSSMAP`、`_SPECGLOSSMAP`）和Shader变体实现两种PBR工作流的切换，开发者可以在材质面板中选择合适的工作流模式。