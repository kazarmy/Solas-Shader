float texture2DShadow(sampler2D shadowtex, vec3 shadowPos) {
    float shadow = texture2D(shadowtex, shadowPos.xy).r;

    return clamp((shadow - shadowPos.z) * 65536.0, 0.0, 1.0);
}

void computeVolumetricLight(inout vec3 vl, in vec3 translucent, in float dither) {
	//Depths
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;

	//Positions
	vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
	vec3 viewPos = ToView(vec3(texCoord.xy, z0));
	vec3 nViewPos = normalize(viewPos);

	//Total Visibility
	float VoU = clamp(dot(nViewPos, upVec), 0.0, 1.0);
		  VoU = 1.0 - pow(VoU, 1.5);
		  VoU = mix(VoU, 1.0, timeBrightness * (1.0 - eBS * eBS));
	float VoL = clamp(dot(nViewPos, lightVec), 0.0, 1.0);

	float visibility = 0.01 * pow4(VoU) * mix(exp(VoL * 1.5) * 0.5 + 0.25, VoL * 2.0, timeBrightness) * int(z0 > 0.56);

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

	if (visibility > 0.0) {
		vec3 shadowCol = vec3(0.0);
		vec3 vlColor = mix(pow(lightCol, vec3(0.75)), lightCol * normalize(skyColor + 0.000001), timeBrightness);

		//Linear Depths
		float linearDepth0 = getLinearDepth(z0);
		float linearDepth1 = getLinearDepth(z1);

		//Variables
		float fovFactor = gbufferProjection[1][1] / 1.37;
		float x = abs(texCoord.x - 0.5);
			  x = 1.0 - x * x;
			  x = pow(x, max(3.0 - fovFactor, 0.0));
		float maxDist = 192.0;
		float distanceFactor = 2.0 + eBS * eBS * 5.0;
			  distanceFactor *= clamp(far, 128.0, 512.0) / maxDist;
			  distanceFactor *= x;
			  maxDist *= x;

		float lViewPos = length(viewPos);

		//Ray Marching
		for (int i = 0; i < VL_SAMPLES; i++) {
			float currentDist = (i + dither) * distanceFactor;

			if (currentDist >= maxDist) break;

			if (linearDepth1 < currentDist || (linearDepth0 < currentDist && translucent.rgb == vec3(0.0))) {
				break;
			}

			vec3 worldPos = ToWorld(ToView(vec3(texCoord, getLogarithmicDepth(currentDist))));

			//Shadows
			vec3 shadowPos = ToShadow(worldPos);

			if (length(shadowPos * 2.0 - 1.0) < 1.0) {
				float shadow0 = texture2DShadow(shadowtex0, shadowPos.xyz);
				float shadow1 = 0.0;

				#ifdef SHADOW_COLOR
				if (shadow0 < 1.0) {
					shadow1 = texture2DShadow(shadowtex1, shadowPos.xyz);
					if (shadow1 > 0.0) {
						shadowCol = texture2D(shadowcolor0, shadowPos.xy).rgb;
					}
				}
				#endif

				#ifdef VL_CLOUDY_NOISE
				float noise = 1.0;

				if (isEyeInWater == 0) {
					vec3 npos = worldPos + cameraPosition + vec3(frameTimeCounter, 0.0, 0.0);
					float n3da = texture2D(noisetex, npos.xz * 0.0005 + floor(npos.y * 0.1) * 0.1).r;
					float n3db = texture2D(noisetex, npos.xz * 0.0005 + floor(npos.y * 0.1 + 1.0) * 0.1).r;
					noise = sin(mix(n3da, n3db, fract(npos.y * 0.1)) * 16.0) * 0.5 + 0.5;
				}

				shadow0 *= noise;
				#endif

				vec3 shadow = clamp(shadow1 * pow2(shadowCol) * 6.0 + shadow0 * vlColor * float(isEyeInWater == 0), 0.0, 8.0);

				//Translucency Blending
				if (linearDepth0 < currentDist) {
					shadow *= translucent.rgb;
				}

				vl += shadow;
			} else {
				vl += 1.0;
			}
		}

		vl *= visibility;
		if (isEyeInWater == 1.0) vl *= mix(waterColorSqrt, waterColorSqrt * weatherCol, wetness) * (4.0 + sunVisibility * 16.0);
	}
}