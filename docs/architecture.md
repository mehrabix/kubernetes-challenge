# Architecture

## Request flow

```
curl $(minikube ip)
      │  HTTP :80
      ▼
ingress-nginx controller        (minikube ingress addon, hostPort 80)
      │  routes by Ingress rule
      ▼
Service hello (ClusterIP :80)   stable virtual IP + DNS name
      │  selector: app.kubernetes.io/name=hello
      ▼
EndpointSlice                   the list of Ready Pod IPs
      │  load-balances
      ▼
Pod hello (:4000)               Express app
      │  envFrom ConfigMap
      ▼
"Hello Ahmad!"
```

## Components

### The application
A minimal Express service ([`src/app.js`](../src/app.js)) with three routes:

| Route | Purpose |
|-------|---------|
| `/` | returns `Hello ${process.env.NAME || 'guest'}!` |
| `/healthz` | liveness/startup probe target |
| `/readyz` | readiness probe target |

### The deployment
[`k8s/base/deployment.yaml`](../k8s/base/deployment.yaml):

- **2 replicas** by default (bumped to 3 in the `prod` overlay).
- **RollingUpdate** `maxSurge: 1`, `maxUnavailable: 0` — no capacity loss on deploy.
- **Probes**:
  - `startupProbe` → `/healthz`, `failureThreshold: 30` (30×2s of grace at boot),
  - `readinessProbe` → `/readyz`, gates traffic,
  - `livenessProbe` → `/healthz`, restarts a wedged process.
- **Security**: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, all capabilities dropped, `seccompProfile: RuntimeDefault`.
- **Resources**: requests `50m/64Mi`, limits `250m/128Mi` (base).
- **Topology spread** across nodes with `whenUnsatisfiable: ScheduleAnyway`.

### Networking
- **Service**: ClusterIP, port `80` → `targetPort: http` (4000).
- **Ingress**: class `nginx`, catch-all `/` prefix rule.
- **NetworkPolicy**: only Pods in `ingress-nginx` may reach port 4000.

> NetworkPolicy is enforced only by CNIs that implement it (e.g. Calico,
> Cilium). minikube's default CNI may accept the object without enforcing it.

### Scaling & availability
- **HPA**: 2–10 replicas, target 70% CPU, conservative scale-down window.
- **PDB**: `minAvailable: 1`.

### Configuration
- **ConfigMap** `hello-config` holds `NAME`. It is projected into the container
  via `envFrom`, so the same image behaves differently per environment.

### Environments
`k8s/base` is the single source of truth. Overlays express only differences:

```
k8s/
├── base/                    # complete stack
└── overlays/
    ├── dev/                 # 1 replica, "Ahmad (dev)"
    └── prod/                # 3 replicas, bigger resources
```

## Design decisions

| Decision | Rationale |
|----------|-----------|
| Kustomize over raw YAML | one base, thin overlays, no template language |
| No `:latest` tag | reproducible, avoids silent drift |
| Non-root + read-only FS | defence in depth |
| ConfigMap for `NAME` | configuration separated from the image |
| Catch-all Ingress | satisfies `curl $(minikube ip)` on the node IP |
| Image built inside minikube | no registry required for the challenge |
