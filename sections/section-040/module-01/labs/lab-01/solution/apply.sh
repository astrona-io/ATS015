#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

# 1. The credential, in the gateway POD's namespace (istio-system), not in
#    tls-demo where the Gateway object lives. A learner builds it with
#    `kubectl -n istio-system create secret tls booking-credential ...` from the
#    material the bootstrap leaves in /tmp. The certificate embedded here is an
#    equivalent self-signed certificate for CN=booking.ica.local, so CI is
#    deterministic.
# NOT A SECRET. Throwaway self-signed material generated for this lab only, for
# the non-routable training host name booking.ica.local. It secures nothing
# real and is committed deliberately so `astrona test` is reproducible.
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: booking-credential
  namespace: istio-system
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUROVENDQWgyZ0F3SUJBZ0lVUFlPdVVlTUlub1JFOTQ3dEFVa2hnZ2ZCMEdjd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0tqRWFNQmdHQTFVRUF3d1JZbTl2YTJsdVp5NXBZMkV1Ykc5allXd3hEREFLQmdOVkJBb01BMmxqWVRBZQpGdzB5TmpBNU1qY3hPVFF3TlRWYUZ3MHpOakE1TWpReE9UUXdOVFZhTUNveEdqQVlCZ05WQkFNTUVXSnZiMnRwCmJtY3VhV05oTG14dlkyRnNNUXd3Q2dZRFZRUUtEQU5wWTJFd2dnRWlNQTBHQ1NxR1NJYjNEUUVCQVFVQUE0SUIKRHdBd2dnRUtBb0lCQVFDM0o1ejZhbW5SNXFQd29RUUhaZXNwRHVIWkJ1Qkp4ZWMreVR0MHZ4WDhyV1dUZXF4TgpNQmxMOHgrTm5kU3J4R3BWMzU4cTQ4WWJpcXdmb0o2dkxqU3NPaG44TkNZWVFHSy9ITGtMNFcvVksvQnNGcU1JCkw0SEJmVlF3UXZXWHBFNVl3TkdDZUZtSmpGaUhaMVdMTm5mR0VnaXVpNDRBSk5YU1g0Vi9IYUsrZjREK2dadmQKTnZINXB5MktiSUZ3WEdCSnlvb01Pb1o2eUJ3RlliZGhqM0doM2hCV3BCZ05NUnZKMUMwTG5XVkpSQnVGeEdySApWVE4veTdPajhOZVhlKzFJcU1RTFE0ekNGajJsYmpQU3czVXVpcUVkM3llcEU5RTE0djY5QW9SMEQ1eWZWTzA5Cmg5MlpLa1JJM084NUJzZzZUSlJOaW1OMlMyMTdKT2tDaVdpakFnTUJBQUdqVXpCUk1CMEdBMVVkRGdRV0JCVFgKTE41QktEWG5pOEprVjFkZUdmTlNpelJ2akRBZkJnTlZIU01FR0RBV2dCVFhMTjVCS0RYbmk4SmtWMWRlR2ZOUwppelJ2akRBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUEwR0NTcUdTSWIzRFFFQkN3VUFBNElCQVFBVWYwTXFuZjQ1CndJKzdXMHd5NFVCczY1Z1RMcTBUdVpKcHp3V1NwT2ZibVF3bHJkN3lFVFBSRVZjYnpUSU9mZjN6RlJCbjhQeEEKZnhUdytXRkdibzl4eGlnN2NLWDVocG9GWGhBdGw1cVNNcWhhRS9ORkUzTFQzanZjQkx1TkRQS1BQSEpMR2tQbgppUTFJK2ROTWpGTEtwc3J1K0VrQWNHRE56WW1wQmVEVVltZ2NDTkJLV1dRckhxZTcyYVQ5YmN5YkdHN3Y2aHRjCk9lOVhjcVdYYURtTkNVK0NLQ0FxbU0wT0p6MGxVdmgxZjZ4QUFjMVlZWTAxcm5LOEJBWTVRWStJemNKUVFEREcKemo3eWxJQVl1aDQ4UysvTG5Bbyt1NENUVWhHaC8vK1QxVVY1M081MzNXRW5YV3RDYnZoWE1OYmYzNDdFeml3Kwo3ZHhnY2pDN0VjMTMKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBZ0VBQW9JQkFRQzNKNXo2YW1uUjVxUHcKb1FRSFplc3BEdUhaQnVCSnhlYyt5VHQwdnhYOHJXV1RlcXhOTUJsTDh4K05uZFNyeEdwVjM1OHE0OFliaXF3ZgpvSjZ2TGpTc09objhOQ1lZUUdLL0hMa0w0Vy9WSy9Cc0ZxTUlMNEhCZlZRd1F2V1hwRTVZd05HQ2VGbUpqRmlICloxV0xObmZHRWdpdWk0NEFKTlhTWDRWL0hhSytmNEQrZ1p2ZE52SDVweTJLYklGd1hHQkp5b29NT29aNnlCd0YKWWJkaGozR2gzaEJXcEJnTk1SdkoxQzBMbldWSlJCdUZ4R3JIVlROL3k3T2o4TmVYZSsxSXFNUUxRNHpDRmoybApialBTdzNVdWlxRWQzeWVwRTlFMTR2NjlBb1IwRDV5ZlZPMDloOTJaS2tSSTNPODVCc2c2VEpSTmltTjJTMjE3CkpPa0NpV2lqQWdNQkFBRUNnZ0VBQk16aC9XSTFSeU5xQ3BBb2RkL1lTNm1GMjlWUCtEOEZSNHo5K2tVRDJOZmIKNjFpY3ZzMG9RZWhXWEYrQVI4Ymh3K3hxS2QveHZQTzVKOVJpM3Y2R3NqamlTTXpwR1Z1ZXBabWxjL0tZVVcybgpEZE9EWkY4eVljQXlLUUw5bUMySWxzK1VRM3pQV1VrM1loMGdPSUl0ODNWYzREanN6aTRvK0lHT2FIMStCWFliClZTNkNCeHNIb0VnZmJ6MVhHa2tEWXg5MFNLbHhBSWZ6eXZRSDBlM1ZVUFZHcEl0czRGVThoamFuRzRFSVpqc1IKUmJXamFOTGRVZFpJT1dlUzNORWF5czdVSk11RTJEM2pHL3h2bFY0UUlxSG1YYk9YRUFvaTRuRkZPR2VLekZUQgoweXN3UG5vSGxYRXVCWXgrNWEyTktKUXVLMWZJcDRrbTEzZFZXOFo0eVFLQmdRRG4zWWVjVyttcWk0Snh2NSs1CjFUdCsycnV4T1QvUjhMOUJzQlArRk5PWDhJN2ZmVkF4a3R6Ym5PWTNVOSt1cVBXSFhwcHlrL082NWdlNnpwa3AKSlg0bmJTYWU5cElvakhJdnVIelBBVFNuUHovcGJZeHM3OFppTkRNd09WYU01ak53endPbFk2c2Y0MzhubFlEZApIREl3SFVZc2ZzZGFJdXlxSHpWSzlVTWVKd0tCZ1FES09CbjE3TUF0djhGUklCV0NkVFNhUmFZUHMvaHJuUVRoClFMWjdqY1JDWmllbnp5SWJxOWZTOWtGZndyL0R3SWQ4aWVRYUhPSjMyYW5VMEFIWU42d081bGhyeUJaWVJibzEKZlZTZWJVSGY5dGFFUjZlRXJYK3IwK2lYWGxrU0p0YzZ4MFlYUTdCcTdDY1g3QkVKbDJ4S2ZuNzNXcDRUTnNpVApFOS9Mc1A2ckpRS0JnQXBPVlhYRXZCa2hoRlhMLzZ5QjV0Z1hudG9jd2xKeGtmNjRkZHNJVC9OajlPWElLeVZZCjhzb3NLaXR4WmZMY2ZiVmJwaC9McGJ5NzlzSDk1dDdtVkxvcDV0cVArU1VtUVBrUUNUUW1TSkhhaE51NlM5Q1gKdzhpZnExck1ZYVYzb2ZlMHErUFJEMDBtam9OUzZOeHJJV3YwRVNkdkp5dEJmQ1YvcDUzQ1V3NW5Bb0dBRHhYYQpVZTlFY3VWQUxhWWdGS2hic1RxSzVkYitMRUQ5Y1RSYnFLSHR4eXBKd1FvQnVHQzhhLzkwNXdqbk4xb3dnVWprCkhGS1ZUbTJOYnRQSm4zQ2Z4RWpJeGRtYVdTRnlmN1VHei83RWtFbWd2U04vU3JXS3RhM01SeWFCckluN09tWk4KUTBVSWJ5R0kxUThHUWxucWVUQXdscEZMQTVIdHFwTXIrYzBOWW9VQ2dZRUFyOXR0VkRMNGtTQmVncXJJOVFNdQpsMzB3Y0NMZWZIcHE0cHZGMEx3Q3VKcFFJODc4VUY4MjJ3emdoTWpJeFdSaWgvcThyRUF3MVpiT2JZUWFUbmxUCmtwRmpvWWdsbDh2RlFzSk1kUXNkZVNiaFBpdVdQQzd1Ym9HMXE1OFdZcENvTGMxdktWOXhnMEVDZ0Rjb0MwUHYKQzFPcnZKY0Y0aE13R2lUbldwQzJSRGM9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
YAML

# 2. The Gateway (TLS listener on 443, redirect-only listener on 80) and the
#    VirtualService that routes /book to booking-service.
kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: booking-gateway
  namespace: tls-demo
spec:
  selector:
    istio: ingressgateway
  servers:
    # TLS listener. protocol HTTPS, and a port name starting `https`.
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - booking.ica.local
      tls:
        mode: SIMPLE
        # A bare name, resolved in the gateway pod's namespace.
        credentialName: booking-credential
    # Plaintext listener that only redirects. No credential needed.
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - booking.ica.local
      tls:
        httpsRedirect: true
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: booking
  namespace: tls-demo
spec:
  hosts:
    - booking.ica.local
  gateways:
    - booking-gateway
  http:
    - match:
        - uri:
            prefix: /book
      route:
        - destination:
            host: booking-service
            port:
              number: 80
YAML

# Give istiod time to push the credential and the listeners to the gateway
# before the grader reads them back. `astrona test` applies and grades in the
# same second, and would otherwise measure the previous state.
sleep 15
