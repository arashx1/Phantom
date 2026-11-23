extends StaticBody3D

const CENTER := Vector3(0, 0, -28)
const RADII := Vector3(222, 174, 222)
const SEGMENTS := 48
const ROWS := 28
var faces := PackedVector3Array()
var surface := SurfaceTool.new()

func point(row: int, column: int, depth: float) -> Vector3:
	var latitude := PI * (float(row) / ROWS - 0.5)
	var longitude := TAU * (column % SEGMENTS) / SEGMENTS
	return CENTER + (RADII - Vector3.ONE * depth) * Vector3(cos(latitude)*cos(longitude), sin(latitude), cos(latitude)*sin(longitude))

func triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b-a).cross(c-a)
	if normal.length_squared() < 0.00001:
		return
	normal = normal.normalized()
	if normal.dot(CENTER-a) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for vertex in [a,c,b]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)
		faces.append(vertex)

func panel(row: int, col: int, depth: float) -> void:
	var a := point(row,col,depth)
	var b := point(row,col+1,depth)
	var c := point(row+1,col+1,depth)
	var d := point(row+1,col,depth)
	triangle(a,b,c)
	triangle(a,c,d)

func _ready() -> void:
	add_to_group("return_gallery")
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	render_mode cull_disabled;
	varying vec3 pos;
	void vertex(){pos=VERTEX;}
	void fragment(){
		vec3 n=abs(normalize(pos-vec3(0.,0.,-28.)));
		vec2 uv=n.y>max(n.x,n.z)?pos.xz:(n.x>n.z?pos.zy:pos.xy);
		vec2 bay=fract(uv/vec2(8.,5.));
		float beam=step(bay.x,.05)+step(bay.y,.12);
		float window=step(.21,bay.x)*step(bay.x,.77)*step(.31,bay.y)*step(bay.y,.73);
		window*=step(.08,fract(bay.x*12.))*step(.1,fract(bay.y*8.));
		ALBEDO=mix(vec3(.22,.13,.084),vec3(.067,.038,.025),min(beam,1.));
		EMISSION=vec3(.65,.25,.065)*window;
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.set_material(material)
	for row in ROWS:
		for col in SEGMENTS:
			panel(row,col,0)
			# Terraced roofs below the castle leave gaps for deeper falls.
			if row < 6 and (col/3+row)%3 != 0:
				panel(row,col,45)
			if row < 4 and (col/4+row)%4 != 0:
				panel(row,col,80)
	var visual := MeshInstance3D.new()
	visual.mesh = surface.commit()
	add_child(visual)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var solid := CollisionShape3D.new()
	solid.shape = shape
	add_child(solid)
