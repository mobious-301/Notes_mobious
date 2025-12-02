// FlareComposite.shader
Shader "Hidden/LX_Post_Effects/BrightnessFlares"
{
    HLSLINCLUDE
    // # define  _USE_DRAW_PROCEDURAL = true
    #pragma multi_compile _ _USE_DRAW_PROCEDURAL
    #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // #pragma vertex Vert
            // #pragma fragment Frag
    
            
            

            StructuredBuffer<float4> _FlareBuffer;
    // 获取缓冲区长度

            int _FlareCount;
            // Texture2D _FlareTex;
            // float4 _FlareTex_ST;
            TEXTURE2D(_FlareTex);
            SAMPLER(sampler_FlareTex);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
    

            // struct Attributes {
            //     float4 positionOS : POSITION;
            //     float2 uv : TEXCOORD0;
            // };
            //
            struct VaryingsA {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float brightness : TEXCOORD1;
            };
            //
            // Varyings Vert(Attributes input)
            // {
            //     Varyings output;
            //     output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            //     output.uv = input.uv;
            //     return output;
            // }

    float4 GetQuadVertexPositionA(uint vertexID, float z = UNITY_NEAR_CLIP_VALUE)
    {
        uint topBit = vertexID >> 1;
        uint botBit = (vertexID & 1);
        float x = topBit;
        float y = 1 - (topBit + botBit) & 1; // produces 1 for indices 0,3 and 0 for 1,2
        float4 pos = float4(x, y, z, 1.0);
    #ifdef UNITY_PRETRANSFORM_TO_DISPLAY_ORIENTATION
        pos = ApplyPretransformRotation(pos);
    #endif
        return pos;
    }
    uint getIDgroup(uint id)
{
    return id / 4;
}
    // float4 GetQuadVertexPositionB(uint vertexID, float z = UNITY_NEAR_CLIP_VALUE)
    // {
    //
    //      float4 bufferI = _FlareBuffer[getIDgroup(input.vertexID)];
    //     int i = vertexID%4;
    //     if (i)
    //     return pos;
    // }

    float4 _vertexPos[10];


            VaryingsA FullscreenVertA(Attributes input)
            {
                VaryingsA output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #if _USE_DRAW_PROCEDURAL
                    output.positionCS = GetQuadVertexPosition(input.vertexID);

                    // for (int i=0;i<_FlareBuffer.Length;i++)
                    // {
                    //     _vertexPos[i]=i;
                    // }
                float IDgroup = getIDgroup(input.vertexID);
                    output.positionCS.x -= 2 * IDgroup;
output.positionCS.xy /= 100;
                float3 BufferInfo = _FlareBuffer[IDgroup];
                // float2 posoffset = BufferInfo.xy;
                output.positionCS.xy += BufferInfo.xy/float2(1920,1080)*40;
                // output.positionCS.xy += BufferInfo.xy;
                output.positionCS.xy = output.positionCS.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f); //convert to -1..1

                output.uv = GetQuadTexCoord(input.vertexID) ;
                output.brightness = 1;

                // output.positionCS.xy = _FlareBuffer[input.vertexID];

                    

                
                #else
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    output.uv = input.uv;
                    output.brightness = 1;
                #endif

                return output;
            }

            half4 FragA(VaryingsA input) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                col=0;
                
                // // // 绘制光斑
                // for (int i = 0; i < _FlareCount; i++) {
                //     float4 flare = _FlareBuffer[i];
                //     float2 uv = (input.uv - flare.xy) * 10.0; // 控制光斑大小
                //     float falloff = 1.0 - saturate(length(uv));
                //     // col.rgb += _FlareTex.Sample(sampler_FlareTex, uv).rgb 
                //     //          * flare.z * falloff;
                //     col.rgb +=  SAMPLE_TEXTURE2D(_FlareTex, sampler_FlareTex, input.uv* flare.z * falloff);
                // }
                col = SAMPLE_TEXTURE2D(_FlareTex, sampler_FlareTex, input.uv);
                // return col*0.03;
                return col;
            }

    
    ENDHLSL
    Properties
        {
            _MainTex("Base Map", 2D) = "white" {}
            _FlareTex("Flare Texture", 2D) = "white" {}
        }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        

        Pass
        {
            Name "Bloom Blur Vertical"
            ztest off
            cull off
            Blend OneMinusDstColor One
            HLSLPROGRAM
            
            #pragma vertex FullscreenVertA
            #pragma fragment FragA
            ENDHLSL
        }
    }
}
