class_name PUWGifDecoder
extends RefCounted
## Minimal GIF87a/89a frame decoder for Pokemon Ultimate World.
##
## Why this exists: Godot's Image loader cannot read GIF files,
## but every animated battle sprite in the project index is a
## Showdown animated GIF. The battle sprite loader streams and
## caches those GIFs by URL; this decoder turns the cached bytes
## into the composited RGBA frames (plus per-frame delays in
## seconds) that an AnimatedSprite2D can play.
##
## Scope, stated honestly: this decodes the GIF subset the
## Showdown sprite files use -- global/local colour palettes,
## LZW compression, graphic-control transparency + disposal
## (leave / restore-background / restore-previous), and
## interlaced images. It composites every frame onto a full
## logical-screen canvas, so the returned Images are finished
## pictures, one per animation frame. It is a decoder only:
## it downloads nothing and invents nothing -- bad or truncated
## data returns {"ok": false} and no frames.

## Decode GIF bytes. Returns:
##   {"ok": bool, "width": int, "height": int,
##    "frames": Array of Image (RGBA8, logical-screen size),
##    "delays": Array of float seconds, one per frame}
static func decode(data: PackedByteArray) -> Dictionary:
	var fail: Dictionary = {"ok": false, "width": 0, "height": 0, "frames": [], "delays": []}
	if data.size() < 13:
		return fail
	var header: String = data.slice(0, 6).get_string_from_ascii()
	if header != "GIF89a" and header != "GIF87a":
		return fail
	var pos: int = 6
	var width: int = _u16(data, pos)
	var height: int = _u16(data, pos + 2)
	var packed: int = data[pos + 4]
	pos += 7
	if width <= 0 or height <= 0:
		return fail
	var global_palette: Array = []
	if (packed & 0x80) != 0:
		var gct_size: int = 1 << ((packed & 0x07) + 1)
		global_palette = _read_palette(data, pos, gct_size)
		pos += 3 * gct_size
	var canvas: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var frames: Array = []
	var delays: Array = []
	# Graphic control state, applied to the next image block.
	var gce_disposal: int = 0
	var gce_delay_cs: int = 10
	var gce_trans_index: int = -1
	var previous_canvas: Image = null
	while pos < data.size():
		var block: int = data[pos]
		pos += 1
		if block == 0x3B:  # trailer
			break
		if block == 0x21:  # extension
			if pos >= data.size():
				break
			var label: int = data[pos]
			pos += 1
			if label == 0xF9:  # graphic control extension
				if pos >= data.size():
					break
				var block_size: int = data[pos]
				pos += 1
				if pos + block_size > data.size():
					break
				var gce_packed: int = data[pos]
				gce_disposal = (gce_packed >> 2) & 0x07
				gce_delay_cs = _u16(data, pos + 1)
				gce_trans_index = data[pos + 3] if (gce_packed & 0x01) != 0 else -1
				pos += block_size
				if pos < data.size():
					pos += 1  # block terminator
			else:
				pos = _skip_sub_blocks(data, pos)
			continue
		if block == 0x2C:  # image descriptor
			if pos + 9 > data.size():
				break
			var fx: int = _u16(data, pos)
			var fy: int = _u16(data, pos + 2)
			var fw: int = _u16(data, pos + 4)
			var fh: int = _u16(data, pos + 6)
			var img_packed: int = data[pos + 8]
			pos += 9
			var palette: Array = global_palette
			if (img_packed & 0x80) != 0:
				var lct_size: int = 1 << ((img_packed & 0x07) + 1)
				palette = _read_palette(data, pos, lct_size)
				pos += 3 * lct_size
			var interlaced: bool = (img_packed & 0x40) != 0
			if pos >= data.size() or palette.is_empty() or fw <= 0 or fh <= 0:
				break
			var min_code_size: int = data[pos]
			pos += 1
			var compressed: PackedByteArray = PackedByteArray()
			while pos < data.size():
				var chunk_size: int = data[pos]
				pos += 1
				if chunk_size == 0:
					break
				if pos + chunk_size > data.size():
					break
				compressed.append_array(data.slice(pos, pos + chunk_size))
				pos += chunk_size
			var indices: PackedInt32Array = _lzw_decode(compressed, min_code_size, fw * fh)
			if indices.size() < fw * fh:
				break
			if gce_disposal == 3:
				previous_canvas = canvas.duplicate()
			_draw_frame(canvas, indices, fx, fy, fw, fh, interlaced, palette, gce_trans_index)
			frames.append(canvas.duplicate())
			var delay_s: float = float(gce_delay_cs) / 100.0
			if delay_s <= 0.0:
				delay_s = 0.1
			delays.append(delay_s)
			# Apply this frame's disposal before the next frame.
			if gce_disposal == 2:
				var rect: Rect2i = Rect2i(fx, fy, fw, fh).intersection(Rect2i(0, 0, width, height))
				if rect.size.x > 0 and rect.size.y > 0:
					canvas.fill_rect(rect, Color(0, 0, 0, 0))
			elif gce_disposal == 3 and previous_canvas != null:
				canvas = previous_canvas
				previous_canvas = null
			gce_disposal = 0
			gce_delay_cs = 10
			gce_trans_index = -1
			continue
		# Unknown block byte: the stream is not a GIF we can trust.
		break
	if frames.is_empty():
		return fail
	return {"ok": true, "width": width, "height": height, "frames": frames, "delays": delays}


