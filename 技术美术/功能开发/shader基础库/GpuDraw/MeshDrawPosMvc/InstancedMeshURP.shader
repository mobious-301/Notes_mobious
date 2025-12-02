Shader "Custom/InstancedColorURP"
{
    Properties
    {
        _BaseColor ("Color", Color) = (1,1,1,1)
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        
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
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
            CBUFFER_END

            // Correct way to declare the matrix buffer in URP
            // #ifdef UNITY_INSTANCING_ENABLED
                StructuredBuffer<float4x4> _MatrixBuffer;
            // #endif
            
            Varyings vert(Attributes input, uint instanceID : SV_InstanceID)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                // #ifdef UNITY_INSTANCING_ENABLED
                    float4x4 data = _MatrixBuffer[instanceID];
                    float4 positionWS = mul(data, float4(input.positionOS.xyz, 1.0));
                // #else
                //     float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // #endif
                
                output.positionCS = TransformWorldToHClip(positionWS.xyz);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                return _BaseColor;
            }
            ENDHLSL
        }
    }
}