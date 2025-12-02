Shader "Custom/Mesh_Ins_Pos"
{
    Properties
    {
        [HDR]_Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _FadeStart ("Fade Start Height", Float) = 5
        _FadeEnd ("Fade End Height", Float) = 0
    }

    SubShader
    {
        Tags {"RenderType"="Transparent" "Queue"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma require compute
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 优化1: 使用StructuredBuffer
            StructuredBuffer<float4> _PositionBuffer;

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _MainTex_ST;
                float _FadeStart;
                float _FadeEnd;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float fade : TEXCOORD1;
            };

            // 优化2: 简化的顶点着色器
            Varyings vert(Attributes input, uint instanceID : SV_InstanceID)
            {
                Varyings output;
                
                // 直接从Buffer获取世界位置
                float4 posData = _PositionBuffer[instanceID];
                float3 worldPos = posData.xyz;
                
                // 添加网格偏移
                worldPos += input.positionOS.xyz * 0.1;
                
                // 计算裁剪空间位置
                output.positionCS = TransformWorldToHClip(worldPos);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                // 优化3: 基于高度的渐变
                float heightPercent = (worldPos.y - _FadeEnd) / (_FadeStart - _FadeEnd);
                output.fade = saturate(heightPercent);
                
                return output;
            }

            // 优化4: 简化的片段着色器
            half4 frag(Varyings input) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;
                col.a *= input.fade;
                return col;
            }
            ENDHLSL
        }
    }
}