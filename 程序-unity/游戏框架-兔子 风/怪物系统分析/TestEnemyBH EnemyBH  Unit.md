让我分析一下 TestEnemyBH 的行为树逻辑和执行条件。

Search files...
让我分析一下 TestEnemyBH 继承了 EnemyBH 的行为树执行条件和活动机制：

### 1. 初始化和激活条件

1. **基础初始化**
```csharp
public override void OnInit() {
    base.OnInit();
    // 初始化行为树和状态机
    behaviorTree = GetComponent<BehaviorTree>();
    behaviorTree.SetVariableValue("unitStateController", unitStateController);
    behaviorTree.SetVariableValue("unit", this);
    behaviorTree.SetVariableValue("targetPos", Vector3.positiveInfinity);
    behaviorTree.StartWhenEnabled = true;
    behaviorTree.RestartWhenComplete = true;
}
```

2. **生成时激活**
```csharp
public override void OnSpawn() {
    if (dataId < 1) dataId = objId;
    // 根据类型设置优化标志
    if (ConfigManager.Instance.cfgUnit[dataId].type == 2) {
        isIgnoreOptimize = true;
    }
    base.OnSpawn();
    InitializeEnemyProperty(dataId);
}
```

### 2. 行为树执行条件

1. **距离检测条件 BattleManager中调用**
```csharp
public override void DistanceSetActive(bool isOn) {
    base.DistanceSetActive(isOn);
    isInVisible = isOn;
    if (isIgnoreOptimize) return;
    behaviorTree.enabled = isOn;  // 根据距离启用/禁用行为树
    if(!isOn) EventManager.Instance.Dispatch(EventId.OnEnemyBattleOut, (Unit)this);
}
```

2. **战斗范围条件**
- 需要在战斗范围内才会执行行为树
- 通过 `BattleManager.Instance.battleEnemyList` 管理战斗中的敌人

3. **生命状态条件**
```csharp
protected override void OnHit(int instanceId, int damage, int toughDmg, int distance) {
    // 生命值检测
    if (newCurHp <= 0) {
        ResetCurCut();
        targetPropertyComp.SetStaticValue(EnumProperty.CurHp.GetHashCode(), 0);
        OnDie();
        return;
    }
}
```

### 3. 活动触发条件

1. **索敌条件**
```csharp
// 在战斗范围内寻找目标
if(Mathf.Abs(ownerXZPos.x-targetXZPos.x)<= BattleRange &&
   Mathf.Abs(ownerXZPos.z-targetXZPos.z)<= BattleRange &&
   !target.IsDie && target.isActiveAndEnabled)
{
    trackTarget.Value = target;
    sharedUnit.Value.unitTargets = target;
    return TaskStatus.Success;
}
```

2. **攻击条件**
```csharp
// 在攻击范围内才会执行攻击行为
return (distanceX <= CastRangeX+targetHitboxRange &&
        distanceZ <= CastRangeZ+targetHitboxRange &&
        distanceX >= CastRangeX_Min &&
        distanceZ >= CastRangeZ_Min)
    ? TaskStatus.Success
    : TaskStatus.Failure;
```

3. **阶段转换条件**
```csharp
// 血量触发阶段转换
if (unit.GetCurHpPercent() < nextPhaseLimit) {
    EventManager.Instance.Dispatch(EventId.OnStrongEnemyIn);
    return TaskStatus.Success;
}
```

### 4. TestEnemyBH 会在以下条件下执行活动：

1. **基本条件**
- 已经完成初始化
- 处于激活状态 (OnSpawn 后且未被回收)
- 生命值大于 0
- 行为树组件已启用

2. **距离条件**
- 在玩家的可视范围内 (DistanceSetActive 为 true)
- 在战斗范围内 (在 BattleManager.battleEnemyList 中)

3. **状态条件**
- 不在受击状态
- 不在死亡状态
- 不在特殊动画状态

4. **目标条件**
- 有有效的攻击目标
- 目标在攻击范围内
- 目标未死亡且处于激活状态

5. **特殊条件**
- 韧性值影响行为选择
- 当前阶段的血量条件
- 是否处于虚弱状态

### 5. 活动终止条件

1. **强制终止**
- 生命值降至 0
- 被回收 (OnRecycle)
- 超出战斗范围
- 目标丢失

2. **状态终止**
- 进入受击状态
- 进入死亡状态
- 进入特殊动画状态

3. **系统终止**
- 行为树被禁用
- 游戏暂停
- 对象被销毁

这个系统通过行为树、状态机和事件系统的配合，实现了一个复杂的 AI 行为控制系统。敌人的活动受到多个层面的条件控制，确保了 AI 行为的合理性和游戏性。
