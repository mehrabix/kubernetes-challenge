# kubernetes-challenge

A small Node.js service, deployed to Kubernetes the way a production team
would do it: declarative manifests with Kustomize, security-hardened and
health-checked Pods, autoscaling, disruption budgets, a CI pipeline, and
one-command automation scripts.

> The service answers `Hello <name>!` — the name is injected from a ConfigMap.

<p align="center">
  <a href="https://github.com/mehrabix/kubernetes-challenge/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/mehrabix/kubernetes-challenge/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-blue.svg">
  <img alt="Node" src="https://img.shields.io/badge/node-24_LTS-339933?logo=node.js&logoColor=white">
  <img alt="Kubernetes" src="https://img.shields.io/badge/kubernetes-1.34+-326CE5?logo=kubernetes&logoColor=white">
  <img alt="Minikube" src="https://img.shields.io/badge/minikube-compatible-29A500?logo=minikube&logoColor=white">
</p>

---

## The challenge

This repository is the solution to the [learnk8s Kubernetes challenge](https://github.com/learnk8s/kubernetes-challenge):

> Deploy this application to Minikube and customise the environment variable to display your name.
>
> ```
> $ curl $(minikube ip)
> Hello Ahmad!
> ```

The challenge itself only asks for a Deployment, a Service, an Ingress and a
ConfigMap. This repository delivers that **and** the practices you would expect
around it in a real team: probes, resource management, security context,
autoscaling, a disruption budget, a network policy, environment overlays, CI,
and automation.

See [`docs/challenge.md`](docs/challenge.md) for a requirement-by-requirement
mapping.

---

## Architecture

```
                    curl $(minikube ip)
                           │
                           ▼
                 ┌────────────────────┐
                 │  Ingress Controller │   (ingress addon)
                 │      (NGINX)        │
                 └─────────┬──────────┘
                           │  Ingress: rule "/" -> Service hello:80
                           ▼
                 ┌────────────────────┐
                 │   Service (hello)   │   ClusterIP :80 -> targetPort http
                 └─────────┬──────────┘
                           │  selector: app.kubernetes.io/name=hello
                           ▼
        ┌──────────────────┴──────────────────┐
        │                                     │
   ┌────▼─────┐                        ┌──────▼───┐
   │ Pod hello │  ...              ...  │ Pod hello │   (2+ replicas, HPA)
   │ :4000     │                        │ :4000     │
   └────┬──────┘                        └───────────┘
        │  envFrom: ConfigMap hello-config (NAME)
        ▼
   "Hello Ahmad!"
```

Reading the request path top to bottom is the fastest way to debug any layer of
it — see [`docs/troubleshooting.md`](docs/troubleshooting.md).

---

## Repository layout

```
kubernetes-challenge/
├── server.js                 # entrypoint (listens on PORT)
├── src/app.js                # Express app: /, /healthz, /readyz
├── test/unit/app.test.js     # unit tests (mocha + supertest)
├── Dockerfile                # multi-stage, non-root runtime
├── Makefile                  # developer entrypoint
├── k8s/
│   ├── base/                 # the full application stack
│   └── overlays/{dev,prod}/  # per-environment tweaks
├── scripts/                  # automation (bootstrap/build/deploy/verify/teardown)
├── .github/workflows/ci.yml  # lint, tests, image build, manifest validation
└── docs/
    ├── challenge.md          # challenge -> repo mapping
    ├── architecture.md       # component-by-component walkthrough
    └── troubleshooting.md    # how to debug each layer (with kubectl)
```

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/) (v1.34+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.34+)
- [Node.js](https://nodejs.org/) 24 LTS (only needed to run tests/lint locally)

---

## Quick start

```bash
git clone https://github.com/mehrabix/kubernetes-challenge.git
cd kubernetes-challenge

# start minikube, enable ingress, build the image, deploy, and verify
make up

# or, at the end of the run:
curl $(minikube ip)
# Hello Ahmad!
```

`make up` runs [`scripts/bootstrap.sh`](scripts/bootstrap.sh), which is
idempotent and safe to re-run.

### Manual steps (what the automation does)

```bash
minikube start
minikube addons enable ingress

# Build the image and load it into minikube (no registry push needed).
docker build -t kubernetes-challenge:1.0.0 .
minikube image load kubernetes-challenge:1.0.0

# Deploy the dev overlay.
kubectl apply -k k8s/overlays/dev
kubectl -n hello rollout status deployment/hello

# Verify.
curl $(minikube ip)
```

---

## What gets deployed

| Resource | Name | Notes |
|----------|------|-------|
| Namespace | `hello` | isolates the stack |
| ConfigMap | `hello-config` | holds `NAME` (the greeting) |
| ServiceAccount | `hello` | no API token mounted |
| Deployment | `hello` | 2 replicas (base), rolling update, 3 probes, non-root, read-only root FS |
| Service | `hello` | ClusterIP, `:80` → `http` (4000) |
| Ingress | `hello` | NGINX, catch-all rule so `curl $(minikube ip)` works |
| HorizontalPodAutoscaler | `hello` | 2–10 replicas on 70% CPU |
| PodDisruptionBudget | `hello` | `minAvailable: 1` |
| NetworkPolicy | `hello` | only the ingress controller may reach the Pods |

---

## Configuration

The only knob is the `NAME` value, supplied by the ConfigMap:

```yaml
# k8s/base/configmap.yaml
data:
  NAME: "Ahmad"
```

Overlays change it per environment, e.g. `k8s/overlays/dev` sets
`"Ahmad (dev)"`. Change it, re-apply, and the greeting updates:

```bash
kubectl -n hello edit configmap hello-config
kubectl -n hello rollout restart deployment/hello
curl $(minikube ip)
```

---

## Environments (Kustomize)

`k8s/base` holds the complete stack; overlays only express the differences:

| Overlay | Replicas | Notes |
|---------|----------|-------|
| `k8s/overlays/dev` | 1 | smaller footprint, dev greeting |
| `k8s/overlays/prod` | 3 | larger resource requests/limits |

```bash
kubectl apply -k k8s/overlays/dev     # or prod
kubectl kustomize k8s/overlays/prod   # render without applying
```

---

## CI/CD

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push and
pull request:

1. **Lint & unit tests** — `npm run lint`, `npm test` on Node 24.
2. **Container build** — a reproducible image build with Buildx (no push).
3. **Manifest validation** — renders the production overlay and validates it
   against the Kubernetes schemas with [kubeconform](https://github.com/yannh/kubeconform).

---

## Automation scripts

| Script | Purpose |
|--------|---------|
| `scripts/bootstrap.sh` | end-to-end: start minikube → enable ingress → build → deploy → verify |
| `scripts/build-image.sh` | build the image inside minikube's Docker daemon |
| `scripts/deploy.sh` | apply the selected Kustomize overlay and wait for rollout |
| `scripts/verify.sh` | assert `curl $(minikube ip)` returns `Hello <NAME>!` |
| `scripts/teardown.sh` | delete the rendered resources |
| `scripts/lib.sh` | shared helpers and configuration |

All scripts honour `MINIKUBE_PROFILE`, `OVERLAY`, `IMAGE` and `NAMESPACE`
environment variables.

---

## Make targets

```
make up             # full local setup
make build          # build the image into minikube
make deploy         # apply the overlay
make verify         # curl and assert the greeting
make down           # delete everything
make logs           # tail application logs
make port-forward   # forward the Service to localhost:8080
make test           # unit tests
make lint           # eslint
```

---

## Production-minded details

- **Non-root, read-only root filesystem**, all capabilities dropped, `seccompProfile: RuntimeDefault`.
- **Three probes**: `startupProbe` (slow starts), `readinessProbe` (traffic gating), `livenessProbe` (restart on wedge).
- **Resource requests and limits** on every container; the HPA scales on CPU utilisation.
- **Rolling update** with `maxUnavailable: 0` so capacity is never reduced during a deploy.
- **Topology spread** so replicas prefer different nodes.
- **PodDisruptionBudget** so voluntary disruptions keep at least one replica.
- **NetworkPolicy** so only the ingress controller reaches the Pods.
- **No `:latest` tag** — the image is pinned to a version.

---

## Troubleshooting

Every layer can fail independently. The full playbook — including the exact
`kubectl` commands for a `Pending`, `CrashLoopBackOff`, `ImagePullBackOff`,
`OOMKilled`, a broken Ingress `503`, and a `Pending` PVC — lives in
[`docs/troubleshooting.md`](docs/troubleshooting.md).

Quick sanity checks:

```bash
kubectl -n hello get pods,svc,ingress
kubectl -n hello describe pod -l app.kubernetes.io/name=hello
kubectl -n hello logs -l app.kubernetes.io/name=hello --tail=50
curl -s -o /dev/null -w '%{http_code}\n' $(minikube ip)
```

---

## License

[MIT](LICENSE) © Ahmad Mehrabi
