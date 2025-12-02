using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BrightnessFlareFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        public Texture2D flareTexture;
        [Range(0f, 3f)] public float brightnessThreshold = 1.5f;
        [Range(1, 100)] public int downSample = 2;
        public Color flareColor = new Color(1, 0.8f, 0.6f, 1);
        public Vector2 flareSize = new Vector2(0.05f, 0.05f);
         public int maxFlares = 256;
        [Range(0.5f, 3f)] public float intensityScale = 1.2f;
        
        public ComputeShader _analysisCS;
    }

    public Settings settings = new Settings();
    private BrightnessFlarePass _pass;
    private ComputeBuffer _flareBuffer;
    private ComputeBuffer _countBuffer;

    public override void Create()
    {
        _pass = new BrightnessFlarePass(settings.renderPassEvent,settings._analysisCS);
        InitializeBuffers();
    }

    private void InitializeBuffers()
    {
        ReleaseBuffers();
        
        // 每个光晕存储: positionX, positionY, intensity
        _flareBuffer = new ComputeBuffer(settings.maxFlares, sizeof(float) * 3, ComputeBufferType.Append);
        _countBuffer = new ComputeBuffer(1, sizeof(int), ComputeBufferType.IndirectArguments);
    }

    private void ReleaseBuffers()
    {
        _flareBuffer?.Release();
        _flareBuffer = null;
        
        _countBuffer?.Release();
        _countBuffer = null;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!settings.flareTexture)
        {
            Debug.LogWarning("Flare texture not assigned");
            return;
        }

        _pass.Setup(
            renderer.cameraColorTarget,
            settings.flareTexture,
            _flareBuffer,
            _countBuffer,
            settings.brightnessThreshold,
            settings.downSample,
            settings.flareColor,
            settings.flareSize,
            settings.intensityScale
        );
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        ReleaseBuffers();
    }
}

// 在类顶部定义静态的Shader属性ID
public static class ShaderIDs
{
    public static readonly int FlareTex = Shader.PropertyToID("_FlareTex");
    public static readonly int FlareColor = Shader.PropertyToID("_FlareColor");
    public static readonly int FlareSize = Shader.PropertyToID("_FlareSize");
    public static readonly int IntensityScale = Shader.PropertyToID("_IntensityScale");
    public static readonly int FlareBuffer = Shader.PropertyToID("_FlareBuffer");
}

public class BrightnessFlarePass : ScriptableRenderPass
{
    private Material _analysisMaterial;
    private Material _flareMaterial;
    private RenderTargetIdentifier _cameraColorTarget;
    private Texture2D _flareTexture;
    private ComputeBuffer _flareBuffer;
    private ComputeBuffer _countBuffer;
    private float _brightnessThreshold;
    private int _downSample;
    private Color _flareColor;
    private Vector2 _flareSize;
    private float _intensityScale;
    private int _downSampledRT;

    private ComputeShader _analysisCS;
    

    public BrightnessFlarePass(RenderPassEvent evt , ComputeShader analysisCS)
    {
        renderPassEvent = evt;
        profilingSampler = new ProfilingSampler("BrightnessFlare");
        
        // 创建材质
        _analysisMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/FlareDraw"));
        
        _flareMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/LX_Post_Effects/BrightnessFlares"));
        
        _downSampledRT = Shader.PropertyToID("_DownSampledRT");


        _analysisCS = analysisCS;
    }

