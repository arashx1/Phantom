shader_type spatial;
render_mode unshaded;
void fragment(){
    vec2 q = abs(UV-0.5)*2.0;
    float glow = clamp(1.0-(q.x*q.x*0.42+q.y*q.y*0.38),0.0,1.0);
    ALBEDO = mix(vec3(0.72,0.25,0.055),vec3(1.0,0.90,0.61),glow);
}
