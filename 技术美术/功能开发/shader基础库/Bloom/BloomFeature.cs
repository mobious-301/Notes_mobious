using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering;

namespace LXPE
{
    public class BloomFeature : ScriptableRendererFeature
    {
        BloomPass BloomPass;

        public override void Create()
        {
            BloomPass = new BloomPass(RenderPassEvent.BeforeRenderingPostProcessing);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            BloomPass.Setup(renderer.cameraColorTarget);
            renderer.EnqueuePass(BloomPass);
        }
    }

    public class BloomPass : ScriptableRenderPass
    {
        static readonly string k_RenderTag = "Render Bloom Effects";
        static readonly int MainTexId = Shader.PropertyToID("_MainTex");
        static readonly int TempTargetId = Shader.PropertyToID("_TempTargetBloom");
        static readonly int FocusPowerId = Shader.PropertyToID("_FocusPower");
        static readonly int FocusDetailId = Shader.PropertyToID("_FocusDetail");
        static readonly int FocusScreenPositionId = Shader.PropertyToID("_FocusScreenPosition");
        static readonly int ReferenceResolutionXId = Shader.PropertyToID("_ReferenceResolutionX");


        static GraphicsFormat m_DefaultHDRFormat;
        Bloom bloom;
        Material BloomMaterial;
        RenderTargetIdentifier currentTarget;

        public BloomPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
            var shader = Shader.Find(ShaderNames.Bloom);
            if (shader == null)
            {
                Debug.LogError("Shader not found.");
                return;
            }
            BloomMaterial = CoreUtils.CreateEngineMaterial(shader);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (BloomMaterial == null)
            {
                Debug.LogError("Material not created.");
                return;
            }

            if (!renderingData.cameraData.postProcessEnabled) return;

            var stack = VolumeManager.instance.stack;
            bloom = stack.GetComponent<Bloom>();
            if (bloom == null) { return; }
            if (!bloom.IsActive()) { return; }

