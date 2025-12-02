using System;
using UnityEngine;
using UnityEngine;

public struct InsDamageData
{
    public Vector3 position;
    public float spawnTime;
    public uint damage;
    public Vector3 Color;
}
public class InsDamageModel
{
    public int MaxInstanceCount { get; private set; }
    public float DefaultLifetime { get; set; } = 10f;
    
    private InsDamageData[] instances;
    private int[] instanceRing;
    private int head = 0;
    private int tail = 0;
    private int activeCount = 0;
    private bool isFull = false;
    
    public event Action<int> OnInstanceActivated;
    public event Action<int> OnInstanceDeactivated;
    public event Action OnAllInstancesExpired;
    
    public int ActiveInstanceCount => activeCount;
    public int AvailableSlots => isFull ? 0 : MaxInstanceCount - activeCount;

    public InsDamageModel(int maxInstanceCount)
    {
        MaxInstanceCount = maxInstanceCount;
        instances = new InsDamageData[maxInstanceCount];
        instanceRing = new int[maxInstanceCount];
    }

    public int AddInstance(Vector3 position, uint damage,Vector3 Color)
    {
        if (isFull)
        {
            // 获取要被回收的实例索引
            int recycledIndex = instanceRing[tail];
            ref var recycled = ref instances[recycledIndex];
        
            // 触发回收事件
            OnInstanceDeactivated?.Invoke(recycledIndex);
        
            // 仅更新必要字段，保留其他字段不变
            recycled.position = position;       // 更新位置
            recycled.spawnTime = Time.time;    // 重置生成时间
            recycled.damage = damage;          // 更新伤害值
            recycled.Color = Color;
        
            // 移动指针
            tail = (tail + 1) % MaxInstanceCount;
            instanceRing[head] = recycledIndex;
            head = (head + 1) % MaxInstanceCount;
        
            OnInstanceActivated?.Invoke(recycledIndex);
            return recycledIndex;
        }
        else
        {
            // 获取新索引
            int newIndex = head;
            ref var newInstance = ref instances[newIndex];
        
            // 初始化新实例
            newInstance.position = position;
            newInstance.spawnTime = Time.time;
            newInstance.damage = damage;
            newInstance.Color = Color;
        
            // 更新环形缓冲区
            instanceRing[head] = newIndex;
            head = (head + 1) % MaxInstanceCount;
            activeCount++;
        
            // 检查是否填满
            if (head == tail) isFull = true;
        
            OnInstanceActivated?.Invoke(newIndex);
            return newIndex;
        }
    }

    public void RemoveExpiredInstances()
    {
        if (DefaultLifetime <= 0 || activeCount == 0) return;
        
        float currentTime = Time.time;
        int checkedCount = 0;
        
        while (checkedCount < activeCount)
        {
            int index = instanceRing[tail];
            ref var instance = ref instances[index];
            
            if (currentTime - instance.spawnTime > DefaultLifetime)
            {
                instance.damage = 0;
                OnInstanceDeactivated?.Invoke(index);
                
                tail = (tail + 1) % MaxInstanceCount;
                activeCount--;
                checkedCount++;
                isFull = false;
                
                if (activeCount == 0)
                {
                    OnAllInstancesExpired?.Invoke();
                    break;
                }
            }
            else
            {
                break;
            }
        }
    }

    public void GetAllActiveInstances(InsDamageData[] outputArray)
    {
        if (activeCount == 0) return;
        
        int writeIndex = 0;
        int readPos = (head - 1 + MaxInstanceCount) % MaxInstanceCount;
        
        for (int i = 0; i < activeCount; i++)
        {
            int ringIndex = instanceRing[readPos];
            outputArray[writeIndex++] = instances[ringIndex];
            readPos = (readPos - 1 + MaxInstanceCount) % MaxInstanceCount;
        }
    }

    public void ClearAllInstances()
    {
        while (activeCount > 0)
        {
            int index = instanceRing[tail];
            instances[index].damage = 0;
            OnInstanceDeactivated?.Invoke(index);
            
            tail = (tail + 1) % MaxInstanceCount;
            activeCount--;
        }
        
        isFull = false;
        head = tail = 0;
        OnAllInstancesExpired?.Invoke();
    }

    public ref InsDamageData GetInstance(int index) => ref instances[index];
}