Shader "Custom/heightWS"
{
    Properties
    {
        _MainTex ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        [Toggle(_ALPHATEST_ON)] _AlphaTestToggle ("Alpha Test", Float) = 0
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _CameraDepthTextureHeight ("_CameraDepthTextureHeight", 2D) = "white" {}
        _HeightCameraOffset("_HeightCameraOffset  xy为 正交相机size - 世界空间 xz",Vector) = (0, 0, 0,0)

        _CameraHeight("_CameraHeight 世界空间 xz", Float) =0

        _maskIns("_maskIns", Range(0.0, 1.0)) = 0.5

        _HeightOffset("_HeightOffset ", Float) =0

        
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            
            // Universal Pipeline Keywords
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float fogFactor : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTextureHeight);
            SAMPLER(sampler_CameraDepthTextureHeight);

            

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4 _BaseColor;
                float _Cutoff;
                float4 _HeightCameraOffset;
                float _maskIns;
                float _CameraHeight;
                float _HeightOffset;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                // 获取世界空间位置
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                // 获取世界空间法线
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInput.normalWS;

                // UV坐标
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                // 雾效
                output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                return output;
            }

            float4 posMask(float3 pos )//左下角到右上角   基于正交相机尺寸 和偏移构成的有效区域
            {
                float4 area=float4(-25,-25,50,50);

                area.xy = float2(-_HeightCameraOffset.x +_HeightCameraOffset.z,-_HeightCameraOffset.y+_HeightCameraOffset.w);
                area.zw = float2(_HeightCameraOffset.x +_HeightCameraOffset.z,_HeightCameraOffset.y+_HeightCameraOffset.w);


                // area.xy = (float2(-_HeightCameraOffset.z,-_HeightCameraOffset.w)+float2(_HeightCameraOffset.x,_HeightCameraOffset.y)) /float2(_HeightCameraOffset.x,_HeightCameraOffset.y)/2;
                float inRange = step(area.x, pos.x) * step(pos.x, area.z);
                
                
                inRange *= step(area.y, pos.z) * step(pos.z, area.w);
                
                return inRange;

            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // 采样贴图
                half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

               
                half4 color = baseMap * _BaseColor;
                float depth  = SAMPLE_TEXTURE2D(_CameraDepthTextureHeight, sampler_CameraDepthTextureHeight, (input.positionWS.xz+float2(-_HeightCameraOffset.z,-_HeightCameraOffset.w)  +float2(_HeightCameraOffset.x,_HeightCameraOffset.y))   /float2(_HeightCameraOffset.x,_HeightCameraOffset.y)/2);
                float linearDepth = LinearEyeDepth(depth, _ZBufferParams);  //近裁切 和远裁切平面   必须跟深度相机相同

                float height = _CameraHeight - depth*1000;

                color = height+_HeightOffset;

                // Alpha测试
                #ifdef _ALPHATEST_ON
                    clip(color.a - _Cutoff);
                #endif

                // 获取主光源
                Light mainLight = GetMainLight();
                
                // 简单光照计算
                float NdotL = saturate(dot(input.normalWS, mainLight.direction));
                // color.rgb *= NdotL * mainLight.color;

                // 应用雾效
                // color.rgb = MixFog(color.rgb, input.fogFactor);



                // color *= saturate(posMask(input.positionWS)+1-_maskIns); // 获得mask



                return color;
            }
            ENDHLSL
        }
    }
}
