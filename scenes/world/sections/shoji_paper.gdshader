shader_type spatial;
render_mode cull_disabled;
varying vec3 timber_pos;
varying vec3 timber_normal;
varying float room;
void vertex(){
	timber_pos=VERTEX;
	timber_normal=NORMAL;
	room=fract(sin(dot(MODEL_MATRIX[3].xyz,vec3(.141,.213,.196)))*245.716);
}
void fragment(){
	float along=abs(timber_normal.z)>.5?timber_pos.x:timber_pos.z;
	float u=fract((along+.3)*.57);
	float y=timber_pos.y;
	float gradient=clamp(1.-abs(y-2.5)*.31,0.,1.);
	float fibre=.018*sin(y*88.+sin(along*23.))+.012*sin(along*71.+y*11.);
	float glow=clamp(gradient*.7+.12+room*.18+fibre,0.,1.);
	float branch=abs(y-(1.55+.29*sin(along*1.6)+.12*sin(along*4.)));
	float foliage=(1.-smoothstep(.04,.23,branch))*(.4+.6*smoothstep(-.2,.9,sin(along*17.+y*6.)));
	vec3 paper=mix(vec3(.31,.105,.045),vec3(.99,.63,.29),glow)*(1.-foliage*.36);
	ALBEDO=paper*.68;
	EMISSION=paper*(.34+.37*glow);
	ROUGHNESS=.96;
}
