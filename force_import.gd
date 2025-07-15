@tool
extends EditorScript

# This script forces import of debris textures

func _run():
	print("Force importing debris textures...")

	# Force reimport of all debris textures
	var debris_paths = [
		"res://assets/sprites/debris/scrap_metal.png",
		"res://assets/sprites/debris/broken_satellite.png",
		"res://assets/sprites/debris/bio_waste.png",
		"res://assets/sprites/debris/ai_component.png",
		"res://assets/sprites/debris/unknown_artifact.png"
	]

	for path in debris_paths:
		if ResourceLoader.exists(path):
			print("Forcing import of: " + path)
			EditorInterface.get_resource_filesystem().reimport_files([path])

	print("Force import complete")
