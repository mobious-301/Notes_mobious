Shader "Hidden/FlareDraw"
{
    Properties
    {
        _FlareTex ("Flare Texture", 2D) = "white" {}
        _FlareColor ("Flare Color", Color) = (1,1,1,1)
        _FlareSize ("Base Flare Size", Vector) = (0.05, 0.05, 0, 0)
        _IntensityScale ("Intensity Scale", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct FlareData
            {
                float2 position;  // 屏幕空间UV坐标 (0-1)
                float intensity;  // 亮度强度
            };

            StructuredBuffer<FlareData> _FlareBuffer;
            int _FlareCount;
            
            sampler2D _FlareTex;
            float4 _FlareColor;
            float2 _FlareSize;
            float _IntensityScale;

            struct Attributes
            {
                uint vertexID : SV_VertexID;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : TEXCOORD1;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // 获取当前实例的光晕数据
                FlareData flare = _FlareBuffer[input.instanceID];
                
                // 计算四边形顶点 (0-3对应四个顶点)
                uint quadVertexID = input.vertexID % 4;
                float2 uv = float2(
                    (quadVertexID == 0 || quadVertexID == 3) ? 0.0 : 1.0,
                    (quadVertexID == 0 || quadVertexID == 1) ? 0.0 : 1.0
                );
                
                // 计算顶点偏移 (基于亮度的动态大小)
                float2 size = _FlareSize * flare.intensity * _IntensityScale;
                float2 offset = (uv - 0.5) * 2.0 * size;
                
                // 转换为裁剪空间坐标
                float2 screenPos = flare.position * 2.0 - 1.0;
                
                // 处理DX/OpenGL平台差异
                #if UNITY_UV_STARTS_AT_TOP
                screenPos.y *= -1;
                #endif
                
                output.positionCS = float4(screenPos + offset, 0.0, 1.0);
                output.uv = uv;
                
                // 基于亮度调整颜色
                output.color = _FlareColor;
                output.color.a *= saturate(flare.intensity);
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 texColor = tex2D(_FlareTex, input.uv);
                // return texColor * input.color;
                return 100;
            }
            ENDHLSL
        }
    }
}
