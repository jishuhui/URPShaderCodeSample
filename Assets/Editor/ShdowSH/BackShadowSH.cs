using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class BackShadowSH : MonoBehaviour
{
    [MenuItem("Tools/烘焙球谐阴影")]
    public static void Bake()
    {
        int shadowMapResolution = 2048;
        GameObject go = Selection.activeGameObject;
        int sampleCount = 512;
        MeshRenderer[] renderers = go.GetComponentsInChildren<MeshRenderer>(true);
        CommandBuffer cmd = new CommandBuffer();
        Vector3[] randomDirs = new Vector3[sampleCount];
        float[] shBasis = new float[9];
        float pdf = 1.0f / (4f * Mathf.PI);
        Bounds bv = new Bounds(Vector3.zero, Vector3.zero);
        
        ComputeShader computeShader =
            AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/Editor/ShdowSH/BakeDirectionalShadow.compute");
        for (int i = 0; i < renderers.Length; i++)
        {
            MeshRenderer renderer = renderers[i];
            if (renderer == null)
                continue;
            if (bv.size.x == 0f)
                bv = renderer.bounds;
            else
                bv.Encapsulate(renderer.bounds);
        }

        float r = Vector3.Distance(bv.max, bv.center);
        Vector4 boudingShpere = bv.center;
        boudingShpere.w = r;
        Matrix4x4 projectMatrix = Matrix4x4.Ortho(-r, r, -r, r, 0, -2f * r);
        Matrix4x4 invZProject = projectMatrix;
        if (SystemInfo.usesReversedZBuffer)
        {
            invZProject.m20 = -projectMatrix.m20;
            invZProject.m21 = -projectMatrix.m21;
            invZProject.m22 = -projectMatrix.m22;
            invZProject.m23 = -projectMatrix.m23;
        }

        RenderTexture shadowMap =
            new RenderTexture(shadowMapResolution, shadowMapResolution, 32, RenderTextureFormat.Depth);
        for (int z = 0; z < sampleCount; z++)
        {
            float haltonSequence0 = GetHaltonSequence(z, 2);
            float haltonSequence1 = GetHaltonSequence(z, 3);
            randomDirs[z] = UniformSampleSphere(haltonSequence0, haltonSequence1);
        }

        for (int i = 0; i < renderers.Length; i++)
        {
            MeshRenderer renderer = renderers[i];
            if (renderer == null)
                continue;

            int depthPass = renderer.sharedMaterial.FindPass("DepthOnly");
            if (depthPass >= 0)
            {
                if (renderer.additionalVertexStreams)
                {
                    Object.DestroyImmediate(renderer.additionalVertexStreams);
                    renderer.additionalVertexStreams = null;
                }

                MeshFilter mf = renderer.GetComponent<MeshFilter>();
                Mesh newMesh = Object.Instantiate(mf.sharedMesh);
                int bufferSize = newMesh.vertices.Length;
                ComputeBuffer verticeBuffer = new ComputeBuffer(bufferSize, sizeof(float) * 3);
                verticeBuffer.SetData(newMesh.vertices);
                ComputeBuffer shadowBuffer = new ComputeBuffer(bufferSize, sizeof(float));
                float[] shadowArray = new float[bufferSize];
                Vector4[] shCoefficients0123 = new Vector4[bufferSize];
                Vector4[] shCoefficients4567 = new Vector4[bufferSize];
                Vector4[] shCoefficients9 = new Vector4[bufferSize];
                
                for (int z = 0; z < sampleCount; z++)
                {
                    Vector3 dir = randomDirs[z];
                    Vector3 cameraPos = bv.center + dir * r;
                    Quaternion rotation = Quaternion.LookRotation(-dir);
                    Matrix4x4 light2World = Matrix4x4.TRS(cameraPos, rotation, Vector3.one);
                    Matrix4x4 world2Light = light2World.inverse;
                    Matrix4x4 model2Light = invZProject * world2Light * renderer.localToWorldMatrix;
                    
                    cmd.Clear();
                    cmd.SetViewport(new Rect(0f, 0f, shadowMapResolution, shadowMapResolution));
                    cmd.SetViewProjectionMatrices(world2Light, projectMatrix);
                    cmd.SetRenderTarget(shadowMap);
                    cmd.ClearRenderTarget(true, false, Color.clear);
                    cmd.SetGlobalDepthBias(2f, 2f);
                    cmd.DrawRenderer(renderer, renderer.sharedMaterial, 0, depthPass);
                    cmd.SetComputeBufferParam(computeShader, 0, "_VextriceBuffer", verticeBuffer);
                    cmd.SetComputeBufferParam(computeShader, 0, "_ShadowBuffer", shadowBuffer);
                    cmd.SetComputeMatrixParam(computeShader, "_Model2Light", model2Light);
                    cmd.SetComputeTextureParam(computeShader, 0, "_ShadowMap", shadowMap);
                    cmd.SetComputeIntParam(computeShader, "_BufferSize", bufferSize);
                    cmd.DispatchCompute(computeShader, 0, Mathf.CeilToInt(bufferSize / 64f), 1, 1);
                    Graphics.ExecuteCommandBuffer(cmd);
                    shadowBuffer.GetData(shadowArray);
                    dir = renderer.transform.worldToLocalMatrix.MultiplyVector(dir);
                    HarmonicsBasis(dir, shBasis);
                    
                    for (int j = 0; j < bufferSize; j++)
                    {
                        shCoefficients0123[j][0] += shadowArray[j] * shBasis[0];
                        shCoefficients0123[j][1] += shadowArray[j] * shBasis[1];
                        shCoefficients0123[j][2] += shadowArray[j] * shBasis[2];
                        shCoefficients0123[j][3] += shadowArray[j] * shBasis[3];
                        shCoefficients4567[j][0] += shadowArray[j] * shBasis[4];
                        shCoefficients4567[j][1] += shadowArray[j] * shBasis[5];
                        shCoefficients4567[j][2] += shadowArray[j] * shBasis[6];
                        shCoefficients4567[j][3] += shadowArray[j] * shBasis[7];
                        shCoefficients9[j][0] += shadowArray[j] * shBasis[8];
                    }
                }

                float weight = 1f / (pdf * sampleCount);
                for (int j = 0; j < bufferSize; j++)
                {
                    shCoefficients0123[j][0] = shCoefficients0123[j][0] * weight;
                    shCoefficients0123[j][1] = shCoefficients0123[j][1] * weight;
                    shCoefficients0123[j][2] = shCoefficients0123[j][2] * weight;
                    shCoefficients0123[j][3] = shCoefficients0123[j][3] * weight;
                    shCoefficients4567[j][0] = shCoefficients4567[j][0] * weight;
                    shCoefficients4567[j][1] = shCoefficients4567[j][1] * weight;
                    shCoefficients4567[j][2] = shCoefficients4567[j][2] * weight;
                    shCoefficients4567[j][3] = shCoefficients4567[j][3] * weight;
                    shCoefficients9[j][0] = shCoefficients9[j][0] * weight;
                }
                //设置球谐信息到模型
                newMesh.SetUVs(1, shCoefficients0123);
                newMesh.SetUVs(2, shCoefficients4567);
                newMesh.SetUVs(3, shCoefficients9);
                
                //
                Vector3[] vertices = newMesh.vertices;
                //创建颜色数组
                Color[] vcolors = new Color[vertices.Length];
                for (int j = 0; j < vertices.Length; j++)
                {
                    vcolors[j] = Color.Lerp(Color.red, Color.green, vertices[j].y);
                }

                newMesh.colors = vcolors;
                renderer.additionalVertexStreams = newMesh;
            }
        }

        cmd.Release();
        shadowMap.Release();
        GameObject.DestroyImmediate(shadowMap);
    }
    
    public static Vector3 UniformSampleSphere(float e0, float e1)
    {
        float Phi = 2f * Mathf.PI * e0;
        float CosTheta = 1f - 2f * e1;
        float SinTheta = Mathf.Sqrt(1 - CosTheta * CosTheta);
        Vector3 dir;
        dir.x = SinTheta * Mathf.Cos(Phi);
        dir.y = SinTheta * Mathf.Sin(Phi);
        dir.z = CosTheta;
        return dir;
    }

    public static float GetHaltonSequence(int index, int radix)
    {
        float result = 0f;
        float fraction = 1f / radix;

        while (index > 0)
        {
            result += (index % radix) * fraction;

            index /= radix;
            fraction /= radix;
        }

        return result;
    }
    
    const float sh0_0 = 0.28209479f;
    const float sh1_1 = 0.48860251f;
    const float sh2_n2 = 1.09254843f;
    const float sh2_n1 = 1.09254843f;
    const float sh2_0 = 0.31539157f;
    const float sh2_1 = 1.09254843f;
    const float sh2_2 = 0.54627421f;
    static void HarmonicsBasis(Vector3 pos, float[] sh9)
    {
        Vector3 normal = pos;
        float x = normal.x;
        float y = normal.y;
        float z = normal.z;
        sh9[0] = sh0_0;
        sh9[1] = sh1_1 * y;
        sh9[2] = sh1_1 * z;
        sh9[3] = sh1_1 * x;
        sh9[4] = sh2_n2 * x * y;
        sh9[5] = sh2_n1 * z * y;
        sh9[6] = sh2_0 * (2 * z * z - x * x - y * y);
        sh9[7] = sh2_1 * z * x;
        sh9[8] = sh2_2 * (x * x - y * y);
    }    
    
}