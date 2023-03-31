# Copyright 2022 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
