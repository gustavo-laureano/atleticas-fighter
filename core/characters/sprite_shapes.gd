class_name SpriteShapes
extends RefCounted

# Extrai o contorno do desenho de um frame (pixels não transparentes) para
# montar hitboxes que acompanham o sprite. O resultado fica em cache por
# textura, então cada frame só é processado uma vez no jogo inteiro.

# Pixels com alfa acima disso contam como "corpo".
const ALPHA_THRESHOLD := 0.5
# Quanto o contorno é simplificado, em pixels da textura (maior = menos pontos).
const SIMPLIFY_EPSILON := 3.0
# Descarta pedacinhos soltos do desenho (bigode, sujeira na borda...).
const MIN_AREA := 150.0

static var _cache: Dictionary = {}


# Contornos do desenho da textura, em pixels da textura (origem no canto superior esquerdo).
static func outlines(texture: Texture2D) -> Array[PackedVector2Array]:
	if _cache.has(texture):
		return _cache[texture]

	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, ALPHA_THRESHOLD)

	var result: Array[PackedVector2Array] = []
	for outline in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), SIMPLIFY_EPSILON):
		if _area(outline) >= MIN_AREA:
			result.append(outline)
	_cache[texture] = result
	return result


static func _area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for i in polygon.size():
		sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(sum) / 2.0
