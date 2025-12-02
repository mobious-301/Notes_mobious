Shader "Custom/EdgeIntersection"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _EdgeColor ("Edge Color", Color) = (1, 1, 1, 1)
        _MaskDepthFadeDistance("_MaskDepthFadeDistance 接触边缘宽度", Float) = 1
        _MaskDepthFadeExp("_MaskDepthFadeExp 接触边缘宽度", Float) = 1


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
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.screenPos = ComputeScreenPos(output.positionCS);
                return output;
            }


            float4 frag(Varyings input) : SV_Target
            {
                // float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

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

                return float4(depthDiff.xxx, 1);
            }
            ENDHLSL
        }
    }
}
