#ifndef XRA_IMPOSTERCOMMON_CGINC
#define XRA_IMPOSTERCOMMON_CGINC

sampler2D _ImposterBaseTex;
float4 _ImposterBaseTex_TexelSize;
sampler2D _ImposterWorldNormalDepthTex;

half _ImposterFrames;
half _ImposterSize;
half3 _ImposterOffset;
half _ImposterFullSphere;
half _ImposterBorderClamp;

struct ImposterData
{
    half2 uv;
    half2 grid;
    half4 frame0;
    half4 frame1;
    half4 frame2;
    half4 vertex;
};

struct Ray
{
    half3 Origin;
    half3 Direction;
};

half3 NormalizePerPixelNormal (half3 n)
{
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
        return n;
    #else
        return normalize(n);
    #endif
}

half3 PerPixelWorldNormal(float4 i_tex, half4 tangentToWorld[3])
{
#ifdef _NORMALMAP
    half3 tangent = tangentToWorld[0].xyz;
    half3 binormal = tangentToWorld[1].xyz;
    half3 normal = tangentToWorld[2].xyz;

    #if UNITY_TANGENT_ORTHONORMALIZE
        normal = NormalizePerPixelNormal(normal);

        // ortho-normalize Tangent
        tangent = normalize (tangent - normal * dot(tangent, normal));

        // recalculate Binormal
        half3 newB = cross(normal, tangent);
        binormal = newB * sign (dot (newB, binormal));
    #endif

    half3 normalTangent = NormalInTangentSpace(i_tex);
    half3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
#else
    half3 normalWorld = normalize(tangentToWorld[2].xyz);
#endif
    return normalWorld;
}

half4 BakeNormalsDepth( sampler2D bumpMap, half2 uv, half depth, half4 tangentToWorld[3] )
{
    half4 tex = tex2D( bumpMap, uv );
    
    half3 worldNormal = PerPixelWorldNormal(tex, tangentToWorld);
    
    return half4( worldNormal.xyz*0.5+0.5, 1-depth );
}

half4 ImposterBlendWeights( sampler2D tex, half2 uv, half2 frame0, half2 frame1, half2 frame2, half4 weights, half2 dx, half2 dy )
{    
    half4 samp0 = tex2Dgrad( tex, frame0, dx.xy, dy.xy );
    half4 samp1 = tex2Dgrad( tex, frame1, dx.xy, dy.xy );
    half4 samp2 = tex2Dgrad( tex, frame2, dx.xy, dy.xy );

    half4 result = samp0*weights.x + samp1*weights.y + samp2*weights.z;
    
    return result;
}

float Isolate( float c, float w, float x )
{
    return smoothstep(c-w,c,x)-smoothstep(c,c+w,x);
}

float SphereMask( float2 p1, float2 p2, float r, float h )
{
    float d = distance(p1,p2);
    return 1-smoothstep(d,r,h);
}

//for hemisphere
half3 OctaHemiEnc( half2 coord )
{
 	coord = half2( coord.x + coord.y, coord.x - coord.y ) * 0.5;
 	half3 vec = half3( coord.x, 1.0 - dot( half2(1.0,1.0), abs(coord.xy) ), coord.y  );
 	return vec;
}
//for sphere
half3 OctaSphereEnc( half2 coord )
{
    half3 vec = half3( coord.x, 1-dot(1,abs(coord)), coord.y );
    if ( vec.y < 0 )
    {
        half2 flip = vec.xz >= 0 ? half2(1,1) : half2(-1,-1);
        vec.xz = (1-abs(vec.zx)) * flip;
    }
    return vec;
}

half3 GridToVector( half2 coord )
{
    half3 vec;
    if ( _ImposterFullSphere )
    {
        vec = OctaSphereEnc(coord);
    }
    else
    {
        vec = OctaHemiEnc(coord);
    }
    return vec;
}

//for hemisphere
half2 VecToHemiOct( half3 vec )
{
	vec.xz /= dot( 1.0, abs(vec) );
	return half2( vec.x + vec.z, vec.x - vec.z );
}

half2 VecToSphereOct( half3 vec )
{
    vec.xz /= dot( 1,  abs(vec) );
    if ( vec.y <= 0 )
    {
        half2 flip = vec.xz >= 0 ? half2(1,1) : half2(-1,-1);
        vec.xz = (1-abs(vec.zx)) * flip;
    }
    return vec.xz;
}
	
