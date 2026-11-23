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
void vertex() { local_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float clouds = noise3(local_point*1.8);
    float grit = noise3(local_point*32.0);
    float drip = noise3(local_point*vec3(7.0,0.6,8.0));
    ALBEDO = stain.rgb * (0.49+clouds*0.38+grit*0.14+drip*0.20);
    ROUGHNESS = 0.93;
}
