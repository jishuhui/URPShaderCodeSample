Shader "ShaderLearning/URP/Lighting/01_DepthRim"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _RimOffset ("RimOffest", Range(0.0 , 0.01)) = 0.0
        _RimOffsetX ("RimOffestX", Range(0.0 , 0.01)) = 0.0
        _RimOffsetY ("RimOffestY", Range(0.0 , 0.01)) = 0.0
        _RimThreshold ("RimThreshold", Range(0.0 ,1.0)) = 1.0
        _RimColor ("RimColor", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "Queue" = "Geometry+100"
        }
        // Depth
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }
            ZWrite On
            ColorMask 0
            Cull[_Cull]
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 uv : TEXCOORD0;
                half3 normal : NORMAL;          //法线
                half4 tangent : TANGENT;        //切线
                half4 color : COLOR0;           //顶点色
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 scrPos : TEXCOORD5;
                float3 worldPos : TEXCOORD1;        //世界坐标
                float3 worldNormal : TEXCOORD2;     //世界空间法线
                half4 color : COLOR0;               //顶点色
            };


            CBUFFER_START(UnityPerMaterial)
            sampler2D   _MainTex;
            float4  _MainTex_ST;

            float   _RimThreshold;
            float   _RimOffset, _RimOffsetX, _RimOffsetY;
            float4  _RimColor;
            CBUFFER_END

            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            v2f vert(appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normal, v.tangent);


                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos = vertexInput.positionCS;

                o.scrPos = ComputeScreenPos(vertexInput.positionCS);

                o.worldPos = vertexInput.positionWS;
                o.worldNormal = vertexNormalInput.normalWS;

                o.color = v.color;     //顶点色

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 sampleTex = tex2D(_MainTex, i.uv);
                half2 screenPos = i.scrPos.xy / i.scrPos.w;

                // 屏幕空间UV
                float2 RimScreenUV = float2(i.pos.x / _ScreenParams.x, i.pos.y / _ScreenParams.y);

                float3 N_WS = normalize(i.worldNormal);
                float3 N_VS = normalize(mul((float3x3)UNITY_MATRIX_V, N_WS));
                //偏移UV
                float2 RimOffsetUV = RimScreenUV + N_VS.xy * _RimOffset ;//float2(_RimOffect/i.clipW,0); 

                //采样深度图
                float ScreenDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, RimScreenUV);
                float OffsetDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, RimOffsetUV);

                float linear01EyeOffectDepth = Linear01Depth(OffsetDepth, _ZBufferParams);
                float linear01EyeTrueDepth = Linear01Depth(ScreenDepth, _ZBufferParams);

                float diff = linear01EyeOffectDepth - linear01EyeTrueDepth;    //深度差
                float rimMask = step(_RimThreshold * 0.1 ,  diff);

                // half4 RimColor = float4(rimMask * _RimColor.rgb * _RimColor.a, 1) * _EnableRim;
                half4 RimColor = float4(rimMask * _RimColor.rgb * _RimColor.a, 1) ;

                return RimColor;//float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}