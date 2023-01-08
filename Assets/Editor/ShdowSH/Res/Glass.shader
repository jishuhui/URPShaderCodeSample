Shader "MHU3D/Particles/Glass"
{
	Properties
	{
		_MatCapTexture("MatCapTexture", 2D) = "black" {}
		_RefractTexture("RefractTexture", 2D) = "white" {}
		_RefractIntensity("RefractIntensity", Float) = 1
		_RefractColor("RefractColor", Color) = (0,0,0,0)
		_NormalTexture("NormalTexture", 2D) = "bump" {}
		_NormalIntensity("NormalIntensity", Float) = 0
	}

	SubShader
	{
		LOD 0

		
		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
		
		Cull Back
		AlphaToMask Off
		HLSLINCLUDE
		#pragma target 2.0
		ENDHLSL

		
		Pass
		{
			
			Name "Forward"
			Tags { "LightMode"="UniversalForward" }
			
			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite Off
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA
			

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"



			struct VertexInput
			{
				float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_tangent : TANGENT;
			};

			struct VertexOutput
			{
				float4 clipPos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				float4 ase_texcoord3 : TEXCOORD1;
				float4 ase_texcoord4 : TEXCOORD2;
				float4 ase_texcoord5 : TEXCOORD3;
				float4 ase_texcoord6 : TEXCOORD4;
				float4 ase_texcoord7 : TEXCOORD5;
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _NormalTexture_ST;
			float4 _RefractColor;
			float _NormalIntensity;
			float _RefractIntensity;
			CBUFFER_END
			sampler2D _MatCapTexture;
			sampler2D _NormalTexture;
			sampler2D _RefractTexture;


						
			VertexOutput vert ( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;

				float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				o.ase_texcoord5.xyz = ase_worldTangent;
				float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
				o.ase_texcoord6.xyz = ase_worldNormal;
				float ase_vertexTangentSign = v.ase_tangent.w * unity_WorldTransformParams.w;
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord7.xyz = ase_worldBitangent;
				o.ase_texcoord3 = v.vertex;
				o.ase_texcoord4.xy = v.ase_texcoord.xy;
				o.ase_texcoord4.zw = 0;
				o.ase_texcoord5.w = 0;
				o.ase_texcoord6.w = 0;
				o.ase_texcoord7.w = 0;
				v.ase_normal = v.ase_normal;

				float3 positionWS = TransformObjectToWorld( v.vertex.xyz );
				float4 positionCS = TransformWorldToHClip( positionWS );

				o.worldPos = positionWS;
				o.clipPos = positionCS;
				return o;
			}



			half4 frag ( VertexOutput IN  ) : SV_Target
			{
				float3 WorldPosition = IN.worldPos;

				float3 objToView15 = mul( UNITY_MATRIX_MV, float4( IN.ase_texcoord3.xyz, 1 ) ).xyz;
				float3 normalizeResult16 = normalize( objToView15 );
				float2 uv_NormalTexture = IN.ase_texcoord4.xy * _NormalTexture_ST.xy + _NormalTexture_ST.zw;
				float3 unpack53 = UnpackNormalScale( tex2D( _NormalTexture, uv_NormalTexture ), _NormalIntensity );
				unpack53.z = lerp( 1, unpack53.z, saturate(_NormalIntensity) );
				float3 tex2DNode53 = unpack53;
				float3 ase_worldTangent = IN.ase_texcoord5.xyz;
				float3 ase_worldNormal = IN.ase_texcoord6.xyz;
				float3 ase_worldBitangent = IN.ase_texcoord7.xyz;
				float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
				float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
				float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
				float3 tanNormal12 = tex2DNode53;
				float3 worldNormal12 = float3(dot(tanToWorld0,tanNormal12), dot(tanToWorld1,tanNormal12), dot(tanToWorld2,tanNormal12));
				float3 break20 = cross( normalizeResult16 , mul( UNITY_MATRIX_V, float4( worldNormal12 , 0.0 ) ).xyz );
				float2 appendResult21 = (float2(-break20.y , break20.x));
				float2 matcap_uv224 = (appendResult21*0.5 + 0.5);
				float4 tex2DNode1 = tex2D( _MatCapTexture, matcap_uv224 );
				float3 tanNormal30 = tex2DNode53;
				float3 worldNormal30 = float3(dot(tanToWorld0,tanNormal30), dot(tanToWorld1,tanNormal30), dot(tanToWorld2,tanNormal30));
				float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - WorldPosition );
				ase_worldViewDir = normalize(ase_worldViewDir);
				float dotResult31 = dot( worldNormal30 , ase_worldViewDir );
				float smoothstepResult33 = smoothstep( 0.0 , 1.0 , dotResult31);
				float Thickness43 = ( 1.0 - smoothstepResult33 );
				float temp_output_35_0 = ( Thickness43 * _RefractIntensity );
				float4 lerpResult40 = lerp( _RefractColor , tex2D( _RefractTexture, ( matcap_uv224 + temp_output_35_0 ) ) , saturate( temp_output_35_0 ));
				
				float3 BakedAlbedo = 0;
				float3 BakedEmission = 0;
				float3 Color = ( tex2DNode1 + lerpResult40 ).rgb;
				float Alpha = saturate( max( tex2DNode1.r , Thickness43 ) );
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;

				return half4( Color, Alpha );
			}

			ENDHLSL
		}

	
	}
}
