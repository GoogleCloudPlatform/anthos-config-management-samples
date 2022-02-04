package controller

rfc3339time(ns) = concat("T", [
	sprintf("%04d-%02d-%02d", time.date(ns)),
	sprintf("%02d:%02d:%02dZ", time.clock(ns)),
])

status := {"conditions": array.concat(
	[x |
		not count(children) == count(input.children[_])
		count(children) < 2
		x := {
			"lastTransitionTime": rfc3339time(time.now_ns()),
			"status": ["False", "True"][count(children)],
			"type": "effective",
		}
	],
	[input.parent.status.conditions[x] | input.parent.status.conditions[x]],
)}

children[child] {
	time.now_ns() > time.parse_rfc3339_ns(input.parent.validFrom)
	time.now_ns() < time.parse_rfc3339_ns(input.parent.validUntil)
	child := {
		"apiVersion": input.controller.spec.childResources[0].apiVersion,
		"kind": split({x | input.children[x]}[_], ".")[0],
		"metadata": {"name": input.parent.metadata.name},
		"roleRef": input.parent.roleRef,
		"subjects": input.parent.subjects,
	}
}
