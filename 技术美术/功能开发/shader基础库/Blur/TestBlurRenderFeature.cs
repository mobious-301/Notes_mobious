using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;
using UnityEngine.Experimental.Rendering;
using System;

namespace LXPE
{
    public class TestBlurRenderFeature : ScriptableRendererFeature
    {
        TestBlurPass testBlurPass;

        public override void Create()
        {
            testBlurPass = new TestBlurPass(RenderPassEvent.BeforeRenderingPostProcessing);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            testBlurPass.Setup(renderer.cameraColorTarget);
            renderer.EnqueuePass(testBlurPass);
        }
    }

    public class TestBlurPass : ScriptableRenderPass
    {
        static readonly string k_RenderTag = "Render TestBlur Effects";
        static readonly int MainTexId = Shader.PropertyToID("_MainTex");
        static readonly int TempTargetId = Shader.PropertyToID("_TempTargetTestBlur");
        static readonly int FocusPowerId = Shader.PropertyToID("_FocusPower");
        static readonly int FocusDetailId = Shader.PropertyToID("_FocusDetail");
        static readonly int FocusScreenPositionId = Shader.PropertyToID("_FocusScreenPosition");
        static readonly int ReferenceResolutionXId = Shader.PropertyToID("_ReferenceResolutionX");
        TestBlur testBlur;
        Material testBlurMaterial;
        RenderTargetIdentifier currentTarget;

        GraphicsFormat m_DefaultHDRFormat;

        const int k_MaxPyramidSize = 16;    

        public TestBlurPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
            // var shader = Shader.Find("PostEffect/TestBlur");
            var shader = Shader.Find("Hidden/URP_Bloom");
            
            if (shader == null)
            {
                Debug.LogError("Shader not found.");
                return;
            }
            testBlurMaterial = CoreUtils.CreateEngineMaterial(shader);


            ShaderConstants._BloomMipUp = new int[k_MaxPyramidSize];
            ShaderConstants._BloomMipDown = new int[k_MaxPyramidSize];

