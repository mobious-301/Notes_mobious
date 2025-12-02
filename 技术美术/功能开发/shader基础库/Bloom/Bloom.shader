// Shader "Hidden/LX Post Effects/Bloom"
// {
//     Properties
//     {
//         _MainTex ("Texture", 2D) = "white" { }
//     }

//     HLSLINCLUDE

//     sampler2D _MainTex;
//     float2 _FocusScreenPosition;
//     float _FocusPower;

//     // TEXTURE2D_X(_SourceTex);
//     float4 _SourceTex_TexelSize;

//     int _isvertexPos;
//     float4 _vertexPos[10];
//     float4 _vertexPosSet[10];

//     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

//     struct Attributes
//     {
//         uint vertexID : SV_VertexID;
//         #if _USE_DRAW_PROCEDURAL

//         #else
//         float4 positionOS : POSITION;
//         float2 uv : TEXCOORD0;
//         #endif
//         UNITY_VERTEX_INPUT_INSTANCE_ID
//     };

//     struct Varyings
//     {
//         float4 positionCS : SV_POSITION;
//         float2 uv : TEXCOORD0;

//         // float2 GroupId : TEXCOORD1;
//         UNITY_VERTEX_OUTPUT_STEREO
//     };


//     uint getIDgroup(uint id)
//     {
//         return id / 4;
//     }

//     Varyings Vert(Attributes input)
//     {
//         Varyings o;

//         UNITY_SETUP_INSTANCE_ID(input);
//         UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
//         // o.vertex = UnityObjectToClipPos(v.vertex);
//         o.positionCS = TransformObjectToHClip(input.positionOS.xyz);
//         o.uv = input.uv;
//         return o;
//     }


//     Varyings FullscreenVert(Attributes input)

//     {
//         Varyings output;
//         UNITY_SETUP_INSTANCE_ID(input);
//         UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//         // #if ! _isvertexPos




//         _ScaleBias = float4(1, 1, 0, 0);
//         // _ScaleBias.xy *= 2;
//         output.positionCS = GetQuadVertexPosition(input.vertexID);

//         // output.positionCS.xy = output.positionCS.xy * float2(2.0f, 2.0f) + float2(- 1.0f, - 1.0f);
//         output.uv = (GetQuadTexCoord(input.vertexID) * _ScaleBias.xy + _ScaleBias.zw) % 2;


//         _vertexPos[0] = float4(0, 0, 0, 0);
//         _vertexPos[1] = float4(1, 1, 1, 1);
//         _vertexPos[2] = float4(2, 2, 2, 2);
//         _vertexPos[3] = float4(3, 3, 3, 3);
//         _vertexPos[4] = float4(4, 4, 4, 4);
//         _vertexPos[5] = float4(5, 5, 5, 5);
//         _vertexPos[6] = float4(6, 6, 6, 6);
//         _vertexPos[7] = float4(7, 7, 7, 7);
//         _vertexPos[8] = float4(8, 8, 8, 8);
//         _vertexPos[9] = float4(9, 9, 9, 9);

//         // _vertexPosSet[0] = float4(0.66666666, 1, 0.33333333, 0);
//         // _vertexPosSet[1] = float4(0.33333333, 0.5, 0, 0.5);
//         // _vertexPosSet[2] = float4(0.16666666, 0.25, 0, 0.25);
//         // _vertexPosSet[2] = float4(0.08333333, 0.125, 0, 0.125);

//         output.positionCS.x -= 2 * _vertexPos[getIDgroup(input.vertexID)];
//         // output.positionCS.xy = output.positionCS.xy * 0.8 + 0.1; ///
//         output.positionCS.xy = output.positionCS.xy * _vertexPosSet[getIDgroup(input.vertexID)].xy + _vertexPosSet[getIDgroup(input.vertexID)].zw;

//         // output.positionCS.x *= 1 + _vertexPos[getIDgroup(input.vertexID)] * _vertexPos[getIDgroup(input.vertexID)] / 5; //横向拉伸


//         output.positionCS.xy = output.positionCS.xy * float2(2.0f, - 2.0f) + float2(- 1.0f, 1.0f); //convert to - 1..1


//         // #else
//         // output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
//         // output.uv = input.uv;
//         // #endif

//         // output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
//         // output.positionCS.xy *= 0.1; //原始坐标
//         // output.uv = GetFullScreenTriangleTexCoord(input.vertexID);

//         // positionCS 是屏幕中心空间坐标 01 坐标 * 2 - 1 得此坐标
//         // output.uv *= 0.001;
//         return output;
//     }

//     half4 FragPrefilter(Varyings input) : SV_Target
//     {
//         UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
//         float2 uv = UnityStereoTransformScreenSpaceTex(input.uv);

