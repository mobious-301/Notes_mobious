# 在Unity Shader中实现固定贴图绑定

在Unity Shader中，有几种方法可以实现固定贴图绑定，避免每次都需要手动设置贴图：

## 方法一：使用默认纹理属性

```shader
Shader "Custom/FixedTexture"
{
    Properties
    {
        // 其他属性...
    }
    SubShader
    {
        // 在CGPROGRAM中直接声明和使用纹理
        sampler2D _FixedTex;
        
        // 如果使用URP/LWRP/HDRP，可能需要这样声明：
        // TEXTURE2D(_FixedTex);
        // SAMPLER(sampler_FixedTex);
        
        CGPROGRAM
        #pragma surface surf Lambert
        
        struct Input
        {
            float2 uv_MainTex;
        };
        
        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D(_FixedTex, IN.uv_MainTex);
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
```

然后在脚本中通过以下方式设置固定贴图：

```csharp
[SerializeField] private Texture2D fixedTexture;

void Start()
{
    Material mat = GetComponent<Renderer>().material;
    mat.SetTexture("_FixedTex", fixedTexture);
}
```

## 方法二：使用全局纹理（适用于多个材质共享同一贴图）

1. 在Shader中使用全局纹理：

```shader
Shader "Custom/GlobalTexture"
{
    Properties
    {
        // 其他属性...
    }
    SubShader
    {
        CGPROGRAM
        #pragma surface surf Lambert
        
        // 声明全局纹理
        uniform sampler2D _GlobalFixedTex;
        
        struct Input
        {
            float2 uv_MainTex;
        };
        
        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D(_GlobalFixedTex, IN.uv_MainTex);
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
```

2. 在C#脚本中设置全局纹理：

```csharp
public Texture2D globalFixedTexture;

void Start()
{
    Shader.SetGlobalTexture("_GlobalFixedTex", globalFixedTexture);
}
```

## 方法三：将纹理嵌入Shader（适用于小纹理）

```shader
Shader "Custom/EmbeddedTexture"
{
    Properties
    {
        // 其他属性...
    }
    SubShader
    {
        CGPROGRAM
        #pragma surface surf Lambert
        
        // 内嵌纹理数据
        uniform sampler2D _EmbeddedTex = 
        {
            // 这里可以放置纹理数据，但通常不推荐手动编写
            // 更实用的方法是使用资源加载
        };
        
        struct Input
        {
            float2 uv_MainTex;
        };
        
        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = tex2D(_EmbeddedTex, IN.uv_MainTex);
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
```

## 最佳实践推荐

对于大多数情况，推荐使用方法一或方法二：

1. **单个材质使用固定贴图**：使用方法一，在材质初始化时设置一次即可
2. **多个材质共享固定贴图**：使用方法二的全局纹理方法
3. **URP/HDRP管线**：可能需要使用`TEXTURE2D`和`SAMPLER`宏，并确保纹理在管线资源中正确配置

如果贴图是项目中的资源，也可以考虑使用`Resources.Load`在Shader加载时自动设置：

```csharp
void Awake()
{
    Texture2D fixedTex = Resources.Load<Texture2D>("Textures/FixedTexture");
    GetComponent<Renderer>().material.SetTexture("_FixedTex", fixedTex);
}
```

这样只需确保纹理放在Resources文件夹下，Shader就会自动加载并使用固定贴图。