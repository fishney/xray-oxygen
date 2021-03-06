#include "common.h"

//Texture2D s_base;
//sampler smp_base;

//////////////////////////////////////////////////////////////////////////////////////////
// Pixel

float4 main ( p_TL I ) : SV_Target
{
	float4 res = s_base.Sample( smp_rtlinear, I.Tex0 );
	res.rgb		= lerp( res.rgb, I.Color.rgb, I.Color.a);
	res.a		*= I.Color.a;

	return res;
}
