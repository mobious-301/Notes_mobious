using UnityEngine;
using UnityEngine.InputSystem;
using Slate;
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

[CustomPropertyDrawer(typeof(ReadOnlyFieldAttribute))]
public class ReadOnlyFieldDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        GUI.enabled = false;
        EditorGUI.PropertyField(position, property, label);
        GUI.enabled = true;
    }
}
#endif
// 自定义Attribute用于标记只读字段
public class ReadOnlyFieldAttribute : PropertyAttribute
{
}

public class DynamicTimeCutsceneController : MonoBehaviour
{
    [Header("昼夜循环配置")] public float dayDurationInMinutes = 24f; // 一天的总时长（分钟）
    public float currentHour; // 当前游戏时间（0-24小时）

    [Header("时间倍率设置")] public float baseTimeMultiplier = 1.0f;
    public float acceleratedTimeMultiplier = 500.0f; // 加速倍率
    public InputActionReference timeAccelerateAction;
    [Tooltip("夜转日加速停止时间点")] public float nightToDayStopPoint = 6f;

    [Header("加速停止点配置")] [Tooltip("日转夜加速停止时间点")]
    public float dayToNightStopPoint = 18f;


    [Header("Cutscene 配置")] public Cutscene dayNightCutscene; // 关联的 Cutscene
    public float[] cutsceneKeyPoints = new float[] { 0f, 6f, 12f, 18f }; // Cutscene 对应的时间关键点

    [ReadOnlyField] public float targetAccelerationTime; // 目标加速时间点
    [ReadOnlyField] public bool isAccelerating = false;

    [ReadOnlyField] public float checkTime;

    void OnEnable()
    {
        timeAccelerateAction.action.Enable();
        ResetSystem();
    }

    void OnDisable()
    {
        timeAccelerateAction.action.Disable();
    }

    void ResetSystem()
    {
        currentHour = 0f; // 初始化时间为0点
        isAccelerating = false;
        SynchronizeCutsceneTime(); // 同步 Cutscene 时间
    }

    void Update()
    {
        HandleAccelerationInput();
        UpdateTime();
    }

    void HandleAccelerationInput()
    {
        if (timeAccelerateAction.action.WasPressedThisFrame())
        {
            StartAcceleration();
        }
    }

    void StartAcceleration()
    {
        // 计算目标加速时间点
        targetAccelerationTime = CalculateTargetTime();

        // 如果目标时间有效，则开始加速
        if (targetAccelerationTime != -1)
        {
            isAccelerating = true;
        }
    }

    float CalculateTargetTime()
    {
        // 判断当前是白天还是夜晚
        bool isDay = currentHour >= nightToDayStopPoint && currentHour < dayToNightStopPoint;

        // 如果是白天，则目标时间为日转夜停止点；如果是夜晚，则目标时间为夜转日停止点
        return isDay ? dayToNightStopPoint : nightToDayStopPoint;
    }

    void UpdateTime()
    {
        // 根据是否加速选择时间倍率
        float timeMultiplier = isAccelerating ? acceleratedTimeMultiplier : baseTimeMultiplier;

        // 更新当前时间
        currentHour += (Time.deltaTime / (dayDurationInMinutes * 60f)) * 24f * timeMultiplier;

        // 确保时间在0-24范围内循环
        if (currentHour >= dayDurationInMinutes) currentHour -= dayDurationInMinutes;

        // 同步 Cutscene 时间
        SynchronizeCutsceneTime();

        // 检查是否需要结束加速状态
        if (isAccelerating && HasReachedTargetTime())
        {
            EndAcceleration();
        }
    }

    bool HasReachedTargetTime()
    {
        checkTime = currentHour > dayToNightStopPoint && targetAccelerationTime == nightToDayStopPoint
            ? currentHour - dayDurationInMinutes
            : currentHour;
        // 检查当前时间是否已经到达或超过目标加速时间点
        return isAccelerating && checkTime >= targetAccelerationTime;
        return Mathf.Abs(currentHour - 24f) <= nightToDayStopPoint;
    }

    void EndAcceleration()
    {
        // 结束加速状态，恢复为正常时间倍率
        isAccelerating = false;
    }

    void SynchronizeCutsceneTime()
    {
        if (dayNightCutscene == null) return;

        // 根据当前游戏时间找到对应的 Cutscene 时间
        // float targetCutsceneTime = 0f;
        // for (int i = 0; i < cutsceneKeyPoints.Length; i++)
        // {
        //     if (currentHour >= cutsceneKeyPoints[i])
        //     {
        //         targetCutsceneTime = cutsceneKeyPoints[i];
        //     }
        //     else
        //     {
        //         break;
        //     }
        // }

        // 设置 Cutscene 的播放进度
        dayNightCutscene.Sample(currentHour);
    }

    void OnGUI()
    {
        string stopPointsInfo = $"停止点: 日转夜 {dayToNightStopPoint:00.00} | 夜转日 {nightToDayStopPoint:00.00}";

        GUI.Label(new Rect(10, 10, 600, 70),
            $"当前时间: {currentHour:00.00}:00 | " +
            $"速度: x{(isAccelerating ? acceleratedTimeMultiplier : baseTimeMultiplier):0.0} | " +
            $"{stopPointsInfo}\n" +
            $"操作: 点击{timeAccelerateAction.action.name}加速到下一个停止点");
    }
}