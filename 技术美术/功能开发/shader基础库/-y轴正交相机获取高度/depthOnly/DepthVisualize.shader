Shader "Custom/DepthVisualize"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DepthScale ("Depth Scale", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float _DepthScale;

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                // 采样深度纹理
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv).r;
                
                // 转换到线性深度空间
                float linearDepth = LinearEyeDepth(depth, _ZBufferParams);
                // linearDepth *= _DepthScale;
                
                // 将深度映射到颜色
                float3 depthColor = float3(1 - linearDepth, 1 - linearDepth, 1 - linearDepth);
                
                return float4(1-depth.xxx, 1);
            }
            ENDHLSL
        }
    }
}
