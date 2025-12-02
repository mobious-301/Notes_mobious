# Unity人形Boss行为树设计

下面是一个基于行为树(Behavior Tree)的人形Boss AI设计，使用Unity的Behavior Tree插件(如Behavior Designer)或自定义实现。

## 行为树结构概览

```
Root (Selector)
├─ 死亡检查 (Sequence)
│   ├─ 检查HP是否≤0
│   └─ 播放死亡动画/结束战斗
├─ 受击反应 (Sequence)
│   ├─ 检查是否被击中
│   └─ 播放受击动画/短暂僵直
├─ 特殊阶段转换 (Sequence)
│   ├─ 检查HP阈值(如30%)
│   └─ 进入狂暴状态/改变行为模式
├─ 技能攻击 (Selector)
│   ├─ 远程技能 (Sequence)
│   │   ├─ 检查冷却时间
│   │   ├─ 检查玩家距离
│   │   └─ 释放远程攻击
│   ├─ 范围AOE (Sequence)
│   │   ├─ 检查冷却时间
│   │   ├─ 检查范围内玩家数量
│   │   └─ 释放范围攻击
│   └─ 连招攻击 (Sequence)
│       ├─ 检查玩家距离
│       ├─ 选择连招模式
│       └─ 执行近战连招
├─ 追击玩家 (Sequence)
│   ├─ 检查玩家是否在视野内
│   ├─ 路径计算
│   └─ 移动向玩家
└─ 闲置行为 (Selector)
    ├─ 巡逻移动 (Sequence)
    │   ├─ 选择巡逻点
    │   └─ 移动向巡逻点
    └─ 闲置动画 (播放待机动画)
```

## 详细节点说明

### 1. 死亡检查
```csharp
public class CheckDeath : Conditional
{
    public Health health;
    
    public override bool Check()
    {
        return health.currentHP <= 0;
    }
}
```

### 2. 受击反应
```csharp
public class ReactToHit : Action
{
    public Animator animator;
    public float staggerDuration = 1f;
    
    public override TaskStatus OnUpdate()
    {
        animator.SetTrigger("Hit");
        return TaskStatus.Success;
    }
}
```

### 3. 阶段转换
```csharp
public class CheckPhaseTransition : Conditional
{
    public Health health;
    public float phaseThreshold = 0.3f; // 30% HP
    
    public override bool Check()
    {
        return health.currentHP <= health.maxHP * phaseThreshold;
    }
}
```

### 4. 技能攻击子系统

#### 远程技能检查
```csharp
public class CheckRangedAttackCondition : Conditional
{
    public float cooldown = 5f;
    public float minDistance = 8f;
    public float maxDistance = 15f;
    private float lastAttackTime;
    
    public override bool Check()
    {
        if (Time.time - lastAttackTime < cooldown) return false;
        
        float distance = Vector3.Distance(transform.position, player.position);
        return distance >= minDistance && distance <= maxDistance;
    }
}
```

#### 近战连招选择
```csharp
public class SelectComboPattern : Action
{
    public string[] comboPatterns;
    private int currentComboIndex;
    
    public override TaskStatus OnUpdate()
    {
        currentComboIndex = Random.Range(0, comboPatterns.Length);
        animator.SetInteger("ComboIndex", currentComboIndex);
        animator.SetTrigger("StartCombo");
        return TaskStatus.Success;
    }
}
```

### 5. 追击玩家
```csharp
public class ChasePlayer : Action
{
    public float moveSpeed = 3.5f;
    public float stoppingDistance = 2f;
    public NavMeshAgent agent;
    
    public override TaskStatus OnUpdate()
    {
        if (Vector3.Distance(transform.position, player.position) <= stoppingDistance)
        {
            agent.isStopped = true;
            return TaskStatus.Success;
        }
        
        agent.isStopped = false;
        agent.SetDestination(player.position);
        agent.speed = moveSpeed;
        return TaskStatus.Running;
    }
}
```

## 行为树参数配置

建议在Unity中配置以下参数：
- 攻击冷却时间
- 各技能触发距离
- 移动速度(普通/狂暴状态)
- HP阶段阈值
- 连招模式概率权重
- 视野范围/角度

## 进阶设计建议

1. **动态难度调整**：根据玩家表现动态调整Boss行为参数
2. **环境互动**：设计Boss利用战场环境的特殊行为
3. **弱点机制**：特定时段暴露弱点供玩家攻击
4. **阶段转换动画**：添加视觉效果增强阶段转换表现
5. **语音/音效**：不同行为配合相应的语音提示

## 实现注意事项

1. 使用Unity的Animator Controller管理动画状态
2. 考虑使用NavMesh进行可靠的路径查找
3. 为行为树添加调试可视化工具
4. 使用ScriptableObject存储Boss参数便于调整平衡性
5. 确保行为树能够被中断(如受击时取消当前行为)

这个设计可以根据具体游戏需求进行调整和扩展，比如添加更多技能类型或特殊行为模式。