Shader "Plpeline/DebugShadowSH"
{
    Properties
    {
        [HDR]_Color("Color",COLOR) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _AlphaCutOff ("_AlphaCutOff" , Range(0, 1)) = 0.1
//        _AlphaCutOff1 ("_AlphaCutOff" , Range(0, 1)) = 0.9
        _ShadowSHStrength ("ShadowSH" , Range(0, 1)) = 0.5
        _MainColorStrength ("_MainColorStrength" , Range(0, 1)) = 0.5
    }

    SubShader
    {
		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
      
        struct Attributes
        {
            float4 positionOS   : POSITION;
            float3 normalOS     : NORMAL;
            float4 tangentOS    : TANGENT;
            float2 texcoord     : TEXCOORD0;
            float4 texcoord1     : TEXCOORD1;
            float4 texcoord2     : TEXCOORD2;
            float4 texcoord3     : TEXCOORD3;
        };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float4 _Color;
            float _ShadowSHStrength,_MainColorStrength,_AlphaCutOff,_AlphaCutOff1;

        struct Varyings
        {
            float2 uv                      : TEXCOORD0;
            float4 color                   : COLOR;
            float3 positionWS              : TEXCOORD3;
            float4 positionCS              : SV_POSITION;
        };

		inline float Dither8x8Bayer( int x, int y )
		{
			const float dither[ 64 ] = {
				 1, 49, 13, 61,  4, 52, 16, 64,
				33, 17, 45, 29, 36, 20, 48, 32,
				 9, 57,  5, 53, 12, 60,  8, 56,
				41, 25, 37, 21, 44, 28, 40, 24,
				 3, 51, 15, 63,  2, 50, 14, 62,
				35, 19, 47, 31, 34, 18, 46, 30,
				11, 59,  7, 55, 10, 58,  6, 54,
				43, 27, 39, 23, 42, 26, 38, 22};
			int r = y * 8 + x;
			return dither[r] / 64;
		}
        // 8x8数组
        half Dither8x8_Array(uint2 uv , float color)
        {
            uv %= 8;
            float A4x4[64]=
            {
                0,32,8,40,2,34,10,42,
                48,16,56,24,50,18,58,26,
                12,44,4,36,14,46,6,38,
                60,28,52,20,62,30,54,22,
                3,35,11,43,1,33,9,41,
                51,19,59,27,49,17,57,25,
                15,47,7,39,13,45,5,37,
                63,31,55,23,61,29,53,21
            };
            
            half pixel = A4x4[uv.x*8+uv.y]/64;
            return step(pixel,color);
        }


        float GetShadowSH9(float3 dir,float4 sh0123,float4 sh4567,float sh8)
        {
            float res = sh0123.x * 0.28209479f;
            float temp = dir.y * sh0123.y * 0.48860251;
            res += temp;
            temp = dir.z * sh0123.z * 0.48860251;
            res += temp;
            temp = dir.x * sh0123.w * 0.48860251;
            res += temp;

            temp = dir.x * dir.y * sh4567.x * 1.09254843;
            res += temp;
            temp = dir.y * dir.z * sh4567.y * 1.09254843;
            res += temp;
            temp = (-dir.x * dir.x - dir.y * dir.y + 2 * dir.z * dir.z) * sh4567.z * 0.31539157;
            res += temp;
            temp = dir.z * dir.x * sh4567.w * 1.09254843f;
            res += temp;
            temp = (dir.x * dir.x - dir.y * dir.y) * sh8 * 0.54627421;
            res += temp;
            return res;
        }

        Varyings PBRVertex(Attributes input)
        {
            Varyings output = (Varyings)0; 
            output.positionWS = TransformObjectToWorld(input.positionOS);
            output.positionCS = TransformWorldToHClip(output.positionWS);
            float3 lightDirection = _MainLightPosition.xyz;
            lightDirection = mul(unity_WorldToObject, float4(lightDirection.xyz, 0)).xyz;
            lightDirection = normalize(lightDirection);
            output.color = (GetShadowSH9(lightDirection, input.texcoord1, input.texcoord2, input.texcoord3.x)).xxxx;
            output.uv = input.texcoord;
            return output;
        }

        half4 PBRFragment(Varyings input) : SV_Target
        {

            float4 BaseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
            BaseColor.rgb = lerp(1.0,BaseColor.rgb,_MainColorStrength);
            float VertexColor = lerp(1.0,input.color.r,_ShadowSHStrength);
            float4 outcolor = float4(BaseColor.rgb * _Color * VertexColor * 1.3, BaseColor.a);
            #ifdef ALPHACLIP
                half alpha = outcolor.a;
                #ifdef DITHER
                    uint2 ditheruv = (uint2)input.positionCS.xy;
                    alpha = Dither8x8_Array(ditheruv,smoothstep(0, _AlphaCutOff, alpha) - 0.1);
                    clip(alpha - 0.5);
                #else
                    clip(alpha - _AlphaCutOff);
                #endif
            #endif
            
            return outcolor;
        }
        ENDHLSL

        //PASS0 AlphaCutOff
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "SRPDefaultUnlit"}
            ZWrite On
            Cull Off
            HLSLPROGRAM
            // Material Keywords
            #pragma multi_compile ALPHACLIP
            // #pragma multi_compile DITHER
            //
            #pragma vertex PBRVertex
            #pragma fragment PBRFragment
            ENDHLSL
        }
//        Pass1 Transparent
        Pass
        {
            Name "Forward"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite Off
            Cull Off
			Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex PBRVertex
            #pragma fragment PBRFragment
            
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}
            ZWrite On
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex PBRVertex
            #pragma fragment PBRFragment
            ENDHLSL
        }
    }
}