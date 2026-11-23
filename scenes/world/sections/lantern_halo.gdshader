shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
void vertex(){
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
    float radius=length(UV-0.5)*2.0;
    float halo=exp(-6.0*radius*radius)*pow(max(0.0,1.0-radius),2.0);
    ALBEDO=vec3(1.0,0.38,0.08);
    ALPHA=halo*0.38;
}
