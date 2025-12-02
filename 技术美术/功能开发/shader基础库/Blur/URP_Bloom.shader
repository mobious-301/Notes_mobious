
Shader "Hidden/URP_Bloom"
{
    Properties
    {
        _MainTex("Base (RGB)", 2D) = "white" {}
        _Threshold("Threshold", Float) = 1.0
        _Intensity("Intensity", Float) = 0.5
        _MipSigma("Mip Sigma", Float) = 2.0
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

    // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
    // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"


    TEXTURE2D(_SourceTex);

    SAMPLER(sampler_SourceTex);

    // struct Attributes
    // {
        // // uint vertexID : SV_VertexID;
        // // #if _USE_DRAW_PROCEDURAL

        // // #else
        // float4 positionOS : POSITION;
        // float2 uv : TEXCOORD0;
        // // #endif
        // // UNITY_VERTEX_INPUT_INSTANCE_ID
    // };

    // struct Varyings
    // {
        // float4 positionCS : SV_POSITION;
        // float2 uv : TEXCOORD0;

        // // float2 GroupId : TEXCOORD1;
        // // UNITY_VERTEX_OUTPUT_STEREO
    // };

    // Varyings Vert(Attributes input)
    // {
        // Varyings o;

        // // UNITY_SETUP_INSTANCE_ID(input);
        // // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        // // o.vertex = UnityObjectToClipPos(v.vertex);
        // o.positionCS = TransformObjectToHClip(input.positionOS.xyz);
        // o.uv = input.uv;
        // return o;
    // }

    half4 EncodeHDR(half3 color)
    {
        #if _USE_RGBM
        half4 outColor = EncodeRGBM(color);
        #else
        half4 outColor = half4(color, 1.0);
        #endif

        #if UNITY_COLORSPACE_GAMMA
        return half4(sqrt(outColor.xyz), outColor.w); // linear to γ
        #else
        return outColor;
        #endif
    }


    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always



        // Brightness extraction pass
        Pass
        {
            Name "Bloom Prefilter"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragBrightness

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            sampler2D _MainTex;
            float _Threshold;


            half4 FragBrightness(Varyings input) : SV_Target
            {


                // _Threshold = 0.5f;
                // half3 color = tex2D(_MainTex, input.uv).rgb;
                float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
                half3 color = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_SourceTex, uv).xyz;

                // half brightness = dot(color.rgb, half3(0.2126, 0.7152, 0.0722));
                half brightness = max(color.r, max(color.g, color.b));
                // return saturate((brightness - _Threshold) / (1.0 - _Threshold));
                // _Threshold = 1-_Threshold;

                return float4(color * (brightness - _Threshold) / (1.0 - _Threshold),1);
            }
            ENDHLSL
        }

        // half4 FragPrefilter(Varyings input) : SV_Target
        // {
            // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            // float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);

            // half3 color = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv).xyz;

            // // User controlled clamp to limit crazy high broken spec
            // color = min(ClampMax, color);

            // // Thresholding
            // half brightness = Max3(color.r, color.g, color.b);
            // half softness = clamp(brightness - Threshold + ThresholdKnee, 0.0, 2.0 * ThresholdKnee);
            // softness = (softness * softness) / (4.0 * ThresholdKnee + 1e - 4);
            // half multiplier = max(brightness - Threshold, softness) / max(brightness, 1e - 4);
            // color *= multiplier;

            // // Clamp colors to positive once in prefilter. Encode can have a sqrt, and sqrt(- x) == NaN. Up / Downsample passes would then spread the NaN.
            // color = max(color, 0);
            // return EncodeHDR(color);
        // }


        // Bloom upsampling pass
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragUpsampleOpt

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

            // sampler2D _MainTex;
            TEXTURE2D(_MainTex);

            SAMPLER(sampler_MainTex);
            TEXTURE2D(_MipUpLowTex);
            float4 _MipUpLowTex_TexelSize;
            float _MipSigma;
            int _MipLevel;
            int _MipCount;

            float MipGaussianBlendWeight(float2 uv)
            {
                float sigma2 = _MipSigma * _MipSigma;
                float c = 4.0 * PI * sigma2;
                float numerator = (1 << (_MipLevel << 2)) * log(4.0);
                float denominator = c * ((1 << (_MipLevel << 1)) + c);
                return saturate(numerator / denominator);
            }

            half4 FragUpsampleOpt(Varyings input) : SV_Target
            {
                float3 src = SAMPLE_TEXTURE2D_X_LOD(_MainTex, sampler_MainTex, input.uv, _MipLevel);
                float3 coarser = SAMPLE_TEXTURE2D_X(_MipUpLowTex, sampler_MainTex, input.uv);
                float weight = MipGaussianBlendWeight(input.uv);
                return float4(lerp(coarser, src, weight), 1.0);
            }
            ENDHLSL
        }

        // Bloom composition pass
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragBloomComposition

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

            // sampler2D _MainTex;

            TEXTURE2D(_MainTex);

            SAMPLER(sampler_MainTex);


            sampler2D _BloomOptMipDown;
            TEXTURE2D(_BloomMipUp[16]) ; // Assuming a maximum of 16 mip levels
            float _Intensity;
            int _MipLevel;
            int _MipCount;

            float _MipSigma;

            TEXTURE2D(_MipUpLowTex);
            SAMPLER(sampler_MipUpLowTex);


            float4 _MipUpLowTex_TexelSize;

            // float _MipCount;
            float MipGaussianBlendWeight(float2 uv, float mipSigma, int mipLevel, int mipCount)
            {
                // Compute the Gaussian blend weight based on the mipmap level
                const float sigma2 = mipSigma * mipSigma;
                const float c = 4.0 * PI * sigma2;
                const float numerator = (1 << (mipLevel << 2)) * log(4.0);
                const float denominator = c * ((1 << (mipLevel << 1)) + c);
                return saturate(numerator / denominator);
            }


            half4 FragBloomComposition(Varyings input) : SV_Target
            {
                half3 originalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).rgb;
                half3 bloomColor = (0.0).xxx;

                // _MipCount=8;

                // for (int i = _MipCount - 2; i >= 0; i --)
                // {
                    // float weight = MipGaussianBlendWeight(input.uv, _MipSigma, i, _MipCount);
                    // half3 mipColor = SAMPLE_TEXTURE2D(_BloomMipUp[i], sampler_MainTex, input.uv);
                    half3 mipColor = SAMPLE_TEXTURE2D(_MipUpLowTex, sampler_MipUpLowTex, input.uv);
                    // bloomColor += mipColor * 1;
                // }

                // return half4(originalColor + bloomColor * _Intensity, 1.0);
                return half4( originalColor + mipColor* _Intensity/_MipCount, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Bloom blender"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragBrightness

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // sampler2D _MainTex;
            
            float _Threshold;
            float _Intensity;

            TEXTURE2D(_MainTex);

            SAMPLER(sampler_MainTex);


            half4 FragBrightness(Varyings input) : SV_Target
            {


                // _Threshold = 0.5f;
                // half3 color = tex2D(_MainTex, input.uv).rgb;
                float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);
                // half3 color = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_SourceTex, uv).xyz;
                half3 color = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, uv).xyz;


                // half brightness = dot(color.rgb, half3(0.2126, 0.7152, 0.0722));
                half brightness = max(color.r, max(color.g, color.b));
                // return saturate((brightness - _Threshold) / (1.0 - _Threshold));
                // _Threshold = 1-_Threshold;

                return float4(color * _Intensity,1);
            }
            ENDHLSL
        }

    }
}
