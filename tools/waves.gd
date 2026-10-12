extends Node
func _ready():
	for p in Data.PLANES.size():
		var w := Data.waves_for(p)
		print("plane ", p)
		for i in w.size():
			var s := ""
			for g in w[i]:
				s += "%s x%d (r%d, gap %.1f, at %.0f)  " % [g.kind, g.count, g.road, g.gap, g.delay]
			print("  w%d: %s" % [i, s])
	get_tree().quit()
