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

rb := {
	"children": {"RoleBinding.rbac.authorization.k8s.io/v1": {}},
	"controller": {
		"apiVersion": "metacontroller.k8s.io/v1alpha1",
		"kind": "CompositeController",
		"metadata": {"name": "transient-rolebinding-controller"},
		"spec": {
			"childResources": [{
				"apiVersion": "rbac.authorization.k8s.io/v1",
				"resource": "rolebindings",
				"updateStrategy": {"method": "Recreate"},
			}],
			"generateSelector": true,
			"hooks": {"sync": {"webhook": {
				"timeout": "10s",
				"url": "http://transientcontroller-webhook.default:8181/v0/data/controller",
			}}},
			"parentResource": {
				"apiVersion": "example.com/v1",
				"resource": "transientrolebindings",
				"revisionHistory": {"fieldPaths": ["validUntil"]},
			},
			"resyncPeriodSeconds": 300,
		},
	},
	"parent": {
		"apiVersion": "example.com/v1",
		"kind": "TransientRoleBinding",
		"metadata": {"name": "test1"},
		"roleRef": {
			"apiGroup": "rbac.authorization.k8s.io",
			"kind": "ClusterRole", "name": "view",
		},
		"subjects": [{
			"kind": "ServiceAccount",
			"name": "default", "namespace": "default",
		}],
		"validFrom": "2022-01-24T21:08:00+08:00",
		"validUntil": "2022-01-24T21:08:00+08:00",
	},
}

crb := {
	"children": {"ClusterRoleBinding.rbac.authorization.k8s.io/v1": {}},
	"controller": {
		"apiVersion": "metacontroller.k8s.io/v1alpha1",
		"kind": "CompositeController",
		"metadata": {"name": "transient-clusterrolebindings-controller"},
		"spec": {
			"childResources": [{
				"apiVersion": "rbac.authorization.k8s.io/v1",
				"resource": "clusterrolebindings",
				"updateStrategy": {"method": "Recreate"},
			}],
			"generateSelector": true,
			"hooks": {"sync": {"webhook": {
				"timeout": "10s",
				"url": "http://transientcontroller-webhook.default:8181/v0/data/controller",
			}}},
			"parentResource": {
				"apiVersion": "example.com/v1",
				"resource": "transientclusterrolebindings",
				"revisionHistory": {"fieldPaths": ["validUntil"]},
			},
			"resyncPeriodSeconds": 300,
		},
	},
	"parent": {
		"apiVersion": "example.com/v1",
		"kind": "TransientClusterRoleBinding",
		"metadata": {"name": "test2"},
		"roleRef": {
			"apiGroup": "rbac.authorization.k8s.io",
			"kind": "ClusterRole",
			"name": "view",
		},
		"subjects": [{
			"kind": "ServiceAccount",
			"name": "default",
			"namespace": "default",
		}],
		"validFrom": "2022-01-23T21:08:00+08:00",
		"validUntil": "2022-01-25T21:08:00+08:00",
	},
}

test_crb_time_valid {
	vstime := time.now_ns() - (1200 * 1e09)

	vsrfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vstime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vstime)),
	])

	vetime := vstime + (2400 * 1e09)

	verfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vetime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vetime)),
	])

	count(children) == 1 with input as {
		"controller": crb.controller,
		"parent": object.union(crb.parent, {
			"validUntil": verfc3339,
			"validFrom": vsrfc3339,
		}),
		"children": crb.children,
	}
}

test_rb_time_valid {
	vstime := time.now_ns() - (1200 * 1e09)

	vsrfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vstime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vstime)),
	])

	vetime := vstime + (2400 * 1e09)

	verfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vetime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vetime)),
	])

	count(children) == 1 with input as {
		"controller": rb.controller,
		"parent": object.union(rb.parent, {
			"validUntil": verfc3339,
			"validFrom": vsrfc3339,
		}),
		"children": rb.children,
	}
}

test_crb_time_expired {
	vstime := time.now_ns() - (1200 * 1e09)

	vsrfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vstime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vstime)),
	])

	vetime := vstime + (600 * 1e09)

	verfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vetime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vetime)),
	])

	count(children) == 0 with input as {
		"controller": crb.controller,
		"parent": object.union(crb.parent, {
			"validUntil": verfc3339,
			"validFrom": vsrfc3339,
		}),
		"children": crb.children,
	}
}

test_rb_time_expired {
	vstime := time.now_ns() - (1200 * 1e09)

	vsrfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vstime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vstime)),
	])

	vetime := vstime + (600 * 1e09)

	verfc3339 := concat("T", [
		sprintf("%04d-%02d-%02d", time.date(vetime)),
		sprintf("%02d:%02d:%02dZ", time.clock(vetime)),
	])

	count(children) == 0 with input as {
		"controller": rb.controller,
		"parent": object.union(rb.parent, {
			"validUntil": verfc3339,
			"validFrom": vsrfc3339,
		}),
		"children": rb.children,
	}
}