static func _u16(data: PackedByteArray, offset: int) -> int:
	if offset + 1 >= data.size():
		return 0
	return int(data[offset]) | (int(data[offset + 1]) << 8)


static func _read_palette(data: PackedByteArray, offset: int, count: int) -> Array:
	var palette: Array = []
	for i in count:
		var p: int = offset + i * 3
		if p + 2 >= data.size():
			palette.append(Color(0, 0, 0, 1))
		else:
			palette.append(Color(float(data[p]) / 255.0, float(data[p + 1]) / 255.0, float(data[p + 2]) / 255.0, 1.0))
	return palette


static func _skip_sub_blocks(data: PackedByteArray, pos: int) -> int:
	var cursor: int = pos
	while cursor < data.size():
		var chunk_size: int = data[cursor]
		cursor += 1
		if chunk_size == 0:
			break
		cursor += chunk_size
	return cursor


## Draw one frame's colour indices onto the canvas, honouring
## interlace row order and the transparent colour index.
static func _draw_frame(canvas: Image, indices: PackedInt32Array, fx: int, fy: int, fw: int, fh: int, interlaced: bool, palette: Array, trans_index: int) -> void:
	var row_order: Array = []
	if interlaced:
		var starts: Array = [0, 4, 2, 1]
		var steps: Array = [8, 8, 4, 2]
		for group in 4:
			var y: int = starts[group]
			while y < fh:
				row_order.append(y)
				y += steps[group]
	else:
		for y in fh:
			row_order.append(y)
	var canvas_size: Vector2i = canvas.get_size()
	for src_y in fh:
		var dst_y: int = fy + int(row_order[src_y])
		if dst_y < 0 or dst_y >= canvas_size.y:
			continue
		for x in fw:
			var dst_x: int = fx + x
			if dst_x < 0 or dst_x >= canvas_size.x:
				continue
			var idx: int = indices[src_y * fw + x]
			if idx == trans_index:
				continue
			if idx < 0 or idx >= palette.size():
				continue
			canvas.set_pixel(dst_x, dst_y, palette[idx])


## GIF LZW decompression. Returns up to `expected` colour
## indices (fewer when the data is truncated or corrupt).
static func _lzw_decode(data: PackedByteArray, min_code_size: int, expected: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if min_code_size < 2 or min_code_size > 8:
		return out
	var clear_code: int = 1 << min_code_size
	var eoi_code: int = clear_code + 1
	var dictionary: Array = []
	var code_size: int = min_code_size + 1
	var next_code: int = eoi_code + 1
	for i in clear_code:
		dictionary.append([i])
	dictionary.append([clear_code])  # placeholder for the clear code
	dictionary.append([eoi_code])  # placeholder for the end code
	var bit_pos: int = 0
	var total_bits: int = data.size() * 8
	var previous: Array = []
	while bit_pos + code_size <= total_bits:
		var code: int = 0
		for b in code_size:
			var byte_index: int = (bit_pos + b) >> 3
			var bit_index: int = (bit_pos + b) & 7
			if (int(data[byte_index]) >> bit_index) & 1:
				code |= 1 << b
		bit_pos += code_size
		if code == clear_code:
			dictionary.clear()
			for i in clear_code:
				dictionary.append([i])
			dictionary.append([clear_code])
			dictionary.append([eoi_code])
			code_size = min_code_size + 1
			next_code = eoi_code + 1
			previous = []
			continue
		if code == eoi_code:
			break
		var entry: Array = []
		if code < dictionary.size() and not (dictionary[code] as Array).is_empty() and int((dictionary[code] as Array)[0]) != clear_code and code != eoi_code:
			entry = (dictionary[code] as Array).duplicate()
		elif code == next_code and not previous.is_empty():
			entry = previous.duplicate()
			entry.append(previous[0])
		else:
			break  # corrupt stream
		for value in entry:
			out.append(int(value))
			if out.size() >= expected:
				return out
		if not previous.is_empty():
			var new_entry: Array = previous.duplicate()
			new_entry.append(entry[0])
			if next_code < 4096:
				if next_code == dictionary.size():
					dictionary.append(new_entry)
				elif next_code > dictionary.size():
					break
				next_code += 1
				if next_code == (1 << code_size) and code_size < 12:
					code_size += 1
		previous = entry
	return out
