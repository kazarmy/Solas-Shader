//Settings//
#include "/lib/common.glsl"

#define GBUFFERS_ENTITIES_GLOWING

#ifdef FSH

//Varyings//
varying vec2 texCoord;
varying vec4 color;

//Uniforms//
uniform sampler2D texture;

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * color;

    /* DRAWBUFFERS:02 */
    gl_FragData[0] = albedo;
	gl_FragData[1].b = 1.0;
}

#endif

/////////////////////////////////////////////////////////////////////////////////////

#ifdef VSH

//Varyings//
varying vec2 texCoord;
varying vec4 color;

void main() {
	//Coords
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	//Color & Position
	color = gl_Color;

	gl_Position = ftransform();
}

#endif