            var cmd = CommandBufferPool.Get(k_RenderTag);
            Render(cmd, ref renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public void Setup(in RenderTargetIdentifier currentTarget)
        {
            this.currentTarget = currentTarget;
        }

        public Vector4[] myArray = new Vector4[7]
        {
            new Vector4(0.66666666f,1,0.33333333f,0),
            new Vector4(0.33333333f,0.5f,0,0.5f),
            new Vector4(0.16666666f,0.25f,0,0.25f),
            new Vector4(0.08333333f,0.125f,0,0.125f),

            new Vector4(0.04166666f,0.0625f,0,0.0625f),
            new Vector4(0.02083333f,0.03125f,0,0.03125f),
            new Vector4(0.01041666f,0.015625f,0,0.015625f)
            //位置 就因该 计算后存在这

        };

        bool setPadding = false;
        RenderTextureDescriptor m_Descriptor;

        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ref var cameraData = ref renderingData.cameraData;
            var source = currentTarget;
            int destination = TempTargetId;

            // var w = (int)(cameraData.camera.scaledPixelWidth / bloom.downSample.value);
            // var h = (int)(cameraData.camera.scaledPixelHeight / bloom.downSample.value);
            // BloomMaterial.SetFloat(FocusPowerId, bloom.BiurRadius.value);

            // int shaderPass = 0;
            // cmd.SetGlobalTexture(MainTexId, source);
            // cmd.GetTemporaryRT(destination, w, h, 0, FilterMode.Point, RenderTextureFormat.Default);

            // cmd.Blit(source, destination);
            // for (int i = 0; i < bloom.Iteration.value; i++)
            // {
            //     cmd.GetTemporaryRT(destination, w / 2, h / 2, 0, FilterMode.Point, RenderTextureFormat.Default);
            //     cmd.Blit(destination, source, BloomMaterial, shaderPass);
            //     cmd.Blit(source, destination);
            //     cmd.Blit(destination, source, BloomMaterial, shaderPass + 1);
            //     cmd.Blit(source, destination);
            // }
            // for (int i = 0; i < bloom.Iteration.value; i++)
            // {
            //     cmd.GetTemporaryRT(destination, w * 2, h * 2, 0, FilterMode.Point, RenderTextureFormat.Default);
            //     cmd.Blit(destination, source, BloomMaterial, shaderPass);
            //     cmd.Blit(source, destination);
            //     cmd.Blit(destination, source, BloomMaterial, shaderPass + 1);
            //     cmd.Blit(source, destination);
            // }

            // cmd.Blit(destination, destination, BloomMaterial, 0);



            if (true)
            {
                

                m_Descriptor = cameraData.cameraTargetDescriptor;

                // m_DefaultHDRFormat = RenderTextureFormat.DefaultHDR;


                // 创建两个临时RT
                float BloomTempScale = 2f;

                // var sours = GetCompatibleDescriptor((int)(m_Descriptor.width / BloomTempScale), (int)(m_Descriptor.height / BloomTempScale), RenderTextureFormat.DefaultHDR);
                // cmd.GetTemporaryRT(ShaderConstants._BloomMipSimplify, sours, FilterMode.Bilinear);
                cmd.GetTemporaryRT(ShaderConstants._BloomMipSimplify, (int)(m_Descriptor.width / BloomTempScale), (int)(m_Descriptor.height / BloomTempScale), 0, FilterMode.Bilinear, RenderTextureFormat.Default);

                var sours1 = GetCompatibleDescriptor((int)(m_Descriptor.width / BloomTempScale / 2), (int)(m_Descriptor.height / BloomTempScale / 2), GraphicsFormat.R16G16B16A16_SFloat);
                cmd.GetTemporaryRT(ShaderConstants._BloomMipSimplify1, sours1, FilterMode.Bilinear);


                var desc1 = GetCompatibleDescriptor((int)(m_Descriptor.width / BloomTempScale * 3 / 2), (int)(m_Descriptor.height / BloomTempScale), GraphicsFormat.R16G16B16A16_SFloat);
                cmd.GetTemporaryRT(ShaderConstants._BloomMipmap, desc1, FilterMode.Bilinear);

                // var desc2 = GetCompatibleDescriptor((int)(m_Descriptor.width / BloomTempScale*3/2), (int)(m_Descriptor.height / BloomTempScale), m_DefaultHDRFormat);
                cmd.GetTemporaryRT(ShaderConstants._BloomMipmapA, desc1, FilterMode.Bilinear);






                // 代码实现 padding 和横向 拉伸
                if (!setPadding)
                {
                    for (int i = 0; i < myArray.Length; i++)
                    {
                        myArray[i].z += myArray[i].x * 0.1f;
                        myArray[i].w += myArray[i].y * 0.1f;

                        myArray[i].x *= 0.8f;
                        myArray[i].y *= 0.8f;
                    }

                    for (int i = 0; i < myArray.Length; i++)
                    {
                        // myArray[i].x *=  1+i*i/5;
                    }
                    setPadding = true;
                }


                BloomMaterial.SetVectorArray("_vertexPosSet", myArray);

                //控制开关  会以此方法中最后设置的为准 不能动态控制
                // Blit(cmd, source, ShaderConstants._BloomMipSimplify, BloomMaterial, 10);
                // Blit(cmd, ShaderConstants._BloomMipSimplify, ShaderConstants._BloomMipSimplify1, BloomMaterial, 10);

                Blit(cmd, source, ShaderConstants._BloomMipSimplify);
                Blit(cmd, ShaderConstants._BloomMipSimplify, ShaderConstants._BloomMipSimplify1);



                //设置输入输出 并用特殊pass 同时写入多个四边形
                cmd.SetGlobalTexture("_SourceTex", ShaderConstants._BloomMipSimplify1);
                cmd.SetRenderTarget(ShaderConstants._BloomMipmapA);
                cmd.ClearRenderTarget(true, true, Color.clear);
                cmd.DrawProcedural(Matrix4x4.identity, BloomMaterial, 4, MeshTopology.Quads, 20, 5, null); //mippap

                // Blit(cmd, ShaderConstants._BloomMipmapA, ShaderConstants._BloomMipmap, BloomMaterial, 7);  //横向像素外扩
                // Blit(cmd, ShaderConstants._BloomMipmap, ShaderConstants._BloomMipmapA, BloomMaterial, 8);


                Blit(cmd, ShaderConstants._BloomMipmapA, ShaderConstants._BloomMipmap, BloomMaterial, 1); //纵向高斯
                Blit(cmd, ShaderConstants._BloomMipmap, ShaderConstants._BloomMipmapA, BloomMaterial, 2);

                Blit(cmd, ShaderConstants._BloomMipmapA, ShaderConstants._BloomMipmap, BloomMaterial, 1); //纵向高斯
                Blit(cmd, ShaderConstants._BloomMipmap, ShaderConstants._BloomMipmapA, BloomMaterial, 2);

                Blit(cmd, ShaderConstants._BloomMipmapA, ShaderConstants._BloomMipSimplify, BloomMaterial, 5);//合并mapmap 升采样 

                // Blit(cmd, ShaderConstants._BloomMipSimplify, ShaderConstants._BloomMipSimplify1, BloomMaterial, 1); //纵向高斯
                // Blit(cmd, ShaderConstants._BloomMipSimplify1, ShaderConstants._BloomMipSimplify, BloomMaterial, 2);
                cmd.SetGlobalTexture(ShaderConstants._Bloom_Texture, ShaderConstants._BloomMipSimplify);

            }


            // cmd.ReleaseTemporaryRT(ShaderConstants._BloomMipDown[i]);
        }
        // RenderTextureDescriptor GetCompatibleDescriptor()
        //     => GetCompatibleDescriptor(m_Descriptor.width, m_Descriptor.height, m_Descriptor.graphicsFormat);

