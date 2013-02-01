//@author: alg
//@description: Draws a Constant ParticlesGPU Sprites mesh using the DataTexture
//@tags: particles sprites
//@credits: dottore, Viktor Vicsek for Sprites Function

float4x4 tW: WORLD;
float4x4 tV: VIEW;
float4x4 tP: PROJECTION;
float4x4 tVP: VIEWPROJECTION;
float4x4 tWVP: WORLDVIEWPROJECTION;

float2 ViewportSize;

//bool EnableTile = false;
//float TileSize = 16.0;

texture TranslateScaleTex <string uiname="TranslateXYZ (XYZ), UniformScale (W)";>;
sampler TranslateScaleSamp = sampler_state
{
    Texture   = (TranslateScaleTex);          
    MipFilter = LINEAR;                    
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

texture Texture <string uiname="Texture";>;
sampler Samp = sampler_state
{
    Texture   = (Texture);          
    MipFilter = LINEAR;        
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

texture ColorTex <string uiname="Color RGBA (XYZW)";>;
sampler ColorSamp = sampler_state
{
	Texture   = (ColorTex);
	MipFilter = LINEAR;        
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

float4 Color :COLOR = 1;

struct vs2ps
{
    float4 Pos : POSITION ;
    float4 TextureTexCd : TEXCOORD1;
    float Size : PSIZE ;
	float4 Color : COLOR;
};


vs2ps VS(
    float4 Pos : POSITION ,
    float4 TransformTexCd : TEXCOORD0 ,
    float4 TextureTexCd : TEXCOORD1 )
{
    vs2ps Out = (vs2ps)0;
    
    float4 particleTransform = tex2Dlod(TranslateScaleSamp, TransformTexCd);
	Out.Color = tex2Dlod(ColorSamp, TransformTexCd);
    
    Pos.xyz  += particleTransform.xyz;
    
    Out.Pos = mul(Pos, tWVP);
	
//	if(EnableTile)
//	{
//		TextureTexCd.xy /= 16.;
//    	TextureTexCd.xy += float2((translateTileIndex.w%16)/16.,floor(translateTileIndex.w/16.)/16.);
//	}
    
	//TextureTexCd.x *=-20;
    Out.TextureTexCd = TextureTexCd;
	
	float size = min(ViewportSize.x, ViewportSize.y);
	
	float projScaleMax  = max(tP[0][0], tP[1][1]);
	
	//Detecting empty VIEW and PROJECTION matrixes (no camera)
	if(abs(tV[0][0] - tP[0][0]) < 0.001 || abs(tV[1][1] - tP[1][1]) < 0.001)
	{
		projScaleMax /=	2;
	}

	
	Out.Size = (size / 2) * (projScaleMax / Out.Pos.z) * particleTransform.w;
    
	return Out;
}

float4 SINGLE_COLOLOR_PS(vs2ps In): COLOR
{
    return tex2D(Samp, In.TextureTexCd) * Color;
}

float4 COLOLOR_FROM_TEXTURE_PS(vs2ps In): COLOR
{
    return tex2D(Samp, In.TextureTexCd) * In.Color;
}

technique Single_Color
{
	pass P0
    {
		FillMode = POINT;
		PointScaleEnable = true;
		PointSpriteEnable = true;
		
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 SINGLE_COLOLOR_PS();
	}
}

technique Color_From_Texture
{
	pass P0
    {
		FillMode = POINT;
		PointScaleEnable = true;
		PointSpriteEnable = true;
		
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 COLOLOR_FROM_TEXTURE_PS();
	}
}