shader_type sky;

// Three depths of stepped rock spires surround the suspended district.
float hash_cell(float n) { return fract(sin(n * 127.1) * 4375.5); }

float ridge(float azimuth, float elevation, float count, float seed) {
    float u = azimuth * count;
    float cell = mod(floor(u),count);
    float local = abs(fract(u)-0.5);
    float height = -0.16 + 0.62 * pow(hash_cell(cell+seed),1.7);
    height -= floor(local*8.0)*0.037 + local*local*0.44;
    return 1.0-smoothstep(height-0.007,height+0.007,elevation);
}

void sky() {
    float azimuth = atan(EYEDIR.z,EYEDIR.x)/TAU+0.5;
    float elevation = EYEDIR.y;
    vec3 haze = mix(vec3(0.055,0.16,0.24),vec3(0.17,0.37,0.49),exp(-4.0*abs(elevation-0.12)));
    haze = mix(haze,vec3(0.082,0.21,0.30),ridge(azimuth,elevation,107.0,9.0)*0.52);
    haze = mix(haze,vec3(0.047,0.143,0.22),ridge(azimuth,elevation+0.11,72.0,31.0)*0.68);
    haze = mix(haze,vec3(0.022,0.074,0.125),ridge(azimuth,elevation+0.22,48.0,67.0)*0.78);
    COLOR = haze;
}