        RenderTextureDescriptor GetCompatibleDescriptor(int width, int height, GraphicsFormat format, int depthBufferBits = 0)
        {
            var desc = m_Descriptor;
            desc.depthBufferBits = depthBufferBits;
            desc.msaaSamples = 1;
            desc.width = width;
            desc.height = height;
            desc.graphicsFormat = format;
            return desc;
        }

        private new void Blit(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier destination, Material material, int passIndex = 0)
        {
            cmd.SetGlobalTexture(ShaderPropertyId.sourceTex, source);
            // if (m_UseDrawProcedural) //为了实现xr设计的
            // {
            //     Vector4 scaleBias = new Vector4(1, 1, 0, 0);
            //     cmd.SetGlobalVector(ShaderPropertyId.scaleBias, scaleBias);

            //     cmd.SetRenderTarget(new RenderTargetIdentifier(destination, 0, CubemapFace.Unknown, -1),
            //         RenderBufferLoadAction.Load, RenderBufferStoreAction.Store, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store);
            //     cmd.DrawProcedural(Matrix4x4.identity, material, passIndex, MeshTopology.Quads, 4, 1, null);
            // }
            // else
            // {
            cmd.Blit(source, destination, material, passIndex);
            // }
        }

        internal static class ShaderPropertyId
        {
            public static readonly int glossyEnvironmentColor = Shader.PropertyToID("_GlossyEnvironmentColor");
            public static readonly int sourceTex = Shader.PropertyToID("_SourceTex");
            public static readonly int scaleBias = Shader.PropertyToID("_ScaleBias");
        }

        static class ShaderConstants
        {
            public static readonly int _BloomMipSimplify = Shader.PropertyToID("_BloomMipSimplify");
            public static readonly int _BloomMipSimplify1 = Shader.PropertyToID("_BloomMipSimplify1");
            public static readonly int _BloomMipmap = Shader.PropertyToID("_BloomMipmap");
            public static readonly int _BloomMipmapA = Shader.PropertyToID("_BloomMipmapA");
            public static readonly int _Bloom_Texture = Shader.PropertyToID("_Bloom_Texture");
        }
    }
}