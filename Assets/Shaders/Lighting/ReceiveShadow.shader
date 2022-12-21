Shader "ShaderLearning/URP/Lighting/ReceiveShadow"
{
    Properties
    {
        _ShadowColor("ShadowColor", Color) = (0, 0, 0, 1)
        _ShadowSoftSize("ShadowSoftSize",Range(0.001,0.3)) = 0.05
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM

            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #define SHADOW_NICE_QUALITY
            #define USE_PCF_SHADOW

            #pragma vertex vert
            #pragma fragment frag
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            half3 _ShadowColor;
            half _ShadowSoftSize;
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionWS = positionWS;
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                return OUT;
            }
            
            /*
            real CustomSampleShadowmapFiltered(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float4 shadowCoord, ShadowSamplingData samplingData)
            {
                real attenuation;

            #if defined(SHADER_API_MOBILE) || defined(SHADER_API_SWITCH)
                // 4-tap hardware comparison
                real4 attenuation4;
                attenuation4.x = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset0.xyz);
                attenuation4.y = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset1.xyz);
                attenuation4.z = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset2.xyz);
                attenuation4.w = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset3.xyz);
                attenuation = dot(attenuation4, 0.25);
            #else
                float fetchesWeights[9];
                float2 fetchesUV[9];
                SampleShadow_ComputeSamples_Tent_5x5(samplingData.shadowmapSize, shadowCoord.xy, fetchesWeights, fetchesUV);

                attenuation = fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[0].xy, shadowCoord.z));
                attenuation += fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[1].xy, shadowCoord.z));
                attenuation += fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[2].xy, shadowCoord.z));
                attenuation += fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[3].xy, shadowCoord.z));
                attenuation += fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[4].xy, shadowCoord.z));
                attenuation += fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[5].xy, shadowCoord.z));
                attenuation += fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[6].xy, shadowCoord.z));
                attenuation += fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[7].xy, shadowCoord.z));
                attenuation += fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[8].xy, shadowCoord.z));
            #endif

                return attenuation;
            }
            */

            TEXTURE2D(unity_RandomRotation16);  SAMPLER(sampler_unity_RandomRotation16);
            float4 unity_RandomRotation16_TexelSize;
            #define ditherPatternOptimized float4x4(0.0,0.5,0.125,0.625, 0.75,0.22,0.875,0.375, 0.1875,0.6875,0.0625,0.5625, 0.9375,0.4375,0.8125,0.3125)
            #define SHADOW_ITERATIONS 4
            #define DENOISER_ITERATIONS 2
            #define DENOISER_EDGE_TOLERANCE 0.05

            uniform float SOFTNESS_OPTIMIZED = 0.05;
            float InterleavedGradientNoiseOptimized(float2 position_screen)
            {
                float ditherValue = ditherPatternOptimized[position_screen.x * _ScreenParams.x % 4][position_screen.y * _ScreenParams.y % 4] * FOUR_PI;
                return ditherValue;
            }
            float2 VogelDiskSampleOptimized(int sampleIndex, int samplesCount, float phi)
            {
                //float phi = 3.14159265359f;//UNITY_PI;
                float GoldenAngle = 2.4f;

                float r = sqrt(sampleIndex + 0.5f) / sqrt(samplesCount);
                float theta = sampleIndex * GoldenAngle + phi;

                float sine, cosine;
                sincos(theta, sine, cosine);

                return float2(r * cosine, r * sine);
            }

            real SamleShadowPCF(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float4 shadowCoord, ShadowSamplingData samplingData)
            {
                
                half shadowAttenuation = 0;
                #ifdef SHADOW_NICE_QUALITY
                    half center = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz);
                    float shadow = 0.0;
                    float total = 0.0;

                    float2 softness = (1 - (_ShadowSoftSize * 3.0)) * samplingData.shadowmapSize.zw ;
                    UNITY_UNROLL
                    for (float x = -DENOISER_ITERATIONS; x <= DENOISER_ITERATIONS; ++x)
                    {
                        for (float y = -DENOISER_ITERATIONS; y <= DENOISER_ITERATIONS; ++y)
                        {
                            half sampleSM = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + float3(float2(x, y) / softness,0));
                            float weight = saturate(1.0 - abs(center - sampleSM) * DENOISER_EDGE_TOLERANCE);
                            shadow += sampleSM * weight;
                            total += weight;
                        }
                    }

                    shadowAttenuation = shadow / total;
                #else
                    float diskRadius = clamp(_ShadowSoftSize, 0.001, 0.25) * 0.065;
                    float2 jitterUV = shadowCoord.xy * _ScreenParams.xy  * 64;
                    float4x4 Offset = float4x4(samplingData.shadowOffset0,samplingData.shadowOffset1,samplingData.shadowOffset2,samplingData.shadowOffset3);
                    jitterUV += frac(half2(_Time.x, -_Time.z));
                    float3 jitterTexture = SAMPLE_TEXTURE2D(unity_RandomRotation16, sampler_unity_RandomRotation16, jitterUV ).xyz;
                    float randPied = InterleavedGradientNoiseOptimized(jitterTexture.xy) * TWO_PI;
                    randPied /= max(1.0, shadowCoord.z);
                    UNITY_UNROLL
                    for (uint i = 0u; i < SHADOW_ITERATIONS; ++i)
                    {
                        float2 rotatedOffset = VogelDiskSampleOptimized(i, SHADOW_ITERATIONS, randPied) * diskRadius ;
                        shadowAttenuation += SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + Offset[i].xyz +float3(rotatedOffset,0));
                    }
                shadowAttenuation =saturate(shadowAttenuation *0.25);
                #endif
                return shadowAttenuation;
            }

            real CustomSampleShadowmap(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float4 shadowCoord, ShadowSamplingData samplingData, half4 shadowParams, bool isPerspectiveProjection = true)
            {
                // Compiler will optimize this branch away as long as isPerspectiveProjection is known at compile time
                if (isPerspectiveProjection)
                    shadowCoord.xyz /= shadowCoord.w;

                real attenuation;
                real shadowStrength = shadowParams.x;

                // TODO: We could branch on if this light has soft shadows (shadowParams.y) to save perf on some platforms.
            #ifdef _SHADOWS_SOFT
                #ifdef USE_PCF_SHADOW
                    attenuation = SamleShadowPCF(TEXTURE2D_SHADOW_ARGS(ShadowMap, sampler_ShadowMap), shadowCoord, samplingData);
                #else
                    attenuation = SampleShadowmapFiltered(TEXTURE2D_SHADOW_ARGS(ShadowMap, sampler_ShadowMap), shadowCoord, samplingData);
                #endif
            #else
                // 1-tap hardware comparison
                attenuation = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz);
            #endif

                attenuation = LerpWhiteTo(attenuation, shadowStrength);

                // Shadow coords that fall out of the light frustum volume must always return attenuation 1.0
                // TODO: We could use branch here to save some perf on some platforms.
                return BEYOND_SHADOW_FAR(shadowCoord) ? 1.0 : attenuation;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Light GetMainLight(float4 shadowCoord) 在 Lighting.hlsl
                // half MainLightRealtimeShadow(float4 shadowCoord) 在 Shadows.hlsl
                //因为影子和光照牵扯的比较多,影子本身又和烘培有关系，情况较多，本实例只演示实时阴影的使用方式，由上述2个函数修改而来。
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);//这个转换函数还可以再拆，但是没有必要, 在 Shadows.hlsl 可以自行学习（其实就是多了一个计算阴影级联的宏）
                ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
                half4 shadowParams = GetMainLightShadowParams();
                //实时光的本质还是采样shadow map. _SHADOWS_SOFT 作用发挥在SampleShadowmap函数中，不定义的话没有软阴影
                half shadowAttenuation = SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);

                shadowAttenuation = CustomSampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
                half3 shadowColor = LerpWhiteTo(_ShadowColor,1.0 - shadowAttenuation);
                //这里为了方便观察直接用采样结果作为rgb
                half4 baseColor = half4(shadowColor,1);
                return baseColor;
            }

            ENDHLSL
        }
    }
}
