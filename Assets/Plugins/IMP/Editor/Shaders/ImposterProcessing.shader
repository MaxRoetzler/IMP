Shader "Hidden/XRA/IMP/ImposterProcessing"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always
        
		Pass
		{
		
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;
			sampler2D _BackTex;
            float4 _Channels;
            
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2Dlod(_MainTex, float4(i.uv,0,0));


                return fixed4(col.rgb,0);
                
			}
			ENDCG
		}
		
		Pass //1 combine
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;
			sampler2D _MainTex2;
            float _Step;
            
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				
				fixed4 col2 = tex2D(_MainTex2, i.uv);
								
                return fixed4(col.rgb,col2.r);
                
			}
			ENDCG
		}
		
		Pass //2 padding
		{
		    blend off
		    cull off
		    zwrite off
		    ztest off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = v.vertex;
				o.uv = v.uv;
				return o;
			}
			
			texture2D _MainTex; 
			float4 _TexelSize; //_MainTex_TexelSize 
			texture2D _MaskTex;
			texture2D _ErodeTex;
			SamplerState _LinearClamp;
			float _AlphaStep;
			float _FillAlpha;
            
            struct fragOut{
                half4 color : COLOR0;
                half4 mask : COLOR1;
            };
            
            #define STEPS 8
            
			fragOut frag (v2f i) : SV_Target
			{
			    fragOut o;
			    
			    float2 offsets[STEPS] = {float2(-1,0),float2(1,0),float2(0,1),float2(0,-1),float2(-1,1),float2(1,1),float2(1,-1),float2(-1,-1)};
			
				half4 col = _MainTex.Sample(_LinearClamp, i.uv);
                half4 mask = _MaskTex.Sample(_LinearClamp, i.uv);
                
                o.color = col;
                o.mask = mask;
                
                for( int n=0; n<STEPS; n++ )
                {
                    half2 coord = offsets[n] * _TexelSize.xy;
                    
                    half4 maskN = _MaskTex.Sample(_LinearClamp, i.uv+coord);
                    
                    if ( mask.r == 0.0 && maskN.r > 0.0 )
                    {
                        o.mask.r = 1;
                        o.color = _MainTex.Sample(_LinearClamp, i.uv+coord );
                        if ( _FillAlpha > 0.0 )
                        {
                            //from 0.5 to 0.0 outward
                            o.color.a = saturate( lerp(-0.5,0.5,_AlphaStep) );
                        }
                    }
                    if ( mask.g == 1.0 && maskN.g < 1.0 )
                    {
                        o.mask.g = 0.0;
                        if ( _FillAlpha > 0.0 )
                        {
                            //from 0.5 to 1.0 inward
                            o.color.a = saturate( lerp(1.5,0.5,_AlphaStep) );//, o.color.a);
                        }
                    }
                }

                return o;
                                
			}
			ENDCG
		}
		
        Pass //3 step alpha
		{
		    blend off
		    
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			            
			half4 frag (v2f i) : SV_Target
			{
				half4 col = tex2D(_MainTex, i.uv);
                return half4( 1-step(col.r,0.0), 1-step(col.r,0.0), 0, 0 );                                
			}
			ENDCG
		}
	}
}
