@tool
extends MeshInstance3D

# A split travelling cape, fitted around the shoulders and backpack.
func _ready() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 0.90
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(cloth)
	var heights := [1.40,1.31,1.11,1.085,1.045]
	var widths := [0.27,0.50,0.58,0.585,0.59]
	var depths := [0.27,0.35,0.40,0.405,0.41]
	for row in heights.size()-1:
		for col in 32:
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var k: int = row+corner.y
				var a := lerpf(-2.70,2.70,(col+corner.x)/32.0)
				var pleat := 1.0+0.038*cos(10*a)*k/4.0
				var y: float = heights[k]-0.07*cos(a)*k/4.0
				surface.set_color(Color("#cbad7c") if row==2 else Color("#285653"))
				surface.set_normal(Vector3(sin(a),0.4,cos(a)).normalized())
				surface.add_vertex(Vector3(widths[k]*sin(a)*pleat,y,depths[k]*cos(a)*pleat))
	mesh = surface.commit()
