Shader "XRA/IMP/UnityBillboard" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
        
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		
		_ImposterBaseTex ("Imposter Base", 2D) = "black" {}
		_ImposterWorldNormalDepthTex ("WorldNormal+Depth", 2D) = "black" {}
		_ImposterFrames ("Frames",  float) = 8
		_ImposterSize ("Radius", float) = 1
		_ImposterOffset ("Offset", Vector) = (0,0,0,0)
		_ImposterFullSphere ("Full Sphere", float) = 0
		
        //_Mode ("__mode", Float) = 0.0 
        //_SrcBlend ("__src", Float) = 1.0
        //_DstBlend ("__dst", Float) = 0.0
        //_ZWrite ("__zw", Float) = 1.0
        //[HideInInspector] 
	}

    SubShader{
        Tags { "IgnoreProjector" = "True" "RenderType" = "TreeBillboard" }

//TODO see \DefaultResourcesExtra\TerrainShaders\Trees\CameraFacingBillboardTree.shader

        //Pass {
            //ColorMask rgb
            ZWrite On 
            Cull back
            //AlphaToMask On

            CGPROGRAM
            //#pragma vertex vert
            //#pragma fragment frag
            //#pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "UnityBuiltin3xTreeLibrary.cginc"
            #include "ImposterCommon.cginc"
            
            #pragma surface surf Standard fullforwardshadows vertex:vert
		    #pragma target 3.5
    
            half _Glossiness;
            half _Metallic;
            half _Cutoff;
            
    
            // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
            // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
            // #pragma instancing_options assumeuniformscaling
            UNITY_INSTANCING_BUFFER_START(Props)
                // put more per-instance properties here
            UNITY_INSTANCING_BUFFER_END(Props)
    
            struct Input 
            {
                float4 texCoord; 
                float4 plane0;
                float4 plane1;
                float4 plane2;
                float3 tangentWorld;
                float3 bitangentWorld;
                float3 normalWorld;
            };
    
            void vert (inout appdata_full v, out Input o)
            {
                UNITY_INITIALIZE_OUTPUT(Input, o);
                ImposterData imp;
                //NOTE modified since Unity BillboardAsset takes vertex on X Y only
                imp.vertex.xyz = float3( (v.vertex.x*2-1)*0.5, 0, (v.vertex.y*2-1)*0.5 );
                imp.vertex.w = v.vertex.w;
                imp.uv = v.texcoord.xy;
                 
                ImposterVertex(imp); 
                
                //IMP results  
                //v2f
                v.vertex = imp.vertex;
                
                //NOTE modified since Unity BillboardAsset doesnt take normal or tangent
                v.normal = float3(0,1,0);
                v.tangent = float4(1,0,0,-1);
                
                float3 normalWorld = UnityObjectToWorldDir(v.normal);
                float3 tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld, v.tangent.w);
                o.tangentWorld = tangentToWorld[0];
                o.bitangentWorld = tangentToWorld[1];
                o.normalWorld = tangentToWorld[2];
                
                //surface
                o.texCoord.xy = imp.uv;
                o.texCoord.zw = imp.grid;
                o.plane0 = imp.frame0;
                o.plane1 = imp.frame1;
                o.plane2 = imp.frame2;
            }
            
            void surf (Input IN, inout SurfaceOutputStandard o)
            {
                ImposterData imp;
                //set inputs
                imp.uv = IN.texCoord.xy;
                imp.grid = IN.texCoord.zw;
                imp.frame0 = IN.plane0; 
                imp.frame1 = IN.plane1;
                imp.frame2 = IN.plane2;
                
                //perform texture sampling
                half4 baseTex;
                half4 normalTex;
                
                ImposterSample(imp, baseTex, normalTex );
                
                clip(baseTex.a-_Cutoff);
                
                //scale world normal back to -1 to 1
                half3 worldNormal = normalTex.xyz*2-1;
                
                //this works but not ideal
                worldNormal = mul( unity_ObjectToWorld, half4(worldNormal,0) ).xyz;
                
                half depth = normalTex.w; //maybe for pixel depth?
                
                half3 t = IN.tangentWorld;
                half3 b = IN.bitangentWorld;
                half3 n = IN.normalWorld;
            
                //from UnityStandardCore.cginc 
                #if UNITY_TANGENT_ORTHONORMALIZE
                    n = normalize(n);
            
                    //ortho-normalize Tangent
                    t = normalize (t - n * dot(t, n));
                    
                    //recalculate Binormal
                    half3 newB = cross(n, t);
                    b = newB * sign (dot (newB, b));
                #endif
                half3x3 tangentToWorld = half3x3(t, b, n); 
                
                //o well
                o.Normal = normalize(mul(tangentToWorld, worldNormal));
                
                o.Albedo = baseTex.rgb;
                o.Alpha = baseTex.a;
                o.Metallic = _Metallic;
                o.Smoothness = _Glossiness;
                o.Occlusion = 1;	
            }
            ENDCG
        //}
    }

    Fallback Off
}