half2 VectorToGrid( half3 vec )
{
    half2 coord;

    if ( _ImposterFullSphere )
    {
        coord = VecToSphereOct( vec );
    }
    else
    {
        vec.y = max(0.001,vec.y);
        vec = normalize(vec);
        coord = VecToHemiOct( vec );
    }
    return coord;
}

half4 TriangleInterpolate( half2 uv )
{
    uv = frac(uv);

    half2 omuv = half2(1.0,1.0) - uv.xy;
    
    half4 res = half4(0,0,0,0);
    //frame 0
    res.x = min(omuv.x,omuv.y); 
    //frame 1
    res.y = abs( dot( uv, half2(1.0,-1.0) ) );
    //frame 2
    res.z = min(uv.x,uv.y); 
    //mask
    res.w = saturate(ceil(uv.x-uv.y));
    
    return res;
}

//frame and framecout, returns 
half3 FrameXYToRay( half2 frame, half2 frameCountMinusOne )
{
    //divide frame x y by framecount minus one to get 0-1
    half2 f = frame.xy / frameCountMinusOne;
    //bias and scale to -1 to 1
    f = (f-0.5)*2.0; 
    //convert to vector, either full sphere or hemi sphere
    half3 vec = GridToVector( f );
    vec = normalize(vec);
    return vec;
}

half3 ITBasis( half3 vec, half3 basedX, half3 basedY, half3 basedZ )
{
    return half3( dot(basedX,vec), dot(basedY,vec), dot(basedZ,vec) );
}
 
half3 FrameTransform( half3 projRay, half3 frameRay, out half3 worldX, out half3 worldZ  )
{
    //TODO something might be wrong here
    worldX = normalize( half3(-frameRay.z, 0, frameRay.x) );
    worldZ = normalize( cross(worldX, frameRay ) ); 
    
    projRay *= -1.0; 
    
    half3 local = normalize( ITBasis( projRay, worldX, frameRay, worldZ ) );
    return local;
}

half2 VirtualPlaneUV( half3 planeNormal, half3 planeX, half3 planeZ, half3 center, half2 uvScale, Ray rayLocal )
{
    half normalDotOrigin = dot(planeNormal,rayLocal.Origin);
    half normalDotCenter = dot(planeNormal,center);
    half normalDotRay = dot(planeNormal,rayLocal.Direction);
    
    half planeDistance = normalDotOrigin-normalDotCenter;
    planeDistance *= -1.0;
    
    half intersect = planeDistance / normalDotRay;
    
    half3 intersection = ((rayLocal.Direction * intersect) + rayLocal.Origin) - center;
    
    half dx = dot(planeX,intersection);
    half dz = dot(planeZ,intersection);
    
    half2 uv = half2(0,0);
    
    if ( intersect > 0 )
    {
        uv = half2(dx,dz);
    }
    else
    {
        uv = half2(0,0);
    }
    
    uv /= uvScale;
    uv += half2(0.5,0.5);
    return uv;
}


half3 SpriteProjection( half3 pivotToCameraRayLocal, half frames, half2 size, half2 coord )
{
    half3 gridVec = pivotToCameraRayLocal;
    
    //octahedron vector, pivot to camera
    half3 y = normalize(gridVec);
    
    half3 x = normalize( cross( y, half3(0.0, 1.0, 0.0) ) );
    half3 z = normalize( cross( x, y ) );

    half2 uv = ((coord*frames)-0.5) * 2.0; //-1 to 1 

    half3 newX = x * uv.x;
    half3 newZ = z * uv.y;
    
    half2 halfSize = size*0.5;
    
    newX *= halfSize.x;
    newZ *= halfSize.y;
    
    half3 res = newX + newZ;  
     
    return res;
}

