// InstanceData.cs
using UnityEngine;
// InstancedMeshModel.cs
using System;
using UnityEngine;
public struct InstanceData
{
    public Vector3 position;
    public Quaternion rotation;
    public Vector3 scale;
    public float spawnTime;
    public bool isActive;
    
    public Matrix4x4 GetMatrix() => Matrix4x4.TRS(position, rotation, scale);
}



public class InstancedMeshModel
{
    // 配置参数
    public int MaxInstanceCount { get; private set; }
    public float DefaultLifetime { get; set; } = 10f;
    
    // 环形缓冲区
    private InstanceData[] instances;
    private int[] instanceRing; // 环形索引数组
    private int head = 0;       // 当前写入位置
    private int tail = 0;       // 最早的活动实例位置
    private int activeCount = 0;
    private bool isFull = false;
    
    // 事件系统
    public event Action<int> OnInstanceActivated;
    public event Action<int> OnInstanceDeactivated;
    public event Action OnAllInstancesExpired;
    
    public int ActiveInstanceCount => activeCount;
    public int AvailableSlots => isFull ? 0 : MaxInstanceCount - activeCount;

    public InstancedMeshModel(int maxInstanceCount)
    {
        MaxInstanceCount = maxInstanceCount;
        instances = new InstanceData[maxInstanceCount];
        instanceRing = new int[maxInstanceCount];
    }

    // 添加新实例（时钟指针前进）
    public int AddInstance(Vector3 position, Quaternion rotation, Vector3 scale)
    {
        if (isFull)
        {
            // 缓冲区已满，覆盖最早的实例
            int recycledIndex = instanceRing[tail];
            ref var recycled = ref instances[recycledIndex];
            
            // 触发回收事件
            OnInstanceDeactivated?.Invoke(recycledIndex);
            
            // 重用实例
            recycled.position = position;
            recycled.rotation = rotation;
            recycled.scale = scale;
            recycled.spawnTime = Time.time;
            recycled.isActive = true;
            
            // 移动尾指针
            tail = (tail + 1) % MaxInstanceCount;
            
            // 更新环形缓冲区
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
            
            // 初始化数据
            newInstance.position = position;
            newInstance.rotation = rotation;
            newInstance.scale = scale;
            newInstance.spawnTime = Time.time;
            newInstance.isActive = true;
            
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

    // 移除过期实例（时钟指针前进）
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
                // 回收实例
                instance.isActive = false;
                OnInstanceDeactivated?.Invoke(index);
                
                // 移动尾指针
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
                break; // 遇到未过期实例停止检查
            }
        }
    }

    // 获取所有活动实例（按时间顺序从新到旧）
    public void GetAllActiveInstances(InstanceData[] outputArray)
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

    // 清空所有实例
    public void ClearAllInstances()
    {
        while (activeCount > 0)
        {
            int index = instanceRing[tail];
            instances[index].isActive = false;
            OnInstanceDeactivated?.Invoke(index);
            
            tail = (tail + 1) % MaxInstanceCount;
            activeCount--;
        }
        
        isFull = false;
        head = tail = 0;
        OnAllInstancesExpired?.Invoke();
    }

    // 获取实例引用
    public ref InstanceData GetInstance(int index) => ref instances[index];
}