    public void Setup(
        RenderTargetIdentifier cameraColorTarget,
        Texture2D flareTexture,
        ComputeBuffer flareBuffer,
        ComputeBuffer countBuffer,
        float brightnessThreshold,
        int downSample,
        Color flareColor,
        Vector2 flareSize,
        float intensityScale)
    {
        _cameraColorTarget = cameraColorTarget;
        _flareTexture = flareTexture;
        _flareBuffer = flareBuffer;
        _countBuffer = countBuffer;
        _brightnessThreshold = brightnessThreshold;
        _downSample = Mathf.Max(1, downSample);
        _flareColor = flareColor;
        _flareSize = flareSize;
        _intensityScale = intensityScale;
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        // 配置降采样RT描述符
        var desc = cameraTextureDescriptor;
        desc.width /= _downSample;
        desc.height /= _downSample;
        desc.depthBufferBits = 0;
        desc.msaaSamples = 1;
        
        cmd.GetTemporaryRT(_downSampledRT, desc, FilterMode.Bilinear);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if ( _flareMaterial == null || _flareTexture == null)
            return;

        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, profilingSampler))
        {
            // 1. 重置计数器
            _flareBuffer.SetCounterValue(0);
            
            // 2. 降采样屏幕
            cmd.Blit(_cameraColorTarget, _downSampledRT);
            
            // 3. 执行亮度分析 (Compute Shader)
            ComputeShader analysisCS = _analysisCS;
            if (analysisCS != null)
            {
                
                float[] zeros = new float[_flareBuffer.count * 3]; // 假设是 float3 缓冲区
                _flareBuffer.SetData(zeros);
                int kernel = analysisCS.FindKernel("BrightnessAnalysis");
                
                // 设置参数
                cmd.SetComputeTextureParam(analysisCS, kernel, "_MainTex", _downSampledRT);
                cmd.SetComputeFloatParam(analysisCS, "_BrightnessThreshold", _brightnessThreshold);
                cmd.SetComputeBufferParam(analysisCS, kernel, "_FlareBuffer", _flareBuffer);
                
                // 传递纹理尺寸
                Vector2 textureSize = new Vector2(
                    renderingData.cameraData.cameraTargetDescriptor.width / _downSample,
                    renderingData.cameraData.cameraTargetDescriptor.height / _downSample
                );
                cmd.SetComputeVectorParam(analysisCS, "_TextureSize", textureSize);
                
                // 调度计算
                int threadGroupsX = Mathf.CeilToInt(textureSize.x / 8f);
                int threadGroupsY = Mathf.CeilToInt(textureSize.y / 8f);
                // int threadGroupsX = Mathf.CeilToInt(textureSize.x );
                // int threadGroupsY = Mathf.CeilToInt(textureSize.y );
                cmd.DispatchCompute(analysisCS, kernel, threadGroupsX, threadGroupsY, 1);
                float3[] flareData = new float3[_flareBuffer.count];
                _flareBuffer.GetData(flareData);

            }
            else
            {
                Debug.LogError("BrightnessAnalysis compute shader not found");
            }
            
            
            
            // 修改后的参数设置代码
            // 4. 设置光晕绘制参数
            cmd.SetGlobalTexture(ShaderIDs.FlareTex, _flareTexture);
            cmd.SetGlobalColor(ShaderIDs.FlareColor, _flareColor);
            cmd.SetGlobalVector(ShaderIDs.FlareSize, _flareSize);
            cmd.SetGlobalFloat(ShaderIDs.IntensityScale, _intensityScale);
            // cmd.SetRenderTarget(_cameraColorTarget);
            
            // 启用过程化绘制模式
            _flareMaterial.EnableKeyword("_USE_DRAW_PROCEDURAL");
            _flareMaterial.SetTexture("_FlareTex",_flareTexture);

            // 5. 获取实际光晕数量并绘制
            if (_flareBuffer != null && _countBuffer != null)
            {
                // 复制计数器到_countBuffer
                cmd.CopyCounterValue(_flareBuffer, _countBuffer, 0);
                
                // 设置缓冲区
                cmd.SetGlobalBuffer(ShaderIDs.FlareBuffer, _flareBuffer);
                cmd.SetRenderTarget(_downSampledRT);
                
                ref var cameraData = ref renderingData.cameraData;
                var colorLoadAction = cameraData.isDefaultViewport ? RenderBufferLoadAction.DontCare : RenderBufferLoadAction.Load;
                cmd.SetRenderTarget(new RenderTargetIdentifier(_cameraColorTarget, 0, CubemapFace.Unknown, -1),
                    colorLoadAction, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.DontCare);

                
                // 实例化绘制光晕 (每个光晕是一个四边形)
                cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _flareMaterial,
                    0,
                    MeshTopology.Quads,
                    _flareBuffer.count*4,          // 每个实例4个顶点
                    _flareBuffer.count, // 最大实例数
                    null        // 属性块
                );
                // ref var cameraData = ref renderingData.cameraData;
                // var colorLoadAction = cameraData.isDefaultViewport ? RenderBufferLoadAction.DontCare : RenderBufferLoadAction.Load;
                // cmd.SetRenderTarget(new RenderTargetIdentifier(_cameraColorTarget, 0, CubemapFace.Unknown, -1),
                //     colorLoadAction, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.DontCare);
                // cmd.DrawProcedural(Matrix4x4.identity, _flareMaterial, 0, MeshTopology.Quads, 20, 5, null); //mippap
                // material.SetPass(0);
                Graphics.DrawProceduralNow(MeshTopology.Points, _flareBuffer.count);
            }
        }
        
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        cmd.ReleaseTemporaryRT(_downSampledRT);
    }
}
