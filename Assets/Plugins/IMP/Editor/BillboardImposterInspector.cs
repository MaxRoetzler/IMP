using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(BillboardImposter))]
public class BillboardImposterInspector : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        var obj = serializedObject.targetObject as BillboardImposter;
        if (obj == null)
            return;
        
        if (GUILayout.Button("Spawn Single"))
        {
            //create object in scene setup
            obj.Spawn(Vector3.zero);
        }
        
        if (GUILayout.Button("Spawn 10x10 Grid"))
        {
            const int len = 10;
            var root = new GameObject(obj.name);
            root.transform.position = Vector3.zero;
            for (var z = 0; z < len; z++)
            {
                for (var y = 0; y < 1; y++)
                {
                    for (var x = 0; x < len; x++)
                    {
                        var pos = new Vector3(x/(len-1f), 0.5f, z/(len-1f));
                        pos = (pos * 2f) - Vector3.one;
                        pos *= obj.Radius*len;
                        var c = obj.Spawn(pos);
                        c.transform.rotation = Quaternion.AngleAxis(Random.Range(0f,360f),Vector3.up);
                        //c.transform.localScale = Vector3.one * Random.Range(0.8f, 1.2f);
                        c.transform.SetParent(root.transform);
                        c.transform.localPosition = pos;
                    }
                }
            }
        }
    }


}
