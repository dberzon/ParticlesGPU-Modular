//@author: woei
//@help: creates a bezierspline ribbon along 3d coordinates, calculated on the GPU
//@tags: curve, spline, bezier, cubic bezier
// PARAMETERS-------------------------------------------------------------------
//transforms
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tWV: WORLDVIEW;
float4x4 tWVP: WORLDVIEWPROJECTION;
#include <effects\PhongDirectional.fxh>

//texture
texture Tex <string uiname="Texture";>;
sampler Samp = sampler_state
{
    Texture   = (Tex);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

float4x4 tTex: TEXTUREMATRIX <string uiname="Texture Transform";>;
float4x4 tColor <string uiname="Color Transform";>;
float alpha = 1.;

int Size;
texture pTex <string uiname="Position Texture";>;
sampler pSamp = sampler_state
{
    Texture   = (pTex);
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
	AddressU = clamp;
	ADDRESSV = wrap;
};
texture cTex <string uiname="Control Texture";>;
sampler cSamp = sampler_state
{
    Texture   = (cTex);
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
	AddressU = clamp;
	ADDRESSV = wrap;
};

texture colorTex <string uiname="Color Texture";>;
sampler colorSamp = sampler_state
{
    Texture   = (colorTex);
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
	AddressU = clamp;
	ADDRESSV = wrap;
};

texture endColorTex <string uiname="End Color Texture";>;
sampler endColorSamp = sampler_state
{
    Texture   = (endColorTex);
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
	AddressU = clamp;
	ADDRESSV = wrap;
};

struct vs2ps
{
    float4 PosWVP: POSITION;
    float4 TexCd : TEXCOORD0;
	float4 PosCd : TEXCOORD1;
    float3 LightDirV: TEXCOORD2;
    float3 ViewDirV: TEXCOORD3;
    float3 Tang : TEXCOORD4;
    float3 Bi : TEXCOORD5;
	float4 Depth : TEXCOORD6;
	float4 Color : COLOR0;
	float4 EndColor : COLOR1;
	float U : TEXCOORD7;
};
 //---- Bezier-Spline -----------------------------------------------------------
bool rel <string uiname="Relative Tangent";> = true;
struct pota { float4 Pos; float4 Tang; };
pota BezierSpline(float4 p1, float4 t1, float4 p2, float4 t2, float range) {
	pota Out = (pota)0;
	
	float mu = frac(range);
		
    float4 c1 = t1+(p1*rel);
    float4 c2 = lerp(t2,-t2,rel)+(p2*rel);
  
    float mum1 = 1 - mu;
    float mum13 = mum1 * mum1 * mum1;
    float mu3 = mu * mu * mu;

	Out.Pos = mum13*p1 + 3*mu*mum1*mum1*c1 + 3*mu*mu*mum1*c2 + mu3*p2;
	Out.Tang = 3*(c1-p1)*mum1*mum1+3*(c2-c1)*2*mu*mum1+3*(p2-c2)*mu*mu;
	return Out;
}
// VERTEXSHADER-----------------------------------------------------------------
vs2ps VS_Spline(float4 PosO: POSITION, float3 NormO: NORMAL, float4 TexCd : TEXCOORD0, float4 PosCd : TEXCOORD1)
{
    vs2ps Out = (vs2ps)0;
    Out.LightDirV = normalize(-mul(lDir, tV));
	
	float cSize = (Size-1)*0.9999;
	float4 cCd = PosCd;	
	cCd.x = floor(cCd.x*(cSize))/cSize;
	
    float4 p1 = tex2Dlod(pSamp, cCd);
	float4 t1 = tex2Dlod(cSamp, cCd);
	
	float u = PosCd.x*cSize;
	Out.U = u;
	
	float4 p2 = tex2Dlod(pSamp, float4(cCd.x+(1./cSize),cCd.yzw));
	float4 t2 = tex2Dlod(cSamp, float4(cCd.x+(1./cSize),cCd.yzw));
	
	float4 color = tex2Dlod(colorSamp, cCd);
	Out.Color = color;
	
	float4 endColor = tex2Dlod(endColorSamp, cCd);
	Out.EndColor = endColor;
    
	pota curve = BezierSpline(p1,float4(t1.xyz,0),p2,float4(t2.xyz,0),PosCd.x*cSize);
    float4 spline = curve.Pos;

	float3 rVec = 0;
	sincos(t1.w,rVec.y,rVec.z);
	float3x3 tR = float3x3(float3(1,0,0), float3(0,rVec.z,-rVec.y), rVec);

	float3 tang = normalize(curve.Tang);
	float3 bitang= normalize(cross(tang,rVec));
	float3x3 tBN = float3x3((float3)0,bitang,cross(tang,bitang));
	PosO.xyz=spline.xyz+(mul(PosO.xyz,tBN)*spline.w);
	//PosO.xyz=spline.xyz + PosO.xyz * spline.w; - simplified version for CPU implementation. Also can creaate lines, that become thinner at the end.
	
	bitang = normalize(cross(tang,mul(NormO,tR)));
	
    Out.PosWVP  = mul(PosO, tWVP);
    Out.TexCd = mul(TexCd, tTex);

    //normal in view space
    Out.ViewDirV = -normalize(mul(PosO, tWV));
    Out.Tang = tang;
    Out.Bi = bitang;
	Out.Depth = mul(PosO, tWVP);
    return Out;
}
// PIXELSHADER------------------------------------------------------------------
float4 PS(vs2ps In): COLOR
{
	float4 col = tex2D(Samp, In.TexCd);
    float3 n = normalize(cross(In.Tang,In.Bi));    
    col.rgb *= PhongDirectional(n, In.ViewDirV, In.LightDirV);;
    col.a*=alpha;
    return mul(col, tColor);
}

float4 PS_Depth(vs2ps In): COLOR
{
    float4 col = In.Depth.z;
    col.a =1;
    return col;
}

float4 PS_COLOR_FROM_TEXTURE(vs2ps In): COLOR
{
	float4 col = In.Color;
    return col;
}

float4 PS_COLOR_FROM_TWO_TEXTURES(vs2ps In): COLOR
{	
    return lerp(In.Color, In.EndColor, In.U);
}

// TECHNIQUES-------------------------------------------------------------------
technique BezierSpline_PhongDirectional
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS();
    }
}
technique BezierSpline_Depth
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS_Depth();
    }
}

technique Color_From_Texture
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS_COLOR_FROM_TEXTURE();
    }
}

technique Color_From_Two_Textures
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Spline();
        PixelShader = compile ps_3_0 PS_COLOR_FROM_TWO_TEXTURES();
    }
}