void ImposterVertex( inout ImposterData imp )
{
    //incoming vertex, object space
    half4 vertex = imp.vertex;
    
    //camera in object space
    half3 objectSpaceCameraPos = mul( unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz,1) ).xyz;
    half2 texcoord = imp.uv;
    float4x4 objectToWorld = unity_ObjectToWorld;
    float4x4 worldToObject = unity_WorldToObject;

    half3 imposterPivotOffset = _ImposterOffset.xyz;
    half framesMinusOne = _ImposterFrames-1;
    
    float3 objectScale = float3(length(float3(objectToWorld[0].x, objectToWorld[1].x, objectToWorld[2].x)),
                                length(float3(objectToWorld[0].y, objectToWorld[1].y, objectToWorld[2].y)),
                                length(float3(objectToWorld[0].z, objectToWorld[1].z, objectToWorld[2].z)));
             
    //pivot to camera ray
    float3 pivotToCameraRay = normalize(objectSpaceCameraPos.xyz-imposterPivotOffset.xyz);

    //scale uv to single frame
    texcoord = half2(texcoord.x,texcoord.y)*(1.0/_ImposterFrames.x);  
    
    //radius * 2 * unity scaling
    half2 size = _ImposterSize.xx * 2.0; // * objectScale.xx; //unity_BillboardSize.xy                 
    
    half3 projected = SpriteProjection( pivotToCameraRay, _ImposterFrames, size, texcoord.xy );

    //this creates the proper offset for vertices to camera facing billboard
    half3 vertexOffset = projected + imposterPivotOffset;
    //subtract from camera pos 
    vertexOffset = normalize(objectSpaceCameraPos-vertexOffset);
    //then add the original projected world
    vertexOffset += projected;
    //remove position of vertex
    vertexOffset -= vertex.xyz;
    //add pivot
    vertexOffset += imposterPivotOffset;

    //camera to projection vector
    half3 rayDirectionLocal = (imposterPivotOffset + projected) - objectSpaceCameraPos;
                 
    //projected position to camera ray
    half3 projInterpolated = normalize( objectSpaceCameraPos - (projected + imposterPivotOffset) ); 
    
    Ray rayLocal;
    rayLocal.Origin = objectSpaceCameraPos-imposterPivotOffset; 
    rayLocal.Direction = rayDirectionLocal; 
    
    half2 grid = VectorToGrid( pivotToCameraRay );
    half2 gridRaw = grid;
    grid = saturate((grid+1.0)*0.5); //bias and scale to 0 to 1 
    grid *= framesMinusOne;
    
    half2 gridFrac = frac(grid);
    
    half2 gridFloor = floor(grid);
    
    half4 weights = TriangleInterpolate( gridFrac ); 
    
    //3 nearest frames
    half2 frame0 = gridFloor;
    half2 frame1 = gridFloor + lerp(half2(0,1),half2(1,0),weights.w);
    half2 frame2 = gridFloor + half2(1,1);
    
    //convert frame coordinate to octahedron direction
    half3 frame0ray = FrameXYToRay(frame0, framesMinusOne.xx);
    half3 frame1ray = FrameXYToRay(frame1, framesMinusOne.xx);
    half3 frame2ray = FrameXYToRay(frame2, framesMinusOne.xx);
    
    half3 planeCenter = half3(0,0,0);
    
    half3 plane0x;
    half3 plane0normal = frame0ray;
    half3 plane0z;
    half3 frame0local = FrameTransform( projInterpolated, frame0ray, plane0x, plane0z );
    frame0local.xz = frame0local.xz/_ImposterFrames.xx; //for displacement
    
    //virtual plane UV coordinates
    half2 vUv0 = VirtualPlaneUV( plane0normal, plane0x, plane0z, planeCenter, size, rayLocal );
    vUv0 /= _ImposterFrames.xx;   
    
    half3 plane1x; 
    half3 plane1normal = frame1ray;
    half3 plane1z;
    half3 frame1local = FrameTransform( projInterpolated, frame1ray, plane1x, plane1z);
    frame1local.xz = frame1local.xz/_ImposterFrames.xx; //for displacement
    
    //virtual plane UV coordinates
    half2 vUv1 = VirtualPlaneUV( plane1normal, plane1x, plane1z, planeCenter, size, rayLocal );
    vUv1 /= _ImposterFrames.xx;
    
    half3 plane2x;
    half3 plane2normal = frame2ray;
    half3 plane2z;
    half3 frame2local = FrameTransform( projInterpolated, frame2ray, plane2x, plane2z );
    frame2local.xz = frame2local.xz/_ImposterFrames.xx; //for displacement
    
    //virtual plane UV coordinates
    half2 vUv2 = VirtualPlaneUV( plane2normal, plane2x, plane2z, planeCenter, size, rayLocal );
    vUv2 /= _ImposterFrames.xx;
    
    //add offset here
    imp.vertex.xyz += vertexOffset;
    //overwrite others
    imp.uv = texcoord;
    imp.grid = grid;
    imp.frame0 = half4(vUv0.xy,frame0local.xz);
    imp.frame1 = half4(vUv1.xy,frame1local.xz);
    imp.frame2 = half4(vUv2.xy,frame2local.xz);
}