//     // #if _BLOOM_HQ
//     //     float texelSize = _SourceTex_TexelSize.x;
//     //     half4 A = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(-1.0, -1.0));
//     //     half4 B = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(0.0, -1.0));
//     //     half4 C = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(1.0, -1.0));
//     //     half4 D = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(-0.5, -0.5));
//     //     half4 E = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(0.5, -0.5));
//     //     half4 F = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(-1.0, 0.0));
//     //     half4 G = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv);
//     //     half4 H = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(1.0, 0.0));
//     //     half4 I = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(-0.5, 0.5));
//     //     half4 J = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(0.5, 0.5));
//     //     half4 K = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(-1.0, 1.0));
//     //     half4 L = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(0.0, 1.0));
//     //     half4 M = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv + texelSize * float2(1.0, 1.0));

//     //     half2 div = (1.0 / 4.0) * half2(0.5, 0.125);

//     //     half4 o = (D + E + I + J) * div.x;
//     //     o += (A + B + G + F) * div.y;
//     //     o += (B + C + H + G) * div.y;
//     //     o += (F + G + L + K) * div.y;
//     //     o += (G + H + M + L) * div.y;

//     //     half3 color = o.xyz;
//     // #else
//         half3 color = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_LinearClamp, uv).xyz;
//     // #endif

//         // User controlled clamp to limit crazy high broken spec
//         color = min(ClampMax, color);

//         // Thresholding
//         half brightness = Max3(color.r, color.g, color.b);
//         half softness = clamp(brightness - Threshold + ThresholdKnee, 0.0, 2.0 * ThresholdKnee);
//         softness = (softness * softness) / (4.0 * ThresholdKnee + 1e-4);
//         half multiplier = max(brightness - Threshold, softness) / max(brightness, 1e-4);
//         color *= multiplier;

//         // Clamp colors to positive once in prefilter. Encode can have a sqrt, and sqrt(-x) == NaN. Up/Downsample passes would then spread the NaN.
//         color = max(color, 0);
//         return EncodeHDR(color);
//     }

//     float4 FragBlurH(Varyings i) : SV_Target
//     {

//         UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
//         float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
//         // float2 uv = i.uv;

//         half2 uv1 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(1, 0) * - 2.0;
//         half2 uv2 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(1, 0) * - 1.0;
//         half2 uv3 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(1, 0) * 0.0;
//         half2 uv4 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(1, 0) * 1.0;
//         half2 uv5 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(1, 0) * 2.0;
//         half4 s = 0;

//         s += tex2D(_MainTex, uv1) * 0.0545;
//         s += tex2D(_MainTex, uv2) * 0.2442;
//         s += tex2D(_MainTex, uv3) * 0.4026;
//         s += tex2D(_MainTex, uv4) * 0.2442;
//         s += tex2D(_MainTex, uv5) * 0.0545;

//         return s;
//     }

//     float4 FragBlurV(Varyings i) : SV_Target
//     {
//         // float2 uv = i.uv;
//         UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
//         float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);

//         half2 uv1 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(0, 1) * - 2.0;
//         half2 uv2 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(0, 1) * - 1.0;
//         half2 uv3 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(0, 1) * 0.0;
//         half2 uv4 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(0, 1) * 1.0;
//         half2 uv5 = uv + half2(_FocusPower / _ScreenParams.x, _FocusPower / _ScreenParams.y) * half2(0, 1) * 2.0;
//         half4 s = 0;

//         s += tex2D(_MainTex, uv1) * 0.0545;
//         s += tex2D(_MainTex, uv2) * 0.2442;
//         s += tex2D(_MainTex, uv3) * 0.4026;
//         s += tex2D(_MainTex, uv4) * 0.2442;
//         s += tex2D(_MainTex, uv5) * 0.0545;

//         return s;
//     }


//     ENDHLSL

//     SubShader
//     {
//         Cull Off ZWrite Off ZTest Always
//         Tags { "RenderPipeline" = "UniversalPipeline" }
//         Pass
//         {
//             Name "Bloom Prefilter"

//             HLSLPROGRAM
//                 #pragma vertex FullscreenVert
//                 #pragma fragment FragPrefilter
//                 #pragma multi_compile_local _ _BLOOM_HQ
//             ENDHLSL
//         }

//         Pass
//         {
//             // CGPROGRAM
//             Name "FragBlurH"
//             HLSLPROGRAM
//             // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
//             // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

//             #pragma vertex Vert
//             #pragma fragment FragBlurH


//             // ENDCG
//             ENDHLSL

//         }

//         Pass
//         {
//             // CGPROGRAM
//             HLSLPROGRAM
//             #pragma vertex Vert
//             #pragma fragment FragBlurV
//             // ENDCG
//             ENDHLSL

//         }
//     }
// }