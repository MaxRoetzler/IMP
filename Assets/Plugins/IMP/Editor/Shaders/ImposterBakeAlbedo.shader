Shader "Hidden/XRA/IMP/ImposterBakeAlbedo"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Cull off ZWrite on ZTest LEqual
        
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;
			
			float4 _Color;
			
			half _ImposterRenderAlpha; //hacky used to toggle alpha only output only due to relying on replacement shaders

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 screenPos : TEXCOORD1;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos( o.vertex );
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
			    //half2 spos = i.screenPos.xy / i.screenPos.w;
			    //spos *= 0.5+0.5;
			    //half dist = distance(spos.xy,half2(0.5,0.5));
			    //
			    //dist = 1-saturate( dist / 0.2);
			    
				float4 col = tex2D(_MainTex, i.uv) * _Color;
				
				if ( _ImposterRenderAlpha > 0.5 )
				{
				    return col.aaaa;
				}
				
				return col;
			}
			ENDCG
		}
	}
}
