# Challenge mapping

The [learnk8s challenge](https://github.com/learnk8s/kubernetes-challenge) asks
for a small set of objects. This document maps each requirement to the files in
this repository and explains where the solution goes beyond the minimum.

| Challenge requirement | Where it is satisfied |
|-----------------------|-----------------------|
| Build the Docker image | [`Dockerfile`](../Dockerfile) (multi-stage, non-root) + [`scripts/build-image.sh`](../scripts/build-image.sh) |
| **Deployment** | [`k8s/base/deployment.yaml`](../k8s/base/deployment.yaml) |
| **Service** | [`k8s/base/service.yaml`](../k8s/base/service.yaml) |
| **Ingress** | [`k8s/base/ingress.yaml`](../k8s/base/ingress.yaml) |
| **ConfigMap** | [`k8s/base/configmap.yaml`](../k8s/base/configmap.yaml) (`NAME=Ahmad`) |
| Deploy to Minikube | [`scripts/bootstrap.sh`](../scripts/bootstrap.sh) / `make up` |
| `curl $(minikube ip)` returns `Hello Ahmad!` | catch-all Ingress rule → Service → Pod, verified by [`scripts/verify.sh`](../scripts/verify.sh) |
| Commit files to GitHub | `k8s/`, `scripts/`, `docs/`, CI workflow |

## Why the Ingress has no `host`

The challenge runs `curl $(minikube ip)` — the HTTP `Host` header is the node
IP. A rule with a fixed `host:` would return `404`. This repository therefore
uses a **host-less rule**, which matches any `Host`:

```yaml
rules:
  - http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: hello
              port:
                number: 80
```

To use a real hostname instead, add a `host:` and map it in `/etc/hosts`.

## Beyond the minimum

The challenge needs four objects. This repository also ships, because a real
deployment needs them:

- a `Namespace` (isolation),
- a `ServiceAccount` without a mounted API token,
- a `PodDisruptionBudget` (availability during node maintenance),
- a `HorizontalPodAutoscaler` (elasticity),
- a `NetworkPolicy` (least-privilege ingress),
- Kustomize overlays (`dev`, `prod`),
- probes, resource requests/limits, a hardened `securityContext`,
- a CI pipeline and automation scripts.

These are the difference between "it runs" and "it runs in production".