            for (int i = 0; i < k_MaxPyramidSize; i++)
            {
                ShaderConstants._BloomMipUp[i] = Shader.PropertyToID("_BloomMipUp" + i);
                ShaderConstants._BloomMipDown[i] = Shader.PropertyToID("_BloomMipDown" + i);
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (testBlurMaterial == null)
            {
                Debug.LogError("Material not created.");
                return;
            }

            if (!renderingData.cameraData.postProcessEnabled) return;

            var stack = VolumeManager.instance.stack;
            testBlur = stack.GetComponent<TestBlur>();
            if (testBlur == null) { return; }
            if (!testBlur.IsActive()) { return; }

            var cmd = CommandBufferPool.Get(k_RenderTag);
            Render(cmd, ref renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public void Setup(in RenderTargetIdentifier currentTarget)
        {
            this.currentTarget = currentTarget;
        }

        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ref var cameraData = ref renderingData.cameraData;
            var source = currentTarget;
            int destination = TempTargetId;



            // var desc1 = GetStereoCompatibleDescriptor(tw, th, m_DefaultHDRFormat);
            // if (SystemInfo.IsFormatSupported(GraphicsFormat.B10G11R11_UFloatPack32, FormatUsage.Linear | FormatUsage.Render))
            // {
            //     m_DefaultHDRFormat = GraphicsFormat.B10G11R11_UFloatPack32;
            //     m_UseRGBM = false;
            // }
            // else
            // {
            m_DefaultHDRFormat = GraphicsFormat.R8G8B8A8_SRGB;

            int mipCount=6;
            // m_UseRGBM = true;
            // }

            var tw = (int)(cameraData.camera.scaledPixelWidth / testBlur.downSample.value);
            var th = (int)(cameraData.camera.scaledPixelHeight / testBlur.downSample.value);

            var desc1 = GetCompatibleDescriptor(tw, th, m_DefaultHDRFormat);
            cmd.GetTemporaryRT(ShaderConstants._BloomMipUp[0], desc1, FilterMode.Bilinear);

            
            var desc2 = desc1;

            

            desc2.useMipMap = true;
            desc2.autoGenerateMips = true;
            cmd.GetTemporaryRT(ShaderConstants._BloomOptMipDown, desc2, FilterMode.Bilinear);



            
            for (int i = 1; i < mipCount; i++)
            {
                tw = (int)Mathf.Max(1, tw);
                th = (int)Mathf.Max(1, th );
                desc1.width = tw;
                desc1.height = th;
                cmd.GetTemporaryRT(ShaderConstants._BloomMipUp[i], desc1, FilterMode.Bilinear);
            }

            var desc3 = desc1;

            desc3.width = cameraData.camera.scaledPixelWidth;
            desc3.height = cameraData.camera.scaledPixelHeight;

            // cmd.GetTemporaryRT(ShaderConstants._SourceTemp, desc3, FilterMode.Bilinear);
            // cmd.Blit(source, ShaderConstants._SourceTemp);

            cmd.SetGlobalTexture("_SourceTex", source);
            // cmd.SetGlobalTexture("_MainTex", source);

            // 设置渲染目标为 destinationTexture
            // cmd.SetRenderTarget(source);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, testBlurMaterial);


            // cmd.SetGlobalTexture("_BlitTex", source);
            // cmd.Blit(source, ShaderConstants._BloomOptMipDown, testBlurMaterial, 0);

            // cmd.SetGlobalInt(ShaderConstants._MipLevel, mipCount - 1);
            // cmd.Blit(ShaderConstants._BloomOptMipDown, ShaderConstants._BloomMipUp[mipCount - 1], testBlurMaterial, 1);

            // // threshold: 亮度阈值,用于决定哪些区域应该参与 Bloom 效果。
            // // intensity: Bloom 效果的强度。
            // // downsampling: 降采样的级数,决定了 Bloom 效果的质量和性能。
            // // sigma: 高斯模糊的标准差,决定了 Bloom 效果的模糊程度。


            // cmd.SetGlobalInt(ShaderConstants._MipCount, mipCount);
            // cmd.SetGlobalFloat(ShaderConstants._MipSigma, 3.0f);

            // // cmd.SetGlobalFloat(ShaderConstants._Intensity, 3.0f);

            // testBlurMaterial.SetFloat("_MipSigma", testBlur.MipSigma.value);
            // testBlurMaterial.SetFloat("_Intensity", testBlur.Intensity.value);
            // testBlurMaterial.SetFloat("_Threshold", testBlur.Threshold.value);

            

            // // int i = mipCount - 2;
            // mipCount=3;
            // for (int i = mipCount - 2; i >= 0; i--)
            // {
            //     cmd.SetGlobalInt(ShaderConstants._MipLevel, i);
            //     int low = ShaderConstants._BloomMipUp[i + 1];
            //     int high = ShaderConstants._BloomMipUp[i];
            //     cmd.SetGlobalTexture(ShaderConstants._MipUpLowTex, low);
            //     cmd.Blit(ShaderConstants._BloomOptMipDown, high, testBlurMaterial, 1);
            // }

            // // cmd.SetGlobalInt(ShaderConstants._SourceTex, i);

            // cmd.SetGlobalTexture(ShaderPropertyId.sourceTex, source);


            // //  ShaderConstants._BloomMipUp[0]
            // cmd.Blit(ShaderConstants._SourceTemp , source, testBlurMaterial, 3);

        }

        RenderTextureDescriptor GetCompatibleDescriptor(int width, int height, GraphicsFormat format, int depthBufferBits = 0)
        {
            var desc = new RenderTextureDescriptor(width, height, RenderTextureFormat.DefaultHDR);
            desc.depthBufferBits = depthBufferBits;
            desc.msaaSamples = 1;
            desc.width = width;
            desc.height = height;
            desc.graphicsFormat = format;
            return desc;
        }
        
        static class ShaderPropertyId
        {
            public static readonly int sourceTex = Shader.PropertyToID("_SourceTex");
        }

        static class ShaderConstants
        {
            public static readonly int _TempTarget = Shader.PropertyToID("_TempTarget");
            public static readonly int _TempTarget2 = Shader.PropertyToID("_TempTarget2");

            public static readonly int _StencilRef = Shader.PropertyToID("_StencilRef");
            public static readonly int _StencilMask = Shader.PropertyToID("_StencilMask");

            public static readonly int _FullCoCTexture = Shader.PropertyToID("_FullCoCTexture");
            public static readonly int _HalfCoCTexture = Shader.PropertyToID("_HalfCoCTexture");
            public static readonly int _DofTexture = Shader.PropertyToID("_DofTexture");
            public static readonly int _CoCParams = Shader.PropertyToID("_CoCParams");
            public static readonly int _BokehKernel = Shader.PropertyToID("_BokehKernel");
            public static readonly int _BokehConstants = Shader.PropertyToID("_BokehConstants");
            public static readonly int _PongTexture = Shader.PropertyToID("_PongTexture");
            public static readonly int _PingTexture = Shader.PropertyToID("_PingTexture");

            public static readonly int _Metrics = Shader.PropertyToID("_Metrics");
            public static readonly int _AreaTexture = Shader.PropertyToID("_AreaTexture");
            public static readonly int _SearchTexture = Shader.PropertyToID("_SearchTexture");
            public static readonly int _EdgeTexture = Shader.PropertyToID("_EdgeTexture");
            public static readonly int _BlendTexture = Shader.PropertyToID("_BlendTexture");

            public static readonly int _ColorTexture = Shader.PropertyToID("_ColorTexture");
            public static readonly int _Params = Shader.PropertyToID("_Params");
            public static readonly int _SourceTexLowMip = Shader.PropertyToID("_SourceTexLowMip");
            public static readonly int _Bloom_Params = Shader.PropertyToID("_Bloom_Params");
            public static readonly int _Bloom_RGBM = Shader.PropertyToID("_Bloom_RGBM");
            public static readonly int _Bloom_Texture = Shader.PropertyToID("_Bloom_Texture");
            public static readonly int _LensDirt_Texture = Shader.PropertyToID("_LensDirt_Texture");
            public static readonly int _LensDirt_Params = Shader.PropertyToID("_LensDirt_Params");
            public static readonly int _LensDirt_Intensity = Shader.PropertyToID("_LensDirt_Intensity");
            public static readonly int _Distortion_Params1 = Shader.PropertyToID("_Distortion_Params1");
            public static readonly int _Distortion_Params2 = Shader.PropertyToID("_Distortion_Params2");
            public static readonly int _Chroma_Params = Shader.PropertyToID("_Chroma_Params");
            public static readonly int _Vignette_Params1 = Shader.PropertyToID("_Vignette_Params1");
            public static readonly int _Vignette_Params2 = Shader.PropertyToID("_Vignette_Params2");
            public static readonly int _Lut_Params = Shader.PropertyToID("_Lut_Params");
            public static readonly int _UserLut_Params = Shader.PropertyToID("_UserLut_Params");
            public static readonly int _InternalLut = Shader.PropertyToID("_InternalLut");
            public static readonly int _UserLut = Shader.PropertyToID("_UserLut");
            public static readonly int _DownSampleScaleFactor = Shader.PropertyToID("_DownSampleScaleFactor");

            public static readonly int _FlareOcclusionTex = Shader.PropertyToID("_FlareOcclusionTex");
            public static readonly int _FlareOcclusionIndex = Shader.PropertyToID("_FlareOcclusionIndex");
            public static readonly int _FlareTex = Shader.PropertyToID("_FlareTex");
            public static readonly int _FlareColorValue = Shader.PropertyToID("_FlareColorValue");
            public static readonly int _FlareData0 = Shader.PropertyToID("_FlareData0");
            public static readonly int _FlareData1 = Shader.PropertyToID("_FlareData1");
            public static readonly int _FlareData2 = Shader.PropertyToID("_FlareData2");
            public static readonly int _FlareData3 = Shader.PropertyToID("_FlareData3");
            public static readonly int _FlareData4 = Shader.PropertyToID("_FlareData4");
            public static readonly int _FlareData5 = Shader.PropertyToID("_FlareData5");

            public static readonly int _FullscreenProjMat = Shader.PropertyToID("_FullscreenProjMat");

            public static readonly int _ScalingSetupTexture = Shader.PropertyToID("_ScalingSetupTexture");
            public static readonly int _UpscaledTexture = Shader.PropertyToID("_UpscaledTexture");

            public static int[] _BloomMipUp;
            public static int[] _BloomMipDown;
            // public static int _BloomOptMipDown;
            public static readonly int _BloomOptMipDown = Shader.PropertyToID("_BloomOptMipDown");
            public static readonly int _MipLevel = Shader.PropertyToID("_MipLevel");
            public static readonly int _MipCount = Shader.PropertyToID("_MipCount");
            public static readonly int _MipSigma = Shader.PropertyToID("_MipSigma");
            public static readonly int _MipUpLowTex = Shader.PropertyToID("_MipUpLowTex");

            public static readonly int _SourceTemp = Shader.PropertyToID("_SourceTemp");

            


            

            

            

            

            public static int _BloomMipmap;
            public static int _BloomMipmapA;

            public static int _BloomMipSimplify;
            public static int _BloomMipSimplify1;
        }

    }
}