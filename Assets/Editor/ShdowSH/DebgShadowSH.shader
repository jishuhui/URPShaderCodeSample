Shader "Plpeline/DebugShadowSH"
{
    Properties
    {
        [Toggle]_DbugShadowSH("debugShadowSH",float) = 0
        [Toggle]_DbugSpecular("DbugSpecular",float) = 0
        [Toggle]_DbugVertexColor("DbugVertexColor",float) = 0
        _Color("Color",COLOR) = (1,1,1,1)
//        _DarkColor("Color",COLOR) = (0,0,0,1)
        _MainTex ("Texture", 2D) = "white" {}
        _AlphaCutOff ("_AlphaCutOff" , Range(0, 1)) = 0.1
//        _AlphaCutOff1 ("_AlphaCutOff" , Range(0, 1)) = 0.9
        _ShadowSHStrength ("ShadowSH" , Range(0, 1)) = 0.5
        _MainColorStrength ("_MainColorStrength" , Range(0, 1)) = 0.5
        [Space(20)]
        _SpecularColor ("SpecularColor 1", Color) = (1,1,1,1)
        _SpecularExp ("Smoothness 1", Range(0,1)) = 0.5
        _Shift("Shift 1",float) = 0
        [Space(20)]
        _SpecularColor1 ("SpecularColor 2", Color) = (1,1,1,1)
        _SpecularExp1 ("Smoothness 2", Range(0,1)) = 0.5
        _Shift1("Shift 2",float) = 0
        _StretchedNoise("StretchedNoise", 2D) = "white" {}
        _NoiseEXP ("NoiseEXP", Range(-1,1)) = 0
    }

    SubShader
    {
		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        HLSLINCLUDE
        #include "ShadowSH_Function.hlsl"
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
            #pragma multi_compile DITHER
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