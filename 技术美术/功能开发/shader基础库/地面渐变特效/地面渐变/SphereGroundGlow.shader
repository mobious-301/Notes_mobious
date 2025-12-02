Shader "Custom/SphereGroundGlow"
{
    Properties
    {

        // [Toggle(_ENABLE_EFFECT)] _EnableEffect ("Enable Effect", Float) = 0

        // _MainTex ("Texture", 2D) = "white" {}
        // _RampColor("_Ramp  Color", Color) = (1, 1, 1, 1)
        
        // _Ramp ("_Ramp", 2D) = "white" {}
        // _FinalPower("_FinalPower 噪声贴图 强度", Range(0,20)) = 1



        _EdgeColor ("Edge Color", Color) = (1, 1, 1, 1)
        _MaskDepthFadeDistance("_MaskDepthFadeDistance 接触边缘宽度", Float) = 3
        _MaskDepthFadeExp("_MaskDepthFadeExp 接触边缘硬度", Float) = 1

        // _MaskFresnelExp("_MaskFresnelExp 模型边缘宽度", Float) = 4
        
        // _NoiseTexture("_NoiseTexture 噪声贴图", 2D) = "white" {}
        // _Noise01Tiling("_Noise01Tiling 扰动尺寸", Float) = 1
        // _Noise01ScrollSpeed("_Noise01ScrollSpeed 噪声流动速度", Float) = 1
        // _NoiseMaskAdd("_NoiseMaskAdd 噪声贴图 强度", Range(0,1)) = 1

        // _MaskAppearNoise("_MaskAppearNoise 显隐遮罩 贴图", 2D) = "white" {}
        // _MaskAppearLocalYAdd("_MaskAppearLocalYAdd 显隐遮罩 位置",Range(-1,1)) = 0
        // _MaskAppearProgress("_MaskAppearProgress 显隐遮罩 过程",Range(-2,2)) = 0
        



        _Cull("__cull", Float) = 2.0

    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "BackfaceDepth"
            Cull Front // 剔除正面
            ZTest off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _ENABLE_EFFECT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 viewPos : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _MaskDepthFadeDistance;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.screenPos = ComputeScreenPos(output.positionCS);
                output.viewPos = TransformObjectToHClip(input.positionOS.xyz);
                
                return output;
            }

            float GetSceneDepth(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
            }


            float CalculateDepthFade(float4 screenPos)
            {
                float4 positionNorm = screenPos / screenPos.w;
                positionNorm.z = (UNITY_NEAR_CLIP_VALUE >= 0) ? positionNorm.z : positionNorm.z * 0.5 + 0.5;
                
                float sceneDepth = LinearEyeDepth(GetSceneDepth(positionNorm.xy), _ZBufferParams);
                float surfaceDepth = LinearEyeDepth(positionNorm.z, _ZBufferParams);
                
                // return abs((sceneDepth - 1-surfaceDepth) / fadeDistance);
                return (sceneDepth - surfaceDepth) ;
            }

            float4 frag(Varyings input) : SV_Target
            {

                float CullArea=  saturate(CalculateDepthFade(input.screenPos)/-0.001);
                float CullAreaLerp=  saturate(CalculateDepthFade(input.screenPos)/-_MaskDepthFadeDistance);

                return CullArea*(1-CullAreaLerp); // 除以20用于可视化
            }
            ENDHLSL
        }
    }
}
