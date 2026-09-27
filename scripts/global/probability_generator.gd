extends RefCounted
class_name ProbabilityGenerator

# ============================================================
# PROBABILITY GENERATOR
# Util random reusable: tiap index = 1 kandidat beda.
#
# weights: Array angka 0-100, bebas (GAK harus total 100).
# Contoh [34, 46, 90, 100] valid. Contoh [100, 90, 100] valid.
# Bobot gede = peluang gede. Bobot 0/kecil = (hampir) gak kepilih.
# Bobot negatif diperlakukan sebagai 0.
# ============================================================

## Satu draw berbobot. Return index kepilih, atau -1 kalau
## array kosong / semua bobot <= 0.
static func roll_index(weights: Array) -> int:
	if weights.is_empty():
		return -1
	var total := 0.0
	for w in weights:
		total += maxf(0.0, float(w))
	if total <= 0.0:
		return -1
	var r := randf() * total
	var acc := 0.0
	for i in range(weights.size()):
		acc += maxf(0.0, float(weights[i]))
		if r < acc:
			return i
	return weights.size() - 1


## Draw sebanyak count.
## allow_multiple = true  -> boleh index kembar (with replacement).
## allow_multiple = false -> tiap index max sekali (without replacement);
##   kalau count > jumlah kandidat, berhenti seadanya.
## Kalau semua bobot 0, fallback uniform random biar tetep jalan.
static func roll_multi(weights: Array, count: int, allow_multiple: bool = true) -> Array[int]:
	var out: Array[int] = []
	if weights.is_empty() or count <= 0:
		return out
	if allow_multiple:
		for n in range(count):
			var idx := roll_index(weights)
			if idx < 0:
				idx = randi() % weights.size()
			out.append(idx)
	else:
		var pool: Array[int] = []
		for i in range(weights.size()):
			pool.append(i)
		var pool_weights: Array = weights.duplicate()
		for n in range(count):
			if pool.is_empty():
				break
			var idx := roll_index(pool_weights)
			if idx < 0:
				idx = randi() % pool_weights.size()
			out.append(pool[idx])
			pool.remove_at(idx)
			pool_weights.remove_at(idx)
	return out
