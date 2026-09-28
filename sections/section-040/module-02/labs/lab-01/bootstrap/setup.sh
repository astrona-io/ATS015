#!/usr/bin/env bash
# Bootstrap for LAB015-040-02 — Require Client Certificates At The Edge
# Pre-work only. This installs Istio and the starting workloads; it deliberately
# creates NONE of the objects the task asks for — those are what grading checks.
set -euo pipefail

ISTIO_VERSION="1.30.5"
NAMESPACE="mtlsedge-demo"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin the version rather than accepting whatever istioctl happens to be on the
# machine: a different client installs a different control plane, and the whole
# course is written against ${ISTIO_VERSION}. BIN_DIR goes first on PATH above,
# so the pinned binary wins over any system-wide one.
have_version=""
command -v istioctl >/dev/null 2>&1 && \
  have_version=$(istioctl version --remote=false 2>/dev/null | awk '/client version/{print $3}')
if [ "$have_version" != "$ISTIO_VERSION" ]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  echo "[bootstrap] Downloading Istio ${ISTIO_VERSION}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
  install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"
fi
istioctl version --remote=false

if ! command -v openssl >/dev/null 2>&1; then
  echo "[bootstrap] Installing openssl..."
  (apt-get update -qq && apt-get install -y -qq openssl) >/dev/null 2>&1 \
    || (apk add --no-cache openssl) >/dev/null 2>&1 \
    || echo "[bootstrap] WARNING: could not install openssl automatically." >&2
fi

echo "[bootstrap] Installing the Istio control plane (demo profile)..."
istioctl install --set profile=demo -y
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s

# The manifests below are also listed under bootstrap.manifests in config.yaml,
# so they may already be applied. kubectl apply is idempotent, and re-applying
# covers pods created before the injection webhook existed.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apply_manifest() {
  for c in "$SCRIPT_DIR/../manifests/$1" "./manifests/$1" "$SCRIPT_DIR/manifests/$1"; do
    if [ -f "$c" ]; then echo "[bootstrap] Applying $c..."; kubectl apply -f "$c"; return 0; fi
  done
  echo "[bootstrap] WARNING: manifest $1 not found." >&2
}
apply_manifest "lab-start.yaml"

