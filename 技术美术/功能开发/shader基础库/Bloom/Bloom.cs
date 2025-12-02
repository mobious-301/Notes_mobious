using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// using UnityEngine.Rendering.Universal;
using System;
// using UnityEngine;
// using UnityEngine.Rendering;
// namespace UnityEditor.Rendering
// {
namespace LXPE
{

    // [Serializable, VolumeComponentMenu("LX Post Effects/Screen/Tube Distortion")]
    [Serializable, VolumeComponentMenu("lx Post Effects/Bloom")]
    // [SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
    public class Bloom : VolumeComponent, IPostProcessComponent
    {
        [Range(0f, 100f), Tooltip("模糊强度")]
        public FloatParameter BiurRadius = new FloatParameter(0f);

        [Range(0, 10), Tooltip("模糊质量")]
        public IntParameter Iteration = new IntParameter(5);

        [Range(1, 10), Tooltip("模糊深度")]
        public FloatParameter downSample = new FloatParameter(0f);
        // public ClampedFloatParameter downSample = new ClampedFloatParameter(1f, -10f, 10f);

        public bool IsActive() => downSample.value > 0f;

        public bool IsTileCompatible() => false;
    }
}