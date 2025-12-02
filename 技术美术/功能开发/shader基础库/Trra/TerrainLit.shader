Shader "Custom/Terrain/TrraLit"
{
    Properties
    {
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0

        //        _BlendOffset("BlendOffset",Range(0,0.5)) = 0.25
        //        _BlendExponent ("Blend Exponent", Range(1, 8)) = 2

        //Plus
        _DiffuseRemapScale0("Diffuse Remap Scale 0", color) = (1, 1, 1, 1)
        _DiffuseRemapScale1("Diffuse Remap Scale 1", color) = (1, 1, 1, 1)
        _DiffuseRemapScale2("Diffuse Remap Scale 2", color) = (1, 1, 1, 1)
        _DiffuseRemapScale3("Diffuse Remap Scale 3", color) = (1, 1, 1, 1)

        // _NormalScale0
        _NormalScale0 ("_NormalScale0",Range(-1,10)) = 0
        _NormalScale1 ("_NormalScale1",Range(-1,1)) = 0
        _NormalScale2 ("_NormalScale2",Range(-1,1)) = 0
        _NormalScale3 ("_NormalScale3",Range(-1,1)) = 0




        [ToggleUI] _EnableHeightBlend("EnableHeightBlend", Float) = 0.0
        _HeightTransition("Height Transition", Range(0, 1.0)) = 0.0
        // Layer count is passed down to guide height-blend enable/disable, due
        // to the fact that heigh-based blend will be broken with multipass.
        [PerRendererData] _NumLayersCount ("Total Layer Count", Float) = 1.0

        // set by terrain engine
        //  _Control("Control (RGBA)", 2D) = "red" {}
        //  _Splat3("Layer 3 (A)", 2D) = "grey" {}
        //  _Splat2("Layer 2 (B)", 2D) = "grey" {}
        //  _Splat1("Layer 1 (G)", 2D) = "grey" {}
        //  _Splat0("Layer 0 (R)", 2D) = "grey" {}
        _Control("Control (RGBA)", 2D) = "red" {}
        //改


        _Splat0("Layer 0 (R)", 2D) = "white" {}
        _Splat1("Layer 1 (G)", 2D) = "white" {}
        _Splat2("Layer 2 (B)", 2D) = "white" {}
        _Splat3("Layer 3 (A)", 2D) = "white" {}


        [NoScaleOffset]_Normal0("Normal 0 (R)", 2D) = "bump" {}
        [NoScaleOffset]_Normal1("Normal 1 (G)", 2D) = "bump" {}
        [NoScaleOffset]_Normal2("Normal 2 (B)", 2D) = "bump" {}
        [NoScaleOffset]_Normal3("Normal 3 (A)", 2D) = "bump" {}




        _Mask0("Mask 0 (R)", 2D) = "grey" {}
        _Mask1("Mask 1 (G)", 2D) = "grey" {}
        _Mask2("Mask 2 (B)", 2D) = "grey" {}
        _Mask3("Mask 3 (A)", 2D) = "grey" {}

        [Gamma] _Metallic0("Metallic 0", Range(0.0, 1.0)) = 0.0
        [Gamma] _Metallic1("Metallic 1", Range(0.0, 1.0)) = 0.0
        [Gamma] _Metallic2("Metallic 2", Range(0.0, 1.0)) = 0.0
        [Gamma] _Metallic3("Metallic 3", Range(0.0, 1.0)) = 0.0
        _Smoothness0("Smoothness 0", Range(0.0, 1.0)) = 0.5
        _Smoothness1("Smoothness 1", Range(0.0, 1.0)) = 0.5
        _Smoothness2("Smoothness 2", Range(0.0, 1.0)) = 0.5
        _Smoothness3("Smoothness 3", Range(0.0, 1.0)) = 0.5

        // used in fallback on old cards & base map
        _MainTex("BaseMap (RGB)", 2D) = "grey" {}
        _BaseColor("Main Color", Color) = (1,1,1,1)

        _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}

        [ToggleUI] _EnableInstancedPerPixelNormal("Enable Instanced per-pixel normal", Float) = 1.0
    }

    HLSLINCLUDE
    #pragma multi_compile_fragment __ _ALPHATEST_ON
    ENDHLSL

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry-100" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "False" "TerrainCompatible" = "True"
        }

        Pass
        {
            //Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING


            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma multi_compile_instancing
            #pragma instancing_options norenderinglayer assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local_fragment _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL
            #define _NORMALMAP 
            #define _MASKMAP


            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"

            float _BlendOffset;
            half _BlendExponent;

            float3 GetTriWeights(float3 normal)
            {
                float3 weights = abs(normal);
                weights = saturate(weights - _BlendOffset);
                weights = pow(weights, _BlendExponent);
                weights = weights / (weights.x + weights.y + weights.z);
                return weights.yxz;
            }

            #include "../4Textures.hlsl"
            #include "./TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            // Name "GBuffer"
            Tags
            {
                "LightMode" = "UniversalGBuffer"
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles
            #pragma target 3.0
            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            //#pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options norenderinglayer assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL
            #define TERRAIN_GBUFFER 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }

            ZWrite On

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthNormalOnlyVertex
            #pragma fragment DepthNormalOnlyFragment

            #pragma shader_feature_local _NORMALMAP
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitDepthNormalsPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "SceneSelectionPass"
            Tags
            {
                "LightMode" = "SceneSelectionPass"
            }

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #define SCENESELECTIONPASS
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags
            {
                "LightMode" = "Meta"
            }

            Cull Off

            HLSLPROGRAM
            #pragma vertex TerrainVertexMeta
            #pragma fragment TerrainFragmentMeta

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap
            #pragma shader_feature EDITOR_VISUALIZATION
            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitMetaPass.hlsl"
            ENDHLSL
        }

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
    }
    Dependency "AddPassShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Add Pass)"
    Dependency "BaseMapShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Base Pass)"
    Dependency "BaseMapGenShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Basemap Gen)"

    //CustomEditor "UnityEditor.Rendering.Universal.TerrainLitShaderGUI"

    Fallback "Hidden/Universal Render Pipeline/FallbackError"
}