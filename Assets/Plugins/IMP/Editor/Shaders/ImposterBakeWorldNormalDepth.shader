Shader "Hidden/XRA/IMP/ImposterBakeWorldNormalDepth"
{
	Properties
	{
		_BumpMap ("Normal", 2D) = "bump" {}
	}
	SubShader
	{
		Cull back ZWrite on ZTest LEqual

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "UnityStandardUtils.cginc"

			sampler2D _BumpMap;
			float4 _BumpMap_TexelSize;
			float4 _BumpMap_ST;
			float4 _MainTex_ST;
			float _BumpScale;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
				float  depth : TEXCOORD4;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				
				float3 worldPos = mul(unity_ObjectToWorld,v.vertex);
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
   
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
				
				o.depth = COMPUTE_DEPTH_01;
				
				return o;
			}
			


			float4 frag (v2f i) : SV_Target
			{
			    float3 worldPos = float3(i.TtoW0.w,i.TtoW1.w,i.TtoW2.w);

			    float depth = 1-i.depth;
			
				float3 normTangent = UnpackScaleNormal( tex2D(_BumpMap, i.uv), _BumpScale );
				
				float3 normWorld = normalize( float3( dot(i.TtoW0.xyz, normTangent), dot(i.TtoW1.xyz, normTangent), dot(i.TtoW2.xyz, normTangent) ) );
				
				return float4(normWorld.rgb*0.5+0.5, depth);
			}
			ENDCG
		}
	}
}
