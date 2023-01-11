#ifndef UNIVERSAL_VAD_LITINPUT_INCLUDED
#define UNIVERSAL_VAD_LITINPUT_INCLUDED

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
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

        CBUFFER_START(UnityPerMaterial)
        float4 _Color, _DarkColor;
        float _ShadowSHStrength,_MainColorStrength,_AlphaCutOff;

        half4 _SpecularColor, _SpecularColor1;
        float4 _StretchedNoise_ST,_MainTex_ST;
        half _SpecularExp, _Shift, _SpecularExp1, _Shift1, _NoiseEXP;
		int	_DbugShadowSH, _DbugSpecular;
        CBUFFER_END

        TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
        TEXTURE2D(_StretchedNoise);SAMPLER(sampler_StretchedNoise);

    struct Varyings
    {
        float4 positionCS               : SV_POSITION;
        float2 uv                       : TEXCOORD0;
        float3 normalWS                 : TEXCOORD1;
        float3 bitangentWS              : TEXCOORD2; 
        float3 viewWS                   : TEXCOORD3;
        float3 positionWS               : TEXCOORD4;
    	float4 texcoord1				: TEXCOORD5;
    	float4 texcoord2				: TEXCOORD6;
    	float4 texcoord3				: TEXCOORD7;
    	float4 color                    : COLOR;
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
    float GetShadowSH4(float3 dir,float4 sh0123,float4 sh4567,float sh8)
    {
        float res = sh0123.x * 0.28209479f;
        float temp = dir.y * sh0123.y * 0.48860251;
        res += temp;
        temp = dir.z * sh0123.z * 0.48860251;
        res += temp;
        temp = dir.x * sh0123.w * 0.48860251;
        res += temp;

        // temp = dir.x * dir.y * sh4567.x * 1.09254843;
        // res += temp;
        // temp = dir.y * dir.z * sh4567.y * 1.09254843;
        // res += temp;
        // temp = (-dir.x * dir.x - dir.y * dir.y + 2 * dir.z * dir.z) * sh4567.z * 0.31539157;
        // res += temp;
        // temp = dir.z * dir.x * sh4567.w * 1.09254843f;
        // res += temp;
        // temp = (dir.x * dir.x - dir.y * dir.y) * sh8 * 0.54627421;
        // res += temp;
        return  saturate(res);
    }

    //注意是副切线不是切线，也就是切线空间 TBN 中的 B
    half3 ShiftTangent_F(half3 bitangentWS,half3 normalWS,half shift)
    {
        half3 shiftedT = bitangentWS + shift * normalWS;
        return normalize(shiftedT);
    }

    half StrandSpecular(half3 bitangentWS,half3 viewDirWS,half3 lightDirWS,half exponent)
    {
        half3 H = normalize(lightDirWS + viewDirWS);
        half dotTH = dot(bitangentWS,H); // 点乘 计算出来的是2个单位向量的cos的值
        half sinTH = sqrt(1.0 - dotTH * dotTH);//因为 sin^2 + cos^2 = 1 所以 sin = sqrt(1 - cos^2);
        half dirAttenuation = smoothstep(-1.0,0.0,dotTH);
        return dirAttenuation * pow(sinTH,exponent);
    }

    half3 LightingHair(half3 bitangentWS, half3 lightDirWS, half3 normalWS, half3 viewDirWS, float2 uv,half exp,half exp1,half3 specular,half3 specular1)
    {
        //shift tangents
        half shiftTex = (SAMPLE_TEXTURE2D(_StretchedNoise, sampler_StretchedNoise, uv).r - 0.5) * _NoiseEXP;
        half3 t1 = ShiftTangent_F(bitangentWS,normalWS,_Shift + shiftTex);
        half3 t2 = ShiftTangent_F(bitangentWS,normalWS,_Shift1 + shiftTex);
        //specular
        half3 specularColor1  = StrandSpecular(t1,viewDirWS,lightDirWS,exp) * specular;
        half3 specularColor2  = StrandSpecular(t2,viewDirWS,lightDirWS,exp1) * specular1;

        return max(0.01,specularColor1 + specularColor2);

    }

    Varyings PBRVertex(Attributes input)
    {
        Varyings output = (Varyings)0;
	    VertexPositionInputs PosInput = GetVertexPositionInputs(input.positionOS.xyz);
	    VertexNormalInputs NormalInput = GetVertexNormalInputs(input.normalOS,input.tangentOS);

		output.color = 0;
	    output.positionWS = PosInput.positionWS;
	    output.positionCS = PosInput.positionCS;
	    output.bitangentWS = NormalInput.bitangentWS;
	    output.normalWS = NormalInput.normalWS;
	    output.viewWS = GetWorldSpaceViewDir(output.positionWS);
        output.uv = TRANSFORM_TEX(input.texcoord,_MainTex);
		output.texcoord1 = input.texcoord1;
		output.texcoord2 = input.texcoord2;
		output.texcoord3 = input.texcoord3;
		
	    return output;
    }

    half4 PBRFragment(Varyings input) : SV_Target
    {
    	Light light = GetMainLight();
	    half3 attenuatedLightColor = light.color * light.distanceAttenuation;
        half3 normalWS = normalize(input.normalWS);
        half3 viewWS = SafeNormalize(input.viewWS);
        half3 bitangentWS = normalize(input.bitangentWS);

    	half NL = saturate(dot(light.direction,input.normalWS));
    	float3 DiffuselightDir = normalize(mul(unity_WorldToObject, float4(light.direction, 0)).xyz);
    	half ShadowSH = min(NL,GetShadowSH4(DiffuselightDir, input.texcoord1, input.texcoord2, input.texcoord3.x));
    	half DebugShadowSH = ShadowSH;
    	ShadowSH = lerp(1.0,ShadowSH,_ShadowSHStrength);
    	
    	float4 BaseColor = lerp(1.0, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv), _MainColorStrength) * _Color;
    	
        half smoothness = exp2(10 * _SpecularExp + 1);
        half smoothness1 = exp2(10 * _SpecularExp1 + 1);

    	half3 DiffuseColor = ShadowSH.xxx * attenuatedLightColor * BaseColor.rgb;
    	half3 SpecularColor = ShadowSH * attenuatedLightColor *
        	LightingHair(bitangentWS,light.direction,normalWS,viewWS,input.uv,smoothness,smoothness1,_SpecularColor.rgb,_SpecularColor1.rgb);
    	
    	int additionalLightCount = GetAdditionalLightsCount();//获取额外光源数量
    	for (int i = 0; i < additionalLightCount; ++i)
    	{
    		light = GetAdditionalLight(i, input.positionWS);//根据index获取额外的光源数据
    		attenuatedLightColor = light.color * light.distanceAttenuation;
    		half NL = saturate(dot(light.direction,input.normalWS));
    		DiffuselightDir = normalize(mul(unity_WorldToObject, float4(light.direction, 0)).xyz);
    		ShadowSH = min(NL,GetShadowSH4(DiffuselightDir, input.texcoord1, input.texcoord2, input.texcoord3.x));
    		DebugShadowSH += ShadowSH;
    		ShadowSH = lerp(1.0,ShadowSH,_ShadowSHStrength);
    		
			DiffuseColor += ShadowSH.xxx * attenuatedLightColor * BaseColor.rgb;
    		SpecularColor += ShadowSH.xxx * attenuatedLightColor *
    			LightingHair(bitangentWS,light.direction,normalWS,viewWS,input.uv,smoothness,smoothness1,_SpecularColor.rgb,_SpecularColor1.rgb);
	    }
    	
		half3 ambientColor = SampleSH(normalWS) * BaseColor.rgb;
    	float4 outcolor = float4(ambientColor + DiffuseColor + SpecularColor, saturate(BaseColor.a));
        
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

    	//debg
    	outcolor.rgb = lerp(outcolor.rgb,DebugShadowSH,_DbugShadowSH);
    	outcolor.rgb = lerp(outcolor.rgb,SpecularColor,_DbugSpecular);
    	// outcolor.rgb = BaseColor;
    	// outcolor.rgb = input.color.rgb * BaseColor * _Color.rgb;
    	// outcolor.rgb = hairColor + ;
        
        return outcolor;
    }

#endif
