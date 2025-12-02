# AISpawn 对象生成系统分析

## 1. 核心组件结构

### AISpawn 类
- 继承自 MonoBehaviour
- 主要负责敌人单位的生成和管理
- 位置：`BattleLogic/Unit/MixSpawn/AISpawn.cs`

## 2. 关键属性配置

```csharp
[Header("根信息")]
public int objID;              // 对象ID
public int dataID;             // 属性ID(已弃用)
public int GroupId;            // 组号
public Vector3[] destinationArray;  // 目的地数组

[Header("出生特点")]
public bool StartSpawn;        // 是否开场生成
public int dir;               // 出生朝向(3西4东)
public string SpawnType;      // 出生播片系列
public string SpawnCutscene;  // 出生播片
public EnumEffect SpawnEffect; // 出生特效
```

## 3. 生成流程

### 3.1 触发方式
1. **自动触发**：
   - 当 `StartSpawn = true` 时，在 OnEnable 时自动生成
   - 通过事件系统 `EventId.OnAISpawn` 触发

2. **手动触发**：
   - 通过调用 `SpawnEnemyByOutside()` 方法

### 3.2 生成过程

1. **预处理**：
```csharp
if (groupId != GroupId) return;
_cts?.Cancel();  // 取消之前的生成操作
_cts = new CancellationTokenSource();
```

2. **资源加载**：
```csharp
var spawnEnemy = await AssetManager.Instance.InstantiateAsyncEx<TestEnemyBH>(
    $"Assets/AddressableAssets/Mix/Character/Enemy/Enemy{objID}.prefab");
```

3. **位置和朝向设置**：
```csharp
transform1.position = destinationArray[0];
spawnEnemy.dir = dir;
var newAngle = dir == DirectionDef.East ? _rightDirEuler : _leftDirEuler;
```

4. **战斗管理**：
```csharp
if (isSummonList) {
    BattleManager.Instance.summonList.Add(spawnEnemy);
    HpHudController.Instance.BindTeammate(spawnEnemy);
} else {
    BattleManager.Instance.enemyList.Add(spawnEnemy);
}
```

5. **血条系统**：
```csharp
switch (ConfigManager.Instance.cfgUnit[objID].type) {
    case 1: HpHudController.Instance.BindElite(spawnEnemy);
    case 2: HpHudController.Instance.BindBoss(spawnEnemy);
    default: HpHudController.Instance.Bind(spawnEnemy);
}
```

6. **生成后处理**：
- 触发生成事件通知
- 执行特殊演出
- 应用生成特效
- 控制相关对象的激活状态

## 4. 特殊功能

### 4.1 对象控制
```csharp
[Header("生成完成后开关对象")]
public List<GameObject> actObjs;    // 需要激活的对象
public List<GameObject> deActObjs;  // 需要关闭的对象
```

### 4.2 生成特效系统
- 支持自定义出生播片动画
- 支持特效系统集成
- 支持朝向控制

## 5. 继承体系

```
MonoBehaviour
    └── AISpawn
        └── 生成的敌人单位
            ├── BaseEnemy
            ├── TestEnemyBH
            └── TitanEnemy (特殊Boss类型)
```

## 6. 事件系统集成

主要事件：
- `EventId.OnAISpawn`: 触发生成
- `EventId.OnAISpawnStageListen`: 生成后的舞台监听
- `EventId.OnUnitDie`: 单位死亡事件

## 7. 安全机制

1. **异步加载保护**：
   - 使用 CancellationTokenSource 管理异步操作
   - 防止重复生成和资源泄露

2. **错误处理**：
   - 完整的 try-catch 异常处理
   - 生成失败日志记录

这个生成系统，包含了单位生成的完整生命周期管理，性能优化和异常处理。支持不同类型的单位生成和自定义配置。
