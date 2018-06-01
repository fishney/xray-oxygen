#include "common.h"

struct vf
{
	float4 hpos  	: POSITION        ;
	float2 tbase  	: TEXCOORD0        ;  // base
	float2 tnorm0  	: TEXCOORD1        ;  // nm0
	float2 tnorm1  	: TEXCOORD2        ;  // nm1
	half3 M1       	: TEXCOORD3        ;
	half3 M2       	: TEXCOORD4        ;
	half3 M3       	: TEXCOORD5        ;
	half3 v2point  	: TEXCOORD6        ;
	float4 tctexgen : TEXCOORD7        ;
	half4 c0       	: COLOR0                ;
//	float fog      	: FOG                ;
};

uniform sampler2D	s_nmap;
uniform samplerCUBE	s_env0;
uniform samplerCUBE	s_env1;
uniform sampler2D	s_leaves;

#if defined(USE_SOFT_WATER) && defined(NEED_SOFT_WATER)
half3	water_intensity;
#endif	//	defined(USE_SOFT_WATER) && defined(NEED_SOFT_WATER)

half4   main( vf I )          : COLOR
{
	half4	base	= tex2D (s_base,I.tbase);
	half3	n0	= tex2D (s_nmap,I.tnorm0);
	half3	n1	= tex2D (s_nmap,I.tnorm1);
	half3	Navg	= n0 + n1 - 1;

	half3	Nw	= mul (half3x3(I.M1, I.M2, I.M3), Navg);
			Nw	= normalize (Nw);
	half3	v2point	= normalize (I.v2point);
	half3	vreflect= reflect(v2point, Nw);
			vreflect.y= vreflect.y*2-1;     // fake remapping

	half3	env0	= texCUBE (s_env0, vreflect);
	half3	env1	= texCUBE (s_env1, vreflect);
	half3	env	= lerp (env0,env1,L_ambient.w);
			env	*= env*2;

	half	fresnel	= saturate (dot(vreflect,v2point));
	half	power	= pow(fresnel,9);
	half	amount	= 0.15h+0.25h*power;	// 1=full env, 0=no env

	half3	c_reflection       = env*amount;
	half3	final              = lerp(c_reflection,base.rgb,base.a);

			final	*= I.c0*2;

        // tonemap
#ifdef        USE_VTF
//                final                *= I.c0.w        ;
#else
//                 final                 *= tex2D        (s_tonemap,I.tbase).x        ;        // any TC - OK
#endif

#ifdef	NEED_SOFT_WATER

	half	alpha	= 0.75h+0.25h*power;                        // 1=full env, 0=no env

#ifdef	USE_SOFT_WATER
	//	Igor: additional depth test
	half4 _P = 	tex2Dproj( s_position, I.tctexgen);
	half waterDepth = _P.z-I.tctexgen.z;

	//	water fog
	half  fog_exp_intens = -4.0h;
	float fog	= 1-exp(fog_exp_intens*waterDepth);
	half3 Fc  	= half3( 0.1h, 0.1h, 0.1h) * water_intensity.r;
//	half3 Fc  	= lerp(half3( 1.0h, 0.0h, 0.0h), half3( 0.0h, 1.0h, 0.0h), water_intensity.r);
//	half3 Fc  	= half3( 0.1h, 0.1h, 0.2h);
//	half3 Fc  	= half3( 1.0h, 0.0h, 0.0h);
	final 		= lerp (Fc, final, alpha);

	alpha 		= min(alpha, saturate(waterDepth));

	alpha 		= max (fog, alpha);

	//	Leaves
	half4	leaves	= tex2D(s_leaves, I.tbase);
			leaves.rgb *= water_intensity.r;
	half	calc_cos = -dot(float3(I.M1.z, I.M2.z, I.M3.z),  normalize(v2point));
	half	calc_depth = saturate(waterDepth*calc_cos);
	half	fLeavesFactor = smoothstep(0.025, 0.05, calc_depth );
			fLeavesFactor *= smoothstep(0.1, 0.075, calc_depth );
	final		= lerp(final, leaves, leaves.a*fLeavesFactor);
	alpha		= lerp(alpha, leaves.a, leaves.a*fLeavesFactor);

#endif	//	USE_SOFT_WATER
	return  half4   (final, alpha*I.c0.a*I.c0.a )                ;
#else	//	NEED_SOFT_WATER
	return  half4   (final, 1 )                ;
#endif	//	NEED_SOFT_WATER
}
