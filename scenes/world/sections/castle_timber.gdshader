shader_type spatial;
uniform vec4 stain : source_color;
varying vec3 local_point;
float hash3(vec3 v) {
    v = fract(v * 0.1031);
    v += dot(v, v.yzx + 33.33);
    return fract((v.x + v.y) * v.z);
}
float noise3(vec3 p) {
    vec3 cell = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(cell),hash3(cell+vec3(1,0,0)),f.x),mix(hash3(cell+vec3(0,1,0)),hash3(cell+vec3(1,1,0)),f.x),f.y),
               mix(mix(hash3(cell+vec3(0,0,1)),hash3(cell+vec3(1,0,1)),f.x),mix(hash3(cell+vec3(0,1,1)),hash3(cell+vec3(1)),f.x),f.y),f.z);
}
void vertex() { local_point = VERTEX + fract(MODEL_MATRIX[3].xyz*0.37)*7.0; }
uniform vec3 grain_scale = vec3(0.65,15.0,19.0);
void fragment() {
    vec3 p = local_point * grain_scale;
    float bend = noise3(local_point * 1.6);
    float fibre = noise3(p*1.9 + bend*3.0);
    float rings = sin((p.y + p.z + p.x)*1.4 + bend*7.0);
    float streak = smoothstep(0.4,0.95,rings)*noise3(p*0.48);
    float wear = noise3(local_point*3.6);
    ALBEDO = stain.rgb*(0.71 + fibre*0.32 + wear*0.19 - streak*0.13);
    ROUGHNESS = clamp(0.32 + fibre*0.19 + wear*0.12,0.0,1.0);
    SPECULAR = 0.47;
}
