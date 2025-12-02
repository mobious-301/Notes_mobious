using UnityEngine;
using UnityEngine.Rendering.Universal;

[CreateAssetMenu(menuName = "Rendering/Custom Renderer Data")]
public class CustomScriptableRendererData : ScriptableRendererData
{
    public LayerMask opaqueLayerMask = -1;

    protected override ScriptableRenderer Create()
    {
        return new CustomScriptableRenderer(this);
    }
}
