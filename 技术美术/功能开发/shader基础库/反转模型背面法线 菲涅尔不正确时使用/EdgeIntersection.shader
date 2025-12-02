Shader "Custom/EdgeIntersection"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _EdgeColor ("Edge Color", Color) = (1, 1, 1, 1)
        _MaskDepthFadeDistance("_MaskDepthFadeDistance 接触边缘宽度", Float) = 1
        _MaskDepthFadeExp("_MaskDepthFadeExp 接触边缘硬度", Float) = 1

        _MaskFresnelExp("_MaskFresnelExp 模型边缘宽度", Float) = 1



        _Cull("__cull", Float) = 2.0

    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            // Blend[_SrcBlend][_DstBlend]
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
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
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _EdgeColor;
            float _EdgeWidth;
            float _EdgeStrength;
            float _depthOffset;

            float _MaskDepthFadeDistance;
            float _MaskDepthFadeExp;
            float _MaskFresnelExp;
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
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.screenPos = ComputeScreenPos(output.positionCS);
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
                float3 noiseCoords = worldPosition * noiseTiling + time * scrollSpeed + distortion;

                // 为不同方向生成二维噪声采样坐标
                float2 uvXY = float2(noiseCoords.x, noiseCoords.y);
                float2 uvYZ = float2(noiseCoords.y, noiseCoords.z);
                float2 uvZX = float2(noiseCoords.z, noiseCoords.x);

                // 在三个方向上采样噪声纹理
                float noiseXY = tex2D(noiseTexture, uvXY).r;
                float noiseYZ = tex2D(noiseTexture, uvYZ).r;
                float noiseZX = tex2D(noiseTexture, uvZX).r;

                // 使用法线权重对噪声值进行加权混合
                float weightedNoise = normalWeights.x * noiseXY +
                                    normalWeights.y * noiseYZ +
                                    normalWeights.z * noiseZX;

                return weightedNoise; // 返回加权后的噪声值
            }

            // 简单线性混合
            float3 BlendNormalsLinear(float3 n1, float3 n2, float factor)
            {
                return normalize(lerp(n1, n2, factor));
            }

            // Unity风格的法线混合
            float3 BlendNormalsUnity(float3 n1, float3 n2)
            {
                return normalize(float3(n1.xy + n2.xy, n1.z * n2.z));
            }


            // RNM混合（Reoriented Normal Mapping）
            float3 BlendNormalsRNM(float3 n1, float3 n2)
            {
                n1.z += 1;
                n2.xy = -n2.xy;
                return normalize(n1 * dot(n1, n2) / n1.z - n2);
            }




            float4 frag(Varyings input, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                // float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                //if 深度 接触边缘
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                // 获取场景深度并转换到线性空间
                float sceneZ = SampleSceneDepth(screenUV);
                float linearSceneDepth = LinearEyeDepth(sceneZ);
                // 获取当前片段深度并转换到线性空间
                float fragmentZ = input.positionCS.z;
                float linearFragmentDepth = LinearEyeDepth(fragmentZ);
                // 计算线性深度差
                float depthDiff = abs((linearSceneDepth - linearFragmentDepth) / _MaskDepthFadeDistance);
                depthDiff= pow( saturate(1-depthDiff), _MaskDepthFadeExp );
                //end if 深度 接触边缘

                //if 菲涅耳
                float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - input.positionWS);
				ase_worldViewDir = normalize(ase_worldViewDir);


                // 获取和规范化世界空间法线
                float3 normalWS = normalize(input.normalWS);
                
                // 计算反转的法线

                float3 finalNormal  =  normalWS *lerp(-1,1,isFrontFace);
                

                float Fresnel = saturate(dot( ase_worldViewDir , finalNormal));

                Fresnel = pow( ( 1.0 - Fresnel ) , _MaskFresnelExp );
                //end if 菲涅耳
                
                float baseShap = saturate( max( Fresnel, depthDiff ) );

                return float4(baseShap.xxx, 1);
            }
            ENDHLSL
        }
    }
}
