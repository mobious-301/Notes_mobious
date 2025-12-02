#ifndef UNIVERSAL_FULLSCREEN_INCLUDED
#define UNIVERSAL_FULLSCREEN_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
// #define _USE_DRAW_PROCEDURAL 1
#if _USE_DRAW_PROCEDURAL
void GetProceduralQuad(in uint vertexID, out float4 positionCS, out float2 uv)
{
    positionCS = GetQuadVertexPosition(vertexID);
    positionCS.xy = positionCS.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);
    uv = GetQuadTexCoord(vertexID) * _ScaleBias.xy + _ScaleBias.zw;
}
#endif
float4 _vertexPos[10];
float4 _vertexPosSet[10];
float _isvertexPos;
struct Attributes
{
    uint vertexID     : SV_VertexID;
#if _USE_DRAW_PROCEDURAL
    
#else
    float4 positionOS : POSITION;
    float2 uv         : TEXCOORD0;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv         : TEXCOORD0;
    UNITY_VERTEX_OUTPUT_STEREO
};
uint getIDgroup(uint id)
{
    return id/4;
}

Varyings FullscreenVert(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

#if !_isvertexPos


_ScaleBias =float4(1,1,0,0);
// _ScaleBias.xy*=2;
    output.positionCS = GetQuadVertexPosition(input.vertexID);

    // output.positionCS.xy = output.positionCS.xy * float2(2.0f, 2.0f) + float2(-1.0f, -1.0f);
    output.uv = (GetQuadTexCoord(input.vertexID) * _ScaleBias.xy + _ScaleBias.zw)%2;

    
    _vertexPos[0]=float4(0,0,0,0);
    _vertexPos[1]=float4(1,1,1,1);
    _vertexPos[2]=float4(2,2,2,2);
    _vertexPos[3]=float4(3,3,3,3);
    _vertexPos[4]=float4(4,4,4,4);
    _vertexPos[5]=float4(5,5,5,5);
    _vertexPos[6]=float4(6,6,6,6);
    _vertexPos[7]=float4(7,7,7,7);
    _vertexPos[8]=float4(8,8,8,8);
    _vertexPos[9]=float4(9,9,9,9);

    // _vertexPosSet[0]=float4(0.66666666,1,0.33333333,0);
    // _vertexPosSet[1]=float4(0.33333333,0.5,0,0.5);
    // _vertexPosSet[2]=float4(0.16666666,0.25,0,0.25);
    // _vertexPosSet[2]=float4(0.08333333,0.125,0,0.125);

    output.positionCS.x -= 2*_vertexPos[getIDgroup(input.vertexID)];
    output.positionCS.xy = output.positionCS.xy*0.8 +0.1;
    output.positionCS.xy = output.positionCS.xy*_vertexPosSet[getIDgroup(input.vertexID)].xy+_vertexPosSet[getIDgroup(input.vertexID)].zw;

    output.positionCS.x *= 1+_vertexPos[getIDgroup(input.vertexID)]*_vertexPos[getIDgroup(input.vertexID)]/5;
    
    
    // output.positionCS.x =output.positionCS.x*2/3;
    // output.positionCS.x =output.positionCS.x*1/2;
    output.positionCS.xy = output.positionCS.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f); //convert to -1..1

#else
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    output.uv = input.uv;
#endif

// output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
// output.positionCS.xy *=0.1;  //原始坐标 
// output.uv = GetFullScreenTriangleTexCoord(input.vertexID);

// positionCS 是屏幕中心空间坐标   01 坐标 *2-1 得此坐标
// output.uv*=0.001;
    return output;
}

Varyings Vert(Attributes input)
{
    return FullscreenVert(input);
}

#endif
