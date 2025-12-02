using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ParticleSystemExample : MonoBehaviour
{
    public InstancedMeshController meshController;
    [Tooltip("每秒产生的粒子数量（支持小数）")]
    public float particlesPerSecond = 10f;
    public float particleSpeed = 5f;
    
    private float _particleAccumulator = 0f; // 累积未生成的粒子数
    
    private void Update()
    {
        // 计算这一帧应该生成多少粒子（考虑帧率和小数）
        float desiredParticles = particlesPerSecond * Time.deltaTime;
        _particleAccumulator += desiredParticles;
        
        // 只有当累积量 >= 1 时才生成粒子
        int particlesToCreate = Mathf.FloorToInt(_particleAccumulator);
        if (particlesToCreate > 0)
        {
            _particleAccumulator -= particlesToCreate; // 减去已生成的部分
            
            // 限制实际生成数量不超过最大实例数
            particlesToCreate = Mathf.Min(particlesToCreate, meshController.maxInstances);
            
            for (int i = 0; i < particlesToCreate; i++)
            {
                int index = meshController.AddInstance(
                    transform.position,
                    Random.rotation,
                    Vector3.one * Random.Range(0.2f, 0.5f)
                );
                
                if (index == -1) break;
            }
        }
        
        // 更新现有粒子（示例代码）
        // UpdateParticles();
    }
    
    // private void UpdateParticles()
    // {
    //     for (int i = 0; i < meshController.ActiveInstanceCount; i++)
    //     {
    //         var pos = meshController.GetPosition(i) + Vector3.up * particleSpeed * Time.deltaTime;
    //         meshController.UpdateInstance(i, pos, Quaternion.identity, Vector3.one);
    //     }
    // }
}