#ifndef _QUARK_OUTLINE_
#define _QUARK_OUTLINE_

#include "Common.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _CameraColorTexture_TexelSize;
    float _OutlineThickness;
    float _DepthSensitivity;
    float _NormalsSensitivity;
    float _ColorSensitivity;
    float4 _OutlineColor;
CBUFFER_END

TEXTURE2D(_CameraColorTexture); SAMPLER(sampler_CameraColorTexture);

TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

TEXTURE2D(_CameraDepthNormalsTexture); SAMPLER(sampler_CameraDepthNormalsTexture);

struct outline_appdata
{
    half4 positionOS : POSITION;
    half2 uv : TEXCOORD0;
};

struct outline_v2f
{
    half4 vertex : SV_POSITION;
    half2 uv : TEXCOORD0;
};

void Outline_float(float2 UV, float OutlineThickness, float DepthSensitivity, float NormalsSensitivity, float ColorSensitivity, float4 OutlineColor, out float4 Out)
{
    float halfScaleFloor = floor(OutlineThickness * 0.5);
    float halfScaleCeil = ceil(OutlineThickness * 0.5);
    float2 Texel = (1.0) / float2(_CameraColorTexture_TexelSize.z, _CameraColorTexture_TexelSize.w);

    float2 uvSamples[4];
    float depthSamples[4];
    float3 normalSamples[4], colorSamples[4];

    uvSamples[0] = UV - float2(Texel.x, Texel.y) * halfScaleFloor;
    uvSamples[1] = UV + float2(Texel.x, Texel.y) * halfScaleCeil;
    uvSamples[2] = UV + float2(Texel.x * halfScaleCeil, -Texel.y * halfScaleFloor);
    uvSamples[3] = UV + float2(-Texel.x * halfScaleFloor, Texel.y * halfScaleCeil);

    for (int i = 0; i < 4; i++)
    {
        depthSamples[i] = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[i]).r;
        normalSamples[i] = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uvSamples[i]));
        colorSamples[i] = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[i]);
    }

    // Depth
    float depthFiniteDifference0 = depthSamples[1] - depthSamples[0];
    float depthFiniteDifference1 = depthSamples[3] - depthSamples[2];
    float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
    float depthThreshold = (1 / DepthSensitivity) * depthSamples[0];
    edgeDepth = edgeDepth > depthThreshold ? 1 : 0;

    // Normals
    float3 normalFiniteDifference0 = normalSamples[1] - normalSamples[0];
    float3 normalFiniteDifference1 = normalSamples[3] - normalSamples[2];
    float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
    edgeNormal = edgeNormal > (1 / NormalsSensitivity) ? 1 : 0;

    // Color
    float3 colorFiniteDifference0 = colorSamples[1] - colorSamples[0];
    float3 colorFiniteDifference1 = colorSamples[3] - colorSamples[2];
    float edgeColor = sqrt(dot(colorFiniteDifference0, colorFiniteDifference0) + dot(colorFiniteDifference1, colorFiniteDifference1));
    edgeColor = edgeColor > (1 / ColorSensitivity) ? 1 : 0;

    float edge = max(edgeDepth, max(edgeNormal, edgeColor));

    float4 original = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[0]);
    Out = ((1 - edge) * original) + (edge * lerp(original, OutlineColor, OutlineColor.a));
}

outline_v2f OutlineVert(outline_appdata v)
{
    outline_v2f o = (outline_v2f) 0;
    o.vertex = TransformObjectToHClip(v.positionOS.xyz);
    o.uv = v.uv;
    return o;
}

half4 OutlineFrag(outline_v2f i) : SV_Target
{
    float4 color = float4(0, 0, 0, 0);
    
    Outline_float(i.uv, _OutlineThickness, _DepthSensitivity, _NormalsSensitivity, _ColorSensitivity, _OutlineColor, color);
    
    return color;
}

#endif