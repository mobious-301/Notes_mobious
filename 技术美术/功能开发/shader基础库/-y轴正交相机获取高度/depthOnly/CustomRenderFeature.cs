using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public Material blitMaterial = null;
        public RenderTexture renderTexture = null;
    }

    public Settings settings = new Settings();
    private CustomPass blitPass;

    public override void Create()
    {
        blitPass = new CustomPass(name, settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.blitMaterial == null)
        {
            Debug.LogWarningFormat("Missing blit material");
            return;
        }
        blitPass.renderPassEvent = settings.renderPassEvent;
        blitPass.Setup(renderer.cameraDepthTarget);
        renderer.EnqueuePass(blitPass);
    }
}

public class CustomPass : ScriptableRenderPass
{
    private CustomRenderFeature.Settings settings;
    string m_ProfilerTag;
    RenderTargetIdentifier source;

    public CustomPass(string tag, CustomRenderFeature.Settings settings)
    {
        m_ProfilerTag = tag;
        this.settings = settings;
    }

    public void Setup(RenderTargetIdentifier src)
    {
        source = src;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
        cmd.Blit(source, settings.renderTexture, settings.blitMaterial);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    // public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    // {
    //     throw new System.NotImplementedException();
    // }
}
