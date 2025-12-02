Shader "Custom/c"
{
    Properties
    {[HDR]_Color ("Color", Color) = (1, 1, 1, 1)


        _MainTex ("Texture", 2D) = "white" {}
        _MainTexArray ("Texture Array", 2DArray) = "" {} // 声明2D纹理数组
        _TextureIndex ("Texture Index", Float) = 0 // 用于选择纹理
        _NoiseTex ("Noise", 2D) = "black" {}

        _RainHeight ("Rain Height", Float) = 30
        _RainPosOffset("_RainPosOffset", Vector) = (0, 0, 0, 0)
        _RainSpeed ("Rain Speed", Float) = 1
        _RainScale ("Rain Scale", Float) = 1
        _RainSize ("_RainSize", Vector) = (0, 0, 0)
        // _RainArea ("_RainArea", Vector) = (1, 1, 1, 1)
        _WindDirection("_WindDirection", Vector) = (0, 0, 0)
        _WindStrength("_WindStrength", Float) = 0
        _WindSpeed("_WindSpeed", Float) = 0

        _StopHeight("_StopHeight",Float) = 0

        [Toggle]_billY("广告板y轴效果", Float) = 0

        [Toggle]_stretchY("y轴 速度 拉伸", Float) = 0

        // color = lerp(originalColor, effectColor, _billY);


    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }

        ZWrite Off
        Cull Off
        Blend SrcAlpha One


        Pass
        {
            Name "RainPass"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            // 添加必要的include文件
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            struct RainPoint
            {
                float3 position;
                float height;
                float random;
                float3 wind;
            };


            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;

                float4 color : COLOR;
                float3 positionWS : TEXCOORD1;
                float random : TEXCOORD2;
            };

            // 缓冲区定义
            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _MainTex_ST;
            float _RainHeight;
            float _RainSpeed;
            float _RainScale;
            float3 _RainMin;
            float3 _RainMax;
            float _RainTime;
            float3 _WindDirection;
            float _WindStrength;
            float _WindSpeed;

            float4 _RainSize;

            float _billY;
            float4 _RainPosOffset;
            float4 _RainArea;

            float4 _RainGridSize;

            float4 _RainSpacing;


            float _TextureIndex; // 纹理索引

            float _StopHeight;

            float _stretchY;


            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            // 在HLSL代码中
            TEXTURE2D_ARRAY(_MainTexArray); // 声明纹理数组变量
            SAMPLER(sampler_MainTexArray); // 声明采样器

            

            float3 GetWorldPos(uint instanceID)
            {
                float2 gridSize = _RainGridSize.xy;
                float x = floor(instanceID / gridSize.x);
                float z = (instanceID - x * gridSize.x) * _RainSpacing.y;

                return float3((x - gridSize.y / 2) * _RainSpacing.x + _RainSpacing.z, 0, z + _RainSpacing.w);
            }

            // float3 GetWorldPos(uint instanceID)
            // {
                // float2 size = _RainGridSize.xy;
                // float x = floor(instanceID / size.x);
                // float z = instanceID - x * size.x;
                // return float3(z, 0, x);
            // }




            float3 SampleNoise(float2 uv)
            {
                return SAMPLE_TEXTURE2D_LOD(_NoiseTex, sampler_NoiseTex, uv, 0).xyz * 2 - 1;
            }

            // float GetRainHeight(float3 pos, float3 noise)
            // {
                // float time = _Time.x * _RainSpeed;
                // // return 1.0 - frac(time + noise.y +
                // // sin(pos.x * noise.z) +
                // // cos(pos.z * noise.x));

                // return 1.0 - (time + noise) % 1;
            // }
            // 柏林噪声基础函数
            float2 GetRandom(float2 p)
            {
                float2 r = p;
                r = frac(r * float2(443.8975, 397.2973));
                r += dot(r.xy, r.yx + 19.19);
                return frac(float2(r.x * r.y, r.x + r.y));
            }

            float GetRainHeight(float3 pos, float3 noise)
            {
                float time = _Time.y * _RainSpeed*GetRandom(pos.xz).x; // 使用_Time.y替代_Time.x以获得更平滑的动画
                return 1.0 - frac(time + noise.y); // 简化高度计算，减少位置依赖
            }

            // // 方法1：基于instanceID的确定性随机
            // float GetRandomInt(uint instanceID, int maxValue)
            // {
                // // 使用黄金比例和大质数
                // float random = frac(sin(instanceID * 12.9898 + 78.233) * 43758.5453);
                // return floor(random * maxValue);
            // }
            // 方法2：基于位置和时间的随机
            float GetRandomInt(float3 position, int maxValue)
            {
                position.y = 0;
                float random = frac(sin(dot(abs(position.xyz), float3(12.9898, 78.233, 45.5432))) * 43758.5453);
                return floor(random * maxValue);
            }
            // 获取 - 1到1之间的随机值
            // float GetRandom(float2 seed)
            // {
                // return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453) * 2.0 - 1.0;
            // }
            
            float2 getBetOffset(float2 posxz)
            {
                float2 randomOffset = GetRandom(posxz);
                return randomOffset;
            }

            float3 windOS(float3 worldPos, float random){

                float3 windDir = normalize(_WindDirection);
                float windStrength = _WindStrength * (1 + sin(_Time.y * _WindSpeed));
                float3 wind = windDir * windStrength * (_RainHeight+_RainPosOffset - worldPos.y * worldPos.y * 0.2) * random; //worldPos


                return worldPos + wind;
            }



            RainPoint ProcessRainPoint(uint instanceID)
            {
                RainPoint result;
                result.position = float3(0, 0, 0);
                result.height = 0;
                result.random = 0;
                result.wind = float3(0, 0, 0);

                // 1. 计算基础位置
                float3 pos = GetWorldPos(instanceID);
                pos.xz += _RainMin.xz;

                //间距 随机偏移

                float2 betOffset = getBetOffset(pos.xz);
                pos.xz += betOffset;

                // 2. 计算随机值
                // result.random = sin(pos.x * 95.4643 + pos.z) * 0.45 + 0.2;
                result.random = GetRandom(pos.xz).x;
                // result.random = 1;

                // 3. 计算噪声和高度
                float3 noise = SampleNoise(pos.xz * 0.01);
                result.height = GetRainHeight(pos, noise) ;

                //0 1高度 取最后一段减速
                

                // float tempHeight =  saturate (result.height / _StopHeight);
                // float tempHeight =  clamp (result.height , _StopHeight,1);

                if(_stretchY)
                {
                    float3 worldPos = windOS(float3(
                        pos.x,
                        result.height * _RainHeight,
                        pos.z
                        ), result.random); //风对 粒子 模型y轴影响
    
    
                    // 4. 设置世界空间位置
                    result.position = worldPos;
                }
                else
                {
                    result.position = float3(
                        pos.x,
                        result.height * _RainHeight,
                        pos.z
                    );
                }
                

                // 5. 计算风力影响
                // float3 windDir = normalize(_WindDirection);
                // float windStrength = _WindStrength * (1 + sin(_Time.y * _WindSpeed));
                // result.wind = windDir * windStrength * (1 - result.height * result.height) * result.random;
                return result;
            }



            // 应用Billboard效果
            float3 ApplyBillboard(float4 positionOS, RainPoint result)
            {
                // 1. 计算从物体到相机的方向向量
                float3 toCamera = normalize(_WorldSpaceCameraPos - result.position);

                // 2. 计算物体朝向（只在XZ平面上旋转）
                float3 forward = normalize(float3(toCamera.x, 0, toCamera.z));
                float3 right = cross(float3(0, 1, 0), forward);

                // 3. 构建Billboard位置
                float3 billboardPos;
                if(_billY < 0.5)
                {
                    // XZ平面Billboard
                    billboardPos = positionOS.x * right * _RainSize.x * result.random * _RainScale;
                    billboardPos += float3(0, positionOS.y * _RainSize.y * result.random * _RainScale, 0);
                }
                else
                {
                    // 完整Billboard
                    float3 cameraRight = UNITY_MATRIX_V[0].xyz;
                    float3 cameraUp = UNITY_MATRIX_V[1].xyz;
                    billboardPos = positionOS.x * cameraRight * _RainSize.x * result.random * _RainScale;
                    billboardPos += (positionOS.y * cameraUp * _RainSize.y * result.random) * _RainScale;
                }

                return billboardPos + result.position;
            }

            

            // 顶点着色器
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                // 1. 处理雨点数据
                RainPoint result = ProcessRainPoint(input.instanceID);

                // 2. 应用Billboard和最终位置计算
                float3 worldPos = ApplyBillboard(input.positionOS, result);

                // 捞底
                

                if(!_stretchY)
                {
                    // float tempHeight =  clamp (worldPos.y, _StopHeight,999999); //本地空间 底部限制                    
                    // worldPos.y = tempHeight;
                    worldPos = windOS(worldPos, result.random); //风对 粒子 模型y轴影响
                }
                worldPos+= _RainPosOffset.xzy;

                worldPos.y =  clamp (worldPos.y, _StopHeight,999999); //本地空间 底部限制           

                // 3. 设置输出数据
                output.positionCS = TransformWorldToHClip(worldPos);
                output.positionWS = worldPos;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                // 4. 设置颜色和透明度
                output.color = input.color;
                output.color.a *= pow(result.height, 0.25);

                // output.random = GetRandomInt(result.position, _TextureIndex);
                output.random = result.random*16;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

                half4 color = SAMPLE_TEXTURE2D_ARRAY(_MainTexArray, sampler_MainTexArray, input.uv, input.random);
                color *= _Color;

                // 可选：添加光照
                Light mainLight = GetMainLight();
                float3 lightColor = mainLight.color * mainLight.distanceAttenuation;
                // color.rgb *= lightColor;

                return color;
            }
            ENDHLSL
        }


    }
}