# NOT SECRETS. Throwaway self-signed material for the non-routable training
# hostnames *.ica.local, committed deliberately so `astrona test` is reproducible.
# A CA plus a server and a client certificate are provided, fixed rather than
# generated, so that the reference solution in solution/ trusts the same CA and
# `astrona test` is deterministic.
cat > /tmp/ca.crt <<'PEMEOF'
-----BEGIN CERTIFICATE-----
MIIDHzCCAgegAwIBAgIUDUl96XY38KNQH3YyR1Nhv6jhYxcwDQYJKoZIhvcNAQEL
BQAwHzEPMA0GA1UEAwwGaWNhLWNhMQwwCgYDVQQKDANpY2EwHhcNMjYwOTI3MTk0
MjA5WhcNMzYwOTI0MTk0MjA5WjAfMQ8wDQYDVQQDDAZpY2EtY2ExDDAKBgNVBAoM
A2ljYTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMAeKxr35gkQz4y5
Fu4ZVI3taBCGVzmWz/NrWxUJIIojlcSMYgzDr4y363pTUnBv1v8LXJMP17ZwYpJa
OzKSHJ/AGi4qKGBDBE29/Fc7TR/zP9uD1b9reMNI2XuNTtKaJzaSCDQlYHAkQS0L
NXk1j4pbvUP3dXH+nqm8qCC6x7lz2F/MPwW4nhkQUan24317oD51Fe8ZBFa/JD87
EgKFLM0evdLnFbBsjOBXDXvDxjZo1OSKQjSXqvZfO8grtXHUwNh95CdMaLB+KA/j
gdHg08l2H73eKoRyOvi6OCQHZh7c9UTdI60AoqabnVpTddjT4RpwG2hyvNg14e35
CMlWTOkCAwEAAaNTMFEwHQYDVR0OBBYEFMCIRTl5wqwR20nE0VP6kB45brwPMB8G
A1UdIwQYMBaAFMCIRTl5wqwR20nE0VP6kB45brwPMA8GA1UdEwEB/wQFMAMBAf8w
DQYJKoZIhvcNAQELBQADggEBAIhmjQsy7WiuWL/Q2IiR3fi5W5HAL+mA4dSCC+7Z
R3LsPZRiJte26ucogkNDP/ff20HOjdB5gHg/1MR8dAf7FHDGAjqvPwKD6ULhNlaA
3sEY2jdWVwvtrCc7z9LXh/GGC5J1+eZqFXKiVi5a6STawy45ILNyWpxV44F4W7aj
7AMeX9bIlwEQzPYD0xY7SpdVrLmrWdjcWmytRE8eub4yeafG/B40vQJRbCBi6VWH
zMu4QLak5elq9yb9GfZllCpje/wXkQ8BksVNyVDnBLzHRbbG4N658cWzX+Q5Wqc2
a+p7ZTWGLUu7oQO5j7zuQwHUdScNkc8Oq1FGs93q4Jn01Hk=
-----END CERTIFICATE-----
PEMEOF
cat > /tmp/ca.key <<'PEMEOF'
-----BEGIN PRIVATE KEY-----
MIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIBAQDAHisa9+YJEM+M
uRbuGVSN7WgQhlc5ls/za1sVCSCKI5XEjGIMw6+Mt+t6U1Jwb9b/C1yTD9e2cGKS
WjsykhyfwBouKihgQwRNvfxXO00f8z/bg9W/a3jDSNl7jU7Smic2kgg0JWBwJEEt
CzV5NY+KW71D93Vx/p6pvKgguse5c9hfzD8FuJ4ZEFGp9uN9e6A+dRXvGQRWvyQ/
OxIChSzNHr3S5xWwbIzgVw17w8Y2aNTkikI0l6r2XzvIK7Vx1MDYfeQnTGiwfigP
44HR4NPJdh+93iqEcjr4ujgkB2Ye3PVE3SOtAKKmm51aU3XY0+EacBtocrzYNeHt
+QjJVkzpAgMBAAECgf8pC4bGw/Q0WoeBmb6lxXH801d2tMFVpdJS3rHPOfSF5x9r
B2tZqUSdwebtUIEASQf9I76eAKR+XYsKAmKcvg+oU+6lE80/SBr2CeRX5mzmmDy3
aoggLe9BRTf8zY95Aw6DLyBwdmQYDPZOHS4d10vh2HNT62qU9cCnVJaA7AW5E4XL
D5NNaEvqKuWC1sJvouLBscgXZfxJaQCa/eehhEPuCxVVFOiMJcQ06xXBs2eTnOqQ
XwnYxHQaQGHE9FRMpnOfAE1TL+M5F7/X1pORIjM4yEUl3jxHHnd/m4sab8GQ0a/h
2ZpV687EBTQLZoLP9GWlX9tkokp2VfNoayptvUECgYEA7H6pDYVFRXSo0t17XSrb
AiEu1v9SzARQ88Aj7DkrKr0m/e5GWUTtqijus/d5fo/l3ho0WUvTlB6iY0+Ya5lL
scLHQXmurNzeCoV29VYtBDwuR9kgtFfhOCBVeOis+l1Yr+NR2UTmN1//1mAEs3Is
hZYYcgqDEZKVKGWlyn2G80ECgYEAz/aJJayDL0TNQOnDmBSxob4oRL2VewV3luRb
B1pkzY4hNTpD0CwLxVux9FkCP0AaIMDhKYSeScSPYisaXLEHJb4Sgj5hzs757Bbg
KiaW+1eym0/Y+zsbmRVBloU6HPt9j2OCXMO0yvVsKxCUWF/VfGpG0ldCooeh+qBm
WO+M96kCgYEAuYfsa/T/kSuiPjsPStoSEquhqX2IoRFJyNAV3n5DBTZ7Xn8NpX7T
zMhr67fcEpQlS4bXRq6b//nAf5S0CMWsgnpCA3XIuUhU0YA/AN1oV4g27prCc3j1
8Sg8pawz9/4/U01MqtzIluyzMqUFSxnpH6vO5bildqW+aoDD/gVYV4ECgYAkTGTN
1ZmkM38b+HFyZxJGJ/nBXdHsghzIkp0s4GM92bQEJWJWwIlhbkrWWn7g6WBmHSRv
6bzzJULdoKZeTWvw84cpgpfx0ACha7C+yrOJtVnwb/RwjXWYt7QWALUO//p/f5/u
bx5sWoAB2Ef8UOXjbG1mI2L3GXN1Wm/i0BUr2QKBgC7umfnI8WvOGzvrbsE/6vKa
5M7JHB75SYzpiAM1bRBPbNAhZym6asrUV7UrKzBGNYCLJuCLwjMO1N9LumG+kU2A
wydsR0G+xSdia76w7VwUZTA43l4vprrk35Enr6jrsOr1m3A6kGfgyXaJ4Z9EViTO
sUkdJEZQbIKrrd76KnaT
-----END PRIVATE KEY-----
PEMEOF
cat > /tmp/booking.crt <<'PEMEOF'
-----BEGIN CERTIFICATE-----
MIIDGTCCAgGgAwIBAgIUVe1inMyIf9V82shpcYzsvE2acHswDQYJKoZIhvcNAQEL
BQAwHzEPMA0GA1UEAwwGaWNhLWNhMQwwCgYDVQQKDANpY2EwHhcNMjYwOTI3MTk0
MjA5WhcNMzYwOTI0MTk0MjA5WjAqMRowGAYDVQQDDBFib29raW5nLmljYS5sb2Nh
bDEMMAoGA1UECgwDaWNhMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
uqqXBIfRjW8JMNyXHJSecO9Wgx9B9SbZxDP3E6suLRR0VTQamJug1eWa2BdAc3TY
hxNAipbvqPFqNa8+elQ8cK9/ZXXH9/VTR9DXSWVz5sWlujCpWVyZRYDqZKn82JtC
XsYnYSE21QvEPkknX55TW+0JwB9zUtPggyvm3CCMb7A9nsa+h1o1u4Chn2OPABaI
gQMSMWFdUxFKLWUb+mBcZ6imqPN4JjaVHNvaB5QTwEiKykUCjql42uOIUtq1z0KG
uRv+J8BcpMZ39bW/Z8itYQztg28l/nBUyFS3X4Bb1ozFr6mgfloZqpguWTXB4Nw+
OWb6GMaNmEGG7eC+m1oVhQIDAQABo0IwQDAdBgNVHQ4EFgQUkJ8+WM6n6K7Q36lp
XI9PMoGVb7UwHwYDVR0jBBgwFoAUwIhFOXnCrBHbScTRU/qQHjluvA8wDQYJKoZI
hvcNAQELBQADggEBAJhD7tn1JpgSEqF8i5FVXkQBDaO2MY+MzP3RYkiMDCrbczWR
QfSc09vUZQip3VEFxLJKuSZmfCNH3CLWcPnwZBMtksXKUeFyiYDKSHi2w+nVY1xR
9WPlsfnoPS0zO0vKpmU4iZLJGzpAxHmyDBpUiKyHMRYmYqLg1m19kdLhb98jqwWF
QbfmhVK8FyTjn6Efg9jqY/aBDcRVR1PIwkuswtc5lISqcVlZ2snuLUPzAmQMxpXA
kHsjKxoDnLXId6X4RWgy1lQR0cFnJ55fGY2RdGd3rADeHZlRe4xW3JMtmllTAGkT
bSOHN9aziuUDdNvm0oWAOMEcbQKgEOM/n2cGVsg=
-----END CERTIFICATE-----
PEMEOF
cat > /tmp/booking.key <<'PEMEOF'
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC6qpcEh9GNbwkw
3JcclJ5w71aDH0H1JtnEM/cTqy4tFHRVNBqYm6DV5ZrYF0BzdNiHE0CKlu+o8Wo1
rz56VDxwr39ldcf39VNH0NdJZXPmxaW6MKlZXJlFgOpkqfzYm0JexidhITbVC8Q+
SSdfnlNb7QnAH3NS0+CDK+bcIIxvsD2exr6HWjW7gKGfY48AFoiBAxIxYV1TEUot
ZRv6YFxnqKao83gmNpUc29oHlBPASIrKRQKOqXja44hS2rXPQoa5G/4nwFykxnf1
tb9nyK1hDO2DbyX+cFTIVLdfgFvWjMWvqaB+WhmqmC5ZNcHg3D45ZvoYxo2YQYbt
4L6bWhWFAgMBAAECggEAWZZ0+14qAwzG5vX/6l4jusULisvOLpfyTPm5u+1csJMQ
EDJ9D0AmDXJwggSK0L7ECvQA9mLha/5NgK12OWTDSzvXUz0Xd5h820tOf/HakefL
FdSz+mj4QMTR+fUhnl3JmU3V6YZ02AQZL+GRLZGBpW1a0CPoB9kbeCjyWDSg4hrs
auW3bq4w2Re7NQ6sxvKT5nrLU6VL6oLFvXJ5gHyiV64Ct5DQCEZI8JB+C8a8klWs
5odbgy+ACUi6KOuOBM9lDjxO1BhLKrNrMxDlaoJPhSjyMXF5BJpPDjQNSW4LRhGd
HsTbdWr/C5uuQp2U7goXrKBnSlvZ1tEkNBUnr3kYwwKBgQDbE//fLv7AVLnN/C2C
yDebZxUBj6UlpN6mAHnyCkl941C3Zr7iXbTuhfrCLImxlAzsJ/Vw3QYe7WxmHpeP
GjYeu8OxPhf2NOLlhLDsDTJBtiYu0sIGNNx0gHHqkuhZ+AcRHX2Q4s7IZfXdJhzO
WMc2UYRIHUjKueQWBQ8Jt6DuqwKBgQDaIDQl5RNSijJq8oOw6O6M227ctJiqdUvq
ONL/4krpToWAasMFVexMYcsPXU2NQ55IYzDXCa595DrCTAv6OHYg+tjssbvXksF3
ZEKb4Altr7EBF9MTnnZzy8YCJHB6hVT84w7DRhS9nRUxLJ6/eC++0u5YzijyeOVx
jPSXnM5MjwKBgEeoFv0tJe5KyCtz3H72dhnCccB894uEjb7GURy1+KvQekpCtRTd
iZyq/gYdAzyuLDviJgmwgZwEFHyibPhFnoYW7D9BDB1f1wczi5rqBhIwPfT6wrO8
/o6spJYRTyZ+VfFnL/b/+JrbnrujB7EGoMJHj3j2+yQ0AUKijPSkt2LZAoGAbBN4
wy31nPgMcyEmTwma6P/wtjplSlBEBRGSumaNZ3wYecBsUMB6DH6H9lzsiAnw6zz6
fhG1+3qSAqNba+d94GlqAh0uTWnRoi5zMniXM1nSAhCj7Rye5FEbEwSrFonpykNW
lTqsHCcw0OSi44vRXGN25VmAwGNWjCSjLFvte9ECgYEAxnS0gPaOJF8C7vhLGYQq
1d0n1w07zH2AAOWNIAY9QkbXneV/ebJ1huxKUBCEGpnGW9TnP5cp0OK4uCy3KDNx
R8DGvJRiIkArsTeLkMSDRPlCqjpGI4v8XhytdxCxZEKiF1DkIvEj0TQLvEQRO37L
WhW9iVbuyk0ygg5aZC7nRGE=
-----END PRIVATE KEY-----
PEMEOF
cat > /tmp/client.crt <<'PEMEOF'
-----BEGIN CERTIFICATE-----
MIIDGDCCAgCgAwIBAgIUVe1inMyIf9V82shpcYzsvE2acHwwDQYJKoZIhvcNAQEL
BQAwHzEPMA0GA1UEAwwGaWNhLWNhMQwwCgYDVQQKDANpY2EwHhcNMjYwOTI3MTk0
MjA5WhcNMzYwOTI0MTk0MjA5WjApMRkwFwYDVQQDDBBjbGllbnQuaWNhLmxvY2Fs
MQwwCgYDVQQKDANpY2EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCT
SJxywSdJFzXlNJmkI29DtrcImVZajX/2lqYo757v9Too/A7caU7BnRfZH24XiBMd
aYXVnxLoOMCPvtaO2kRSUrdQgY2OEWRjErXAsotYHnAXq7qis41jOh/vvHk3ZVtZ
xrfeDNtw4IuhK1xHUHpUx3Ld0y0OuKIgA5AsNPoBhHytaDrfh3LQd5ar+EeUGwNB
ClASTcK29iazVGuEnLL26v5wgjtx2+zEUaQDea3Th/X+Jl4jzm+HU9mKtRFmnHYL
ZzWo2uaNk0GpTqCGIem/BNvr/SMXyvI2P9B1EcuQyk0s9FCt5cfWlBzveH4U5Mfr
+2CHLk0WpWst0oEfV0XrAgMBAAGjQjBAMB0GA1UdDgQWBBTPF5Gc4jFKBPlO6f7i
vV58TH7utzAfBgNVHSMEGDAWgBTAiEU5ecKsEdtJxNFT+pAeOW68DzANBgkqhkiG
9w0BAQsFAAOCAQEAPXxvfaFTOXTWd+4LIOZcLqLVGyw74CMdrou0p1bIyz9KTzo1
9GbsiB3bcvuUDgnwwumG9DTVpsqiTs0wxvzD1QUgv/A8RhWVcD4Oj0/XplYNaVfv
HKO7h2nnrEf+/Xii+N3Z334787wNnmdwqEZOjhQr2qJD3PnDta7y1ic//XeF18eK
imewNn8hTGjwVGaipkeTE2R4r6L8Dshrkh+EQNt9Nival7XL3SMr6SmfOYPW2qhL
/d+kLKO+5byzC7ZYVC2y2pnUvGfHo24gXE/eyI/wRRHcC0MDLdMSQGwh7TRoGpXX
wC4i8GHp1u4ZRIzB/ETVTo0RRwU89FYe7J2R7w==
-----END CERTIFICATE-----
PEMEOF
cat > /tmp/client.key <<'PEMEOF'
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCTSJxywSdJFzXl
NJmkI29DtrcImVZajX/2lqYo757v9Too/A7caU7BnRfZH24XiBMdaYXVnxLoOMCP
vtaO2kRSUrdQgY2OEWRjErXAsotYHnAXq7qis41jOh/vvHk3ZVtZxrfeDNtw4Iuh
K1xHUHpUx3Ld0y0OuKIgA5AsNPoBhHytaDrfh3LQd5ar+EeUGwNBClASTcK29iaz
VGuEnLL26v5wgjtx2+zEUaQDea3Th/X+Jl4jzm+HU9mKtRFmnHYLZzWo2uaNk0Gp
TqCGIem/BNvr/SMXyvI2P9B1EcuQyk0s9FCt5cfWlBzveH4U5Mfr+2CHLk0WpWst
0oEfV0XrAgMBAAECggEAFO1cTXHkgx4pKkgvDIN8a8Kqfy5KdtNkO0VslqR1kOLn
QKuP8QGFjz0jBlbQ7ccH8EXuHkxcA2MM+V/EXMfmrUvTgDzoQCd4fBtMd/Tml767
bqGYA0Y/8LlxkD7XemeMc1UpCwQIqiE9tcjTc86bkzBDwgEfhdf2MVZQRffBDjXt
zJEfRoEwGlv6aCu5J7c96JpZ9NLKnotRtQQkmG6rFoX2E31avI77x9vm/UbpmktC
k+p/BLxQGe51TuYsRM9qbB5HTmZJobcwdfNZyrHsqSVJnYM+qLaVgPq9aApIo5c6
t0ZA3QcaygFjVhp1qn10FOID6XEg+jFkWNpxekc4AQKBgQDIDlbw+Ddq6PhMj96U
4Es1cVLOw9/dHXI1WJ9Dc71b4C1raIERBUsyvRIBQ529oQS5OB86IkIi7AqOTxtb
WC2Xf4QcGsTSOS+A4OdoiDkG1iFw8y6HWkk6ye+JHeiTn5lpTLd1ZEPUr/Fin0VV
N8kg/AMAT96tlIGsuJbTFoZFiwKBgQC8eGOoQ6vHzohlRGYym5u+3D7pk5O9iRPF
W93MqyyowrKr1/cY/zZTWivfo1NkSbERsI4ZB9WfkaYgMu1q+lFrbNuHLBAj8dZ/
UmpOCeddU7is39I7hYABjUvspwEsH9HtJ3gDqi7uSCuZHh25AKawHDqNpZP0h8ru
j6h7UgjNIQKBgQCJm0t0Ltg3oo4AY8mPkARLe2qhLJxUhMelKBNMm1T52GaFhfmZ
UpHaEbFLy026PQJ5wL/CBgSF7uSH5KQFnc6mcaDWkBcoHwus04Z5IZJQQIP6JFux
4ImUdYhdQYRT3qjwhEOA7Pm3V1prIvDW4Ctpk88grM+XiBn2S3X7NngfZwKBgQCz
WeWMVIl+JN7Lb6HJeydlI3aDFLs9XNsBrwCNKj/fgRhCS8yLbyKlg2PI+EX9Y9sr
OFahH0F9Dj+G2K/yY69jiT4Hjjj128gBdc5P4UDZITjW2k/X8Jz13R5pYCvPb6B4
DF07L5JlkyxaE7y5NxNo+BQIg48e3rKQ/wiYAmL5wQKBgD0SbSTxhdzxn4db15+S
+2Jtv07mmryT0pBcja7srQNgmlFsCB4UcH0kBK2l1ABpSXZ77ympzSWZCIV4NFer
yT4f0XmFu1oA2aA3G0xhDZe12bkN7A/orgkJts1Xt69DTh4b+F2POrDEe5ahwPlQ
JAZ35VHzhJNV4xVEurDo291I
-----END PRIVATE KEY-----
PEMEOF
chmod 600 /tmp/ca.key /tmp/booking.key /tmp/client.key
ls -l /tmp/ca.crt /tmp/booking.crt /tmp/booking.key /tmp/client.crt /tmp/client.key

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || {
  echo "[bootstrap] ERROR: namespace $NAMESPACE was never created." >&2
  exit 1
}

echo "[bootstrap] Ensuring every workload in $NAMESPACE has a sidecar..."
kubectl -n "$NAMESPACE" rollout restart deployment --all >/dev/null 2>&1 || true
for dep in $(kubectl -n "$NAMESPACE" get deployment -o name); do
  kubectl -n "$NAMESPACE" rollout status "$dep" --timeout=300s
done

echo "[bootstrap] Ready. Namespace $NAMESPACE:"
kubectl -n "$NAMESPACE" get pods -o wide
echo "[bootstrap] Nothing the task asks for has been created."
