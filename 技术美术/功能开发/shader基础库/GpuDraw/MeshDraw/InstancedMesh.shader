Shader "Custom/InstancedMesh"
{
    Properties
    {
        [HDR]_Color ("Color", Color) = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white" {}
        _RainHeight ("Rain Height", Float) = 30
        _RainAreaSize ("Rain Area Size", Vector) = (10, 10, 0, 0)
        _RainSpacing ("Rain Spacing", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        ZWrite Off
        Blend SrcAlpha One

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                float alpha : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _MainTex_ST;
                float _RainHeight;
                float2 _RainAreaSize;
                float _RainSpacing;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            Varyings vert(Attributes input, uint instanceID : SV_InstanceID)
            {
                Varyings output;
                
                // Calculate grid position based on instanceID
                uint gridWidth = (uint)(_RainAreaSize.x / _RainSpacing);
                uint x = instanceID % gridWidth;
                uint z = instanceID / gridWidth;
                
                // Calculate world position
                float3 worldPos = float3(
                    x * _RainSpacing - _RainAreaSize.x * 0.5f,
                    _RainHeight,
                    z * _RainSpacing - _RainAreaSize.y * 0.5f
                );
                
                // Apply mesh offset (scaled by original position)
                worldPos += input.positionOS.xyz * 0.1f;
                
                // Transform to clip space
                output.positionCS = TransformWorldToHClip(worldPos);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                // Simple fade based on height
                output.alpha = 1.0;
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;
                // col.a *= input.alpha;
                return 0.9;
            }
            ENDHLSL
        }
    }
}