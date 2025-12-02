using UnityEngine;

public class SimpleDamageSpawner : MonoBehaviour
{
    public InsDamageController damageSystem;  // 拖拽你的InsDamageController到这里
    public uint damageValue = 123456;        // 默认伤害值

    public Color color;
    public int skipPlay = 60;
    private int count = 0;
    void Update()
    {
        if (count >= skipPlay)
        {
            count = 0;
            // 每帧在物体当前位置创建一个伤害点
            damageSystem.AddInstance(transform.position, damageValue,color);
            
        }
        count++;
    }
}