void ImposterSample( in ImposterData imp, out half4 baseTex, out half4 worldNormal )//, out half depth )
{
    half2 fracGrid = frac(imp.grid);
    
    half4 weights = TriangleInterpolate( fracGrid );
      
    half2 gridSnap = floor(imp.grid) / _ImposterFrames.xx;
        
    half2 frame0 = gridSnap;
    half2 frame1 = gridSnap + (lerp(half2(0,1),half2(1,0),weights.w)/_ImposterFrames.xx);
    half2 frame2 = gridSnap + (half2(1,1)/_ImposterFrames.xx);
    


    half2 vp0uv = frame0 + imp.frame0.xy;
    half2 vp1uv = frame1 + imp.frame1.xy; 
    half2 vp2uv = frame2 + imp.frame2.xy;
   
    //clamp out neighboring frames TODO maybe discard instead?
    half2 gridSize = 1.0/_ImposterFrames.xx;
    gridSize *= _ImposterBaseTex_TexelSize.zw;
    gridSize *= _ImposterBaseTex_TexelSize.xy;
    float2 border = _ImposterBaseTex_TexelSize.xy*_ImposterBorderClamp;
    
    //vp0uv = clamp(vp0uv,frame0+border,frame0+gridSize-border);
    //vp1uv = clamp(vp1uv,frame1+border,frame1+gridSize-border);
    //vp2uv = clamp(vp2uv,frame2+border,frame2+gridSize-border);
   
    //for parallax modify
    half4 n0 = tex2Dlod( _ImposterWorldNormalDepthTex, half4(vp0uv, 0, 1 ) );
    half4 n1 = tex2Dlod( _ImposterWorldNormalDepthTex, half4(vp1uv, 0, 1 ) );
    half4 n2 = tex2Dlod( _ImposterWorldNormalDepthTex, half4(vp2uv, 0, 1 ) );
    
    //dx dy
    half2 coords = imp.uv.xy * 0.5;
    float2 dx = ddx(coords.xy);  
    float2 dy = ddy(coords.xy);
    
    half n0s = 0.5-n0.a;    
    half n1s = 0.5-n1.a;
    half n2s = 0.5-n2.a;
    
    half2 n0p = imp.frame0.zw * n0s;
    half2 n1p = imp.frame1.zw * n1s;
    half2 n2p = imp.frame2.zw * n2s;
    
    //add parallax shift 
    vp0uv += n0p;
    vp1uv += n1p;
    vp2uv += n2p;
    
    //clamp out neighboring frames TODO maybe discard instead?
    vp0uv = clamp(vp0uv,frame0+border,frame0+gridSize-border);
    vp1uv = clamp(vp1uv,frame1+border,frame1+gridSize-border);
    vp2uv = clamp(vp2uv,frame2+border,frame2+gridSize-border);
    
    worldNormal = ImposterBlendWeights( _ImposterWorldNormalDepthTex, imp.uv, vp0uv, vp1uv, vp2uv, weights, dx, dy );
    baseTex = ImposterBlendWeights( _ImposterBaseTex, imp.uv, vp0uv, vp1uv, vp2uv, weights, dx, dy );
        
    //pixel depth offset
    //half pdo = 1-baseTex.a;
    //float3 objectScale = float3(length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)),
    //                        length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)),
    //                        length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z)));
    //half2 size = _ImposterSize.xx * 2.0;// * objectScale.xx;  
    //half3 viewWorld = mul( UNITY_MATRIX_VP, float4(0,0,1,0) ).xyz;
    //pdo *= size * abs(dot(normalize(imp.viewDirWorld.xyz),viewWorld));
    //depth = pdo;
}

#endif //XRA_IMPOSTERCOMMON_CGINC