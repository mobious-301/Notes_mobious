Shader "Custom/InsDamageURP"
{
    Properties
    {
        _BaseMapArray("Base Texture Array", 2DArray) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _FadeDuration("Fade Duration", Float) = 2.0
        _InstanceSpacing("Instance Spacing", Float) = 1.0 // 控制组内实例间距
        _AnimationDuration("Animation Duration (Frames)", Int) = 60 // 总动画帧数
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"       // 改为 Transparent
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"           // 使用透明渲染队列（3000）
            "IgnoreProjector" = "True"        // 可选：避免受投影影响
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            // 关键：启用 Alpha 混合模式
            Blend SrcAlpha OneMinusSrcAlpha    // 标准透明混合
            ZWrite Off                        // 关闭深度写入（防止透明物体遮挡问题）
            Cull Off                          // 可选：双面渲染（适合透明物体）

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma require 2darray

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv         : TEXCOORD0;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float4 color     : COLOR;
                float textureIndex : TEXCOORD1;
                float visibility : TEXCOORD2; // 可见性mask
            };

            TEXTURE2D_ARRAY(_BaseMapArray);
            SAMPLER(sampler_BaseMapArray);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMapArray_ST;
                half4 _BaseColor;
                float _FadeDuration;
                float _InstanceSpacing;
                int _AnimationDuration;
            CBUFFER_END

            StructuredBuffer<float3> _Positions;    // 每组共享一个位置
            StructuredBuffer<float> _SpawnTimes;    // 每组共享一个生成时间
            StructuredBuffer<int> _Damages;         // 每组共享一个数字（每位0-9）
            StructuredBuffer<float3> _Colors;         // 每组共享一个数字（每位0-9）

            // 提取数字的第 n 位（0=个位，1=十位，...）
            int GetDigit(int number, int digitPos)
            {
                // 手动计算 10^n（避免浮点误差）
                int divisor = 1;
                [unroll]
                for (int i = 0; i < digitPos; i++) 
                {
                    divisor *= 10;
                }
                
                // 先除法后取模（关键步骤）
                return abs((number / divisor) % 10); // abs() 防止负数干扰
            }

            // 计算可见性mask（剔除前导0）
            float CalculateVisibility(int number, int digitPos)
            {
                // 从最高位开始检查
                for (int i = 9; i > digitPos; --i)
                {
                    if (GetDigit(number, i) != 0)
                        return 1.0; // 前面有非零数字，可见
                }
                // 检查当前位
                return GetDigit(number, digitPos) != 0 ? 1.0 : 0.0;
            }

            // 优化后的 ApplyAnimation（无分支）
            float ApplyAnimation(
                float currentFrame,
                int startFrame,
                int endFrame,
                float startValue,
                float endValue,
                int holdFrame = 0
            )
            {
                // 计算是否在动画区间内（0或1）
                float isActive = step(startFrame, currentFrame) * (1 - step(endFrame + holdFrame, currentFrame));
                
                // 计算动画进度（0~1）
                float progress = saturate((currentFrame - startFrame) / (endFrame - startFrame));
                
                // 插值结果
                float animValue = lerp(startValue, endValue, progress);
                
                // 如果在保持阶段，强制返回结束值
                float isHoldPhase = step(endFrame, currentFrame) * (1 - step(endFrame + holdFrame, currentFrame));
                return lerp(animValue, endValue, isHoldPhase) * isActive + startValue * (1 - isActive);
            }

            // 优化后的顶点动画（无分支）
            void ApplyVertexAnimation(
                float currentFrame,
                inout float3 positionOS,
                out float scale
            )
            {
                            // ===== 2. 缩放动画（保持不变） =====  修改了顺序
                float scalePhase1 = lerp(0.4, 1.0, saturate((currentFrame - 1) / (22 - 1)));
                float scalePhase2 = lerp(1.0, 0.0, saturate((currentFrame - 32) / (40 - 32)));
                
                scale = scalePhase1 * (1 - step(22, currentFrame)) + 
                        1.0 * step(22, currentFrame) * (1 - step(32, currentFrame)) + 
                        scalePhase2 * step(32, currentFrame);

                positionOS*= scale;
                // ===== 1. Y轴位移动画 =====
                // - 15帧前：Y=0
                // - 15-40帧：从0线性上升到50
                // - 40帧后：永久保持Y=50
                float yAnimStart = 15.0;
                float yAnimEnd = 40.0;
                
                // 计算动画进度（0-1），超过40帧后强制为1
                float yProgress = saturate((currentFrame - yAnimStart) / (yAnimEnd - yAnimStart));
                float yOffset = 5.0 * yProgress;
                
                positionOS.y += yOffset;
                
            }

            // 新增函数：计算每组中有效数字的数量
            int GetVisibleDigitCount(int number) {
                int count = 0;
                for (int i = 9; i >= 0; --i) {
                    if (GetDigit(number, i) != 0) {
                        count = i + 1; // 找到最高非零位后确定位数
                        break;
                    }
                }
                return count;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                uint instanceID = input.instanceID;

                // 分组逻辑（原有代码）
                uint groupID = instanceID / 10;
                uint positionInGroup = instanceID % 10;
                float3 groupCenterPos = _Positions[groupID];
                float groupSpawnTime = _SpawnTimes[groupID];
                int groupDamage = _Damages[groupID];
                float3 group_Color = _Colors[groupID];
                output.visibility = CalculateVisibility(groupDamage, positionInGroup);
                int textureIndex = GetDigit(groupDamage, positionInGroup);
                output.color = float4(group_Color, 1.0);

                // 计算生命周期（转换为帧数）
                float lifeTime = _Time.y - groupSpawnTime;
                float currentFrame = lifeTime *60; // 假设60FPS

                // 应用顶点动画
                float3 positionOS = input.positionOS.xyz;
                float scale;
                // 组内偏移 + 最终位置计算
                float3 localOffset = float3(positionInGroup * _InstanceSpacing, 0, 0);
                positionOS -= localOffset;

                // ===== 关键修改：动态计算有效数字的居中偏移 =====
                int visibleDigits = GetVisibleDigitCount(groupDamage);
                float totalWidth = (visibleDigits - 1) * _InstanceSpacing; // 有效数字总宽度
                float startOffset = -totalWidth * 0.5; // 起始偏移（居中）
                positionOS.x -= startOffset;
                
                ApplyVertexAnimation(currentFrame, positionOS, scale);

                // float3 worldPos = groupCenterPos - localOffset;
                positionOS = positionOS  + groupCenterPos; // 应用缩放

                output.positionCS = TransformObjectToHClip(positionOS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMapArray);
                output.textureIndex = textureIndex;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D_ARRAY(_BaseMapArray, sampler_BaseMapArray, input.uv, input.textureIndex);
                half4 color = float4(input.color.xyz * baseMap.rgb, 1.0)*input.visibility;
                // clip(baseMap.a*input.visibility-0.5);//高位0剔除
                clip(baseMap.a-0.5);
                return color;
            }
            ENDHLSL
        }
    }
}