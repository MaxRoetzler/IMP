using System;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;
#if UNITY_EDITOR
using UnityEditor;
#endif

public class BillboardImposter : ScriptableObject
{
    //things that are editor only, so they are not referenced in build, hopefully
#if UNITY_EDITOR
    public GameObject AssetReference;    
#endif
    public int AtlasResolution;

    public Texture2D BaseTexture;

    //the Unity BillboardAsset reference, stored in the BillboardImposter asset
    public BillboardAsset BillboardAsset;

    //capture settings
    public int Frames; //number of frames on X and Y
    public bool IsHalf; //is half hemisphere
    public Material Material;
    public Material BillboardRendererMaterial;
    public Mesh Mesh;
    public Vector3 Offset;
    public Texture2D PackTexture;
    public GameObject Prefab;
    public string PrefabSuffix;
    public float Radius;

#if UNITY_EDITOR
    private Mesh MeshSetup()
    {
        var vertices = new[]
        {
            new Vector3(0f, 0.0f, 0f),
            new Vector3(-0.5f, 0.0f, -0.5f),
            new Vector3(0.5f, 0.0f, -0.5f),
            new Vector3(0.5f, 0.0f, 0.5f),
            new Vector3(-0.5f, 0.0f, 0.5f)
        };

        var triangles = new[]
        {
            2, 1, 0,
            3, 2, 0,
            4, 3, 0,
            1, 4, 0
        };

        var uv = new[]
        {
            //UV matched to verts
            new Vector2(0.5f, 0.5f),
            new Vector2(0.0f, 0.0f),
            new Vector2(1.0f, 0.0f),
            new Vector2(1.0f, 1.0f),
            new Vector2(0.0f, 1.0f)
        };

        var normals = new[]
        {
            new Vector3(0f, 1f, 0f),
            new Vector3(0f, 1f, 0f),
            new Vector3(0f, 1f, 0f),
            new Vector3(0f, 1f, 0f),
            new Vector3(0f, 1f, 0f)
        };

        var mesh = new Mesh
        {
            vertices = vertices,
            uv = uv,
            normals = normals,
            tangents = new Vector4[5]
        };
        mesh.SetTriangles(triangles, 0);
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * Radius * 2f);
        mesh.RecalculateTangents();
        return mesh;
    }

    private static string WriteTexture(Texture2D tex, string path, string name)
    {
        var bytes = tex.EncodeToPNG();

        var fullPath = path + "/" + name + "_" + tex.name + ".png";
        File.WriteAllBytes(fullPath, bytes);
        
        DestroyImmediate(tex, true);

        return fullPath;
    }

    public void Save(string assetPath, string assetName, bool createBillboardAsset = false )
    {
        var lastSlash = assetPath.LastIndexOf("/", StringComparison.Ordinal);

        var folder = assetPath.Substring(0, lastSlash);

        EditorUtility.SetDirty(this);

        BaseTexture.name = "ImposterBase";
        var baseTexPath = WriteTexture(BaseTexture, folder, assetName);
        
        PackTexture.name = "ImposterPack";
        var normTexPath = WriteTexture(PackTexture, folder, assetName);

        AssetDatabase.Refresh();

        var importer = AssetImporter.GetAtPath(baseTexPath) as TextureImporter;
        if (importer != null)
        {
            importer.textureType = TextureImporterType.Default;
            importer.maxTextureSize = AtlasResolution;
            importer.alphaSource = TextureImporterAlphaSource.FromInput;
            importer.alphaIsTransparency = false;
            importer.sRGBTexture = false;
            importer.SaveAndReimport();
            BaseTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(baseTexPath);
        }
 
        importer = AssetImporter.GetAtPath(normTexPath) as TextureImporter;
        if (importer != null)
        {
            importer.textureType = TextureImporterType.Default;
            importer.maxTextureSize = AtlasResolution;
            importer.alphaSource = TextureImporterAlphaSource.FromInput;
            importer.alphaIsTransparency = false;
            importer.sRGBTexture = false;
            importer.SaveAndReimport();
            PackTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(normTexPath);
        }

        var shader = Shader.Find("XRA/IMP/Standard (Surface)");

        Material = new Material(shader);
        
        Material.SetTexture("_ImposterBaseTex", BaseTexture);
        Material.SetTexture("_ImposterWorldNormalDepthTex", PackTexture);

        Material.SetFloat("_ImposterFrames", Frames);
        Material.SetFloat("_ImposterSize", Radius);
        Material.SetVector("_ImposterOffset", Offset);
        Material.SetFloat("_ImposterFullSphere", IsHalf ? 0f : 1f);
        Material.name = assetName;
        EditorUtility.SetDirty(Material);

        //create material
        AssetDatabase.CreateAsset(Material, folder + "/" + assetName + "_Imposter_Mat.mat");
  
        //mesh (not for billboardAsset)
        Mesh = MeshSetup();
        Mesh.name = "ImposterQuad_" + Radius.ToString("F1");
        AssetDatabase.AddObjectToAsset(Mesh, assetPath);

        //create unity billboard asset, for billboard renderer
        //TODO has issues, but unity terrain is being upgraded so billboard renderer might be going
        if ( createBillboardAsset )
            BillboardAsset = CreateUnityBillboardAsset(folder,assetName,assetPath);
        
        AssetDatabase.SaveAssets();
    }


    private GameObject CreatePrefab(bool destroyAfterSpawn = false, string prefName = "")
    {
        var assetPath = AssetDatabase.GetAssetPath(this);
        var folder = assetPath.Substring(0, assetPath.LastIndexOf("/", StringComparison.Ordinal));


        if (string.IsNullOrEmpty(prefName)) prefName = name;

        if (PrefabSuffix != string.Empty) prefName = prefName + "_" + PrefabSuffix;

        var go = new GameObject(prefName);
        go.transform.position = Vector3.zero;
        go.transform.rotation = Quaternion.identity;
        go.transform.localScale = Vector3.one;
        var mf = go.AddComponent<MeshFilter>();
        var mr = go.AddComponent<MeshRenderer>();
        mf.sharedMesh = Mesh;
        mr.sharedMaterial = Material;

        mr.shadowCastingMode = ShadowCastingMode.Off;
        mr.receiveShadows = false;
        
        //try to get existing
        var prefabPath = folder + "/" + prefName + ".prefab";
        var existing = (GameObject) AssetDatabase.LoadAssetAtPath(prefabPath, typeof(GameObject));
        
        Prefab = existing != null ? PrefabUtility.ReplacePrefab(go, existing, ReplacePrefabOptions.Default) : PrefabUtility.CreatePrefab(prefabPath, go, ReplacePrefabOptions.Default);

        EditorUtility.SetDirty(Prefab);
        EditorUtility.SetDirty(this);
        AssetDatabase.SaveAssets();

        if (!destroyAfterSpawn) return go;
        DestroyImmediate(go, true);
        return null;
    }

    public GameObject Spawn(Vector3 pos, bool createNew = false, string prefabName = "")
    {
        if (Prefab == null || createNew)
            CreatePrefab(true, prefabName);

        return (GameObject)PrefabUtility.InstantiatePrefab(Prefab);
    }

    private BillboardAsset CreateUnityBillboardAsset( string folder, string assetName, string assetPath )
    {
        //shader for unity billboards (billboardRenderer and BillboardAsset)
        var shaderBillboard = Shader.Find("XRA/IMP/UnityBillboard");

        //billboardRenderer material
        BillboardRendererMaterial = new Material(shaderBillboard);
        
        BillboardRendererMaterial.SetTexture("_ImposterBaseTex", BaseTexture);
        BillboardRendererMaterial.SetTexture("_ImposterWorldNormalDepthTex", PackTexture);

        BillboardRendererMaterial.SetFloat("_ImposterFrames", Frames);
        BillboardRendererMaterial.SetFloat("_ImposterSize", Radius);
        BillboardRendererMaterial.SetVector("_ImposterOffset", Offset);
        BillboardRendererMaterial.SetFloat("_ImposterFullSphere", IsHalf ? 0f : 1f);
        BillboardRendererMaterial.name = assetName+"_BR";
        EditorUtility.SetDirty(BillboardRendererMaterial);
        
        //create material
        AssetDatabase.CreateAsset(BillboardRendererMaterial, folder + "/" + assetName + "_Imposter_BillboardMat.mat");

        //TODO billboard renderer support 
        //create billboard 
        BillboardAsset = new BillboardAsset
        {
            //for billboardRenderer use an alternative shader
            material = BillboardRendererMaterial
        };

        //billboard renderer vertices must be within 0 to 1 range
        //and only vector2 so we need to swwap the Y Z in shader 
        //in shader (*2-1)*0.5 to get back to original
        //also doesnt accept vertex normals
        BillboardAsset.SetVertices(new Vector2[]
        {
            new Vector2(0.5f, 0.5f),
            new Vector2(0.0f, 0.0f),
            new Vector2(1.0f, 0.0f),
            new Vector2(1.0f, 1.0f),
            new Vector2(0.0f, 1.0f)
        });
        BillboardAsset.SetIndices(new ushort[]
        {
            2, 1, 0,
            3, 2, 0,
            4, 3, 0,
            1, 4, 0
        });
        BillboardAsset.SetImageTexCoords(new Vector4[]
        {
            new Vector4(0.5f, 0.5f, 0f, 0f),
            new Vector4(0.0f, 0.0f, 0f, 0f),
            new Vector4(1.0f, 0.0f, 0f, 0f),
            new Vector4(1.0f, 1.0f, 0f, 0f),
            new Vector4(0.0f, 1.0f, 0f, 0f)
        });

        BillboardAsset.width = Radius;
        BillboardAsset.height = Radius;
        BillboardAsset.bottom = Radius * 0.5f;
        BillboardAsset.name = "BillboardAsset";
        EditorUtility.SetDirty(BillboardAsset);
        AssetDatabase.AddObjectToAsset(BillboardAsset, assetPath);
        return BillboardAsset;
    }

#endif
}