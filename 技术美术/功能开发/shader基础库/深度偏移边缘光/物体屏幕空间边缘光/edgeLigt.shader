Shader "Custom/EdgeIntersection a"
{
    Properties
    {
        // [Toggle(_ENABLE_EFFECT)] _EnableEffect ("Enable Effect", Float) = 0
        // _MainTex ("Texture", 2D) = "white" {}
        _RampColor("_Ramp  Color", Color) = (1, 1, 1, 1)
        
        _Ramp ("_Ramp", 2D) = "white" {}
        _FinalPower("_FinalPower 最终 强度", Range(0,20)) = 3

        _FinalExp("_FinalExp 模型边缘硬度", Range(0,10)) = 1
        _OpacityPower("_OpacityPower 噪声贴图 强度", Range(0,4)) = 1



        // _EdgeColor ("Edge Color", Color) = (1, 1, 1, 1)
        _MaskDepthFadeDistance("_MaskDepthFadeDistance 接触边缘宽度", Float) = 3
        _MaskDepthFadeExp("_MaskDepthFadeExp 接触边缘硬度", Float) = 1

        _MaskFresnelExp("_MaskFresnelExp 模型边缘宽度", Float) = 4
        _MaskFresnelPower("_MaskFresnelPower 模型边缘强度", Range(0,1)) = 1

        
        _NoiseTexture("_NoiseTexture 噪声贴图", 2D) = "white" {}
        _Noise01Tiling("_Noise01Tiling 扰动尺寸", Float) = 1
        _Noise01ScrollSpeed("_Noise01ScrollSpeed 噪声流动速度", Float) = 1
        _NoiseMaskAdd("_NoiseMaskAdd 噪声贴图 强度", Range(0,1)) = 1

        _MaskAppearNoise("_MaskAppearNoise 显隐遮罩 贴图", 2D) = "white" {}
        _MaskAppearLocalYAdd("_MaskAppearLocalYAdd 显隐遮罩 位置",Range(-1,1)) = 0
        _MaskAppearProgress("_MaskAppearProgress 显隐遮罩 过程",Range(-2,2)) = 0
        



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
            // Blend[_SrcBlend][_DstBlend]
            // Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull[_Cull]
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float3 positionOS : TEXCOORD4;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            sampler2D _NoiseTexture;
            // sampler2D _MaskAppearNoise;
            TEXTURE2D(_MaskAppearNoise);
            SAMPLER(sampler_MaskAppearNoise);
            TEXTURE2D(_Ramp);
            SAMPLER(sampler_Ramp);

            
            
            

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _MaskAppearNoise_ST;
            float4 _RampColor;
            float _FinalPower;

            // float4 _EdgeColor;
            float _EdgeWidth;
            float _EdgeStrength;
            float _depthOffset;

            float _MaskDepthFadeDistance;
            float _MaskDepthFadeExp;
            float _MaskFresnelExp;

            float _Noise01Tiling;
            float _Noise01ScrollSpeed;

            float _NoiseMaskAdd;
            float _MaskAppearLocalYAdd;
            float _MaskAppearProgress;
            float _OpacityPower;
            float _MaskFresnelPower;
            float _FinalExp;
            CBUFFER_END

            // 线性深度转换函数
            float LinearEyeDepth(float z)
            {
                float near = _ProjectionParams.y;
                float far = _ProjectionParams.z;

                #if UNITY_REVERSED_Z
                z = 1.0 - z;
                #endif

                z = 2.0 * z - 1.0;
                return (2.0 * near * far) / (far + near - z * (far - near));
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MaskAppearNoise);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.screenPos = ComputeScreenPos(output.positionCS);

                output.positionOS = input.positionOS.xyz;
                return output;
            }




            // 封装的函数：基于位置、时间和法线权重计算加权噪声值
            float ComputeWeightedNoise(
                float3 worldPosition,    // 世界空间中的片段位置
                float3 normalWeights,    // 法线方向的权重（通常是法线绝对值平方）
                float noiseTiling,       // 噪声的平铺比例
                float scrollSpeed,       // 噪声滚动速度
                sampler2D noiseTexture,  // 噪声纹理
                float time,              // 时间参数，用于滚动
                float3 distortion        // 动态失真或偏移值
            ) {
                // 计算噪声的基础采样坐标
                float3 noiseCoords = worldPosition * noiseTiling/10 + time * scrollSpeed/5 + distortion;

                // 为不同方向生成二维噪声采样坐标
                float2 uvXY = float2(noiseCoords.x, noiseCoords.y);
                float2 uvYZ = float2(noiseCoords.y, noiseCoords.z);
                float2 uvZX = float2(noiseCoords.z, noiseCoords.x);

                // 在三个方向上采样噪声纹理
                float noiseXY = tex2D(noiseTexture, uvXY).r;
                float noiseYZ = tex2D(noiseTexture, uvYZ).r;
                float noiseZX = tex2D(noiseTexture, uvZX).r;

                // 使用法线权重对噪声值进行加权混合
                float weightedNoise = normalWeights.z * noiseXY +
                                    normalWeights.x * noiseYZ +
                                    normalWeights.y * noiseZX;

                return weightedNoise; // 返回加权后的噪声值
            }


            float3 ReverseBackNormal(float3 normalWS,float isFrontFace){ //isFrontFace 来自片元着色器输入 bool isFrontFace : SV_IsFrontFace
                return normalWS *lerp(-1,1,isFrontFace);
            }
            // SHADERGRAPH_SAMPLE_SCENE_DEPTH 是 ShaderGraph 中用于采样场景深度的宏。在不同的渲染管线中，可以使用以下对应的深度采样方法：
            // URP
            float GetSceneDepth(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
            }
            float CalculateDepthFade(float4 screenPos, float fadeDistance)
            {
                float4 positionNorm = screenPos / screenPos.w;
                positionNorm.z = (UNITY_NEAR_CLIP_VALUE >= 0) ? positionNorm.z : positionNorm.z * 0.5 + 0.5;
                
                float sceneDepth = LinearEyeDepth(GetSceneDepth(positionNorm.xy+float2(-0.02*saturate(1-fadeDistance*10),0)), _ZBufferParams);
                float surfaceDepth = LinearEyeDepth(positionNorm.z, _ZBufferParams);
                
                // return abs((sceneDepth - 1-surfaceDepth) / fadeDistance);
                return saturate( pow(((sceneDepth - surfaceDepth) /5),2));
            }




            float4 frag(Varyings input, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                float distance = length(input.screenPos)/1000;

                float depthDiff = CalculateDepthFade( input.screenPos,distance);
                return float4(depthDiff,depthDiff,depthDiff,1);
                // return float4(distance,distance,distance,1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                return 0;
            }

            ENDHLSL
        }
    }
}
