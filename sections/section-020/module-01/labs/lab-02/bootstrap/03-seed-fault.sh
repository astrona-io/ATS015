#!/usr/bin/env bash
# The lab's starting state: least-privilege guest lists for the Starfleet,
# with two faults hidden in them.
#   - scout-allow-bridge names the caller sa/bridge, but the bridge runs as
#     sa/starfleet-bridge. The list reaches the scouts, but no rule fits, so
#     the bridge page shows "product reviews are currently unavailable".
#   - navcom-allow-scout selects app=navcomm, a label no pod has. The list
#     never reaches navcom, so navcom is covered only by allow-nothing and the
#     scouts lose their star ratings.
# allow-nothing, bridge-allow-get and cargo-allow-bridge are correct.
# Fixing the two broken lists is the task.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: bridge-allow-get
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: bridge
  action: ALLOW
  rules:
  - to:
    - operation:
        methods: ["GET"]
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: cargo-allow-bridge
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: cargo
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/starfleet-bridge"]
    to:
    - operation:
        methods: ["GET"]
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: scout-allow-bridge
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: scout
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/bridge"]
    to:
    - operation:
        methods: ["GET"]
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: navcom-allow-scout
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: navcomm
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/starfleet-scout"]
    to:
    - operation:
        methods: ["GET"]
YAML

# The empty guest list last, so the planet is only closed once the narrow
# lists are in place.
kubectl apply -f - <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: starfleet
spec: {}
YAML
echo "==> Lab ats-015-lab-020-01-02 ready"
