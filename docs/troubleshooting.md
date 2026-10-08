# Troubleshooting playbook

The request path is layered, so debug it layer by layer — never guess.

```
DNS → Ingress → Service → Endpoints → Pod → container
```

Golden rules:

- `kubectl get pods` is a snapshot; `Running` does not mean healthy. Watch `RESTARTS`.
- Read **Events** for *when/what*; read **Last State** for *why* a container died.
- Always check **Endpoints**, not just Pods and Services.

## Quick status reference

| What you see | First command | Look for |
|--------------|---------------|----------|
| Pod `Pending` | `kubectl describe pod` | `FailedScheduling`, node selector, taints, resources |
| Pod `CrashLoopBackOff` | `kubectl logs --previous` | stack trace, exit code in `Last State` |
| Pod `ImagePullBackOff` | `kubectl describe pod` | `Failed to pull image`, tag, `imagePullSecrets` |
| Pod `OOMKilled` | `kubectl describe pod` | `lastState.reason: OOMKilled`, exit `137` |
| Ingress returns `503` | `kubectl get endpointslice` | empty Endpoints (selector drift) |
| PVC `Pending` | `kubectl describe pvc` | `ProvisioningFailed`, missing StorageClass |

---

## 1. The greeting is wrong (`Hello guest!`)

The `NAME` value did not reach the container.

```bash
kubectl -n hello exec deploy/hello -- printenv NAME
kubectl -n hello get configmap hello-config -o yaml
kubectl -n hello describe pod -l app.kubernetes.io/name=hello | grep -A3 Environment
```

If `NAME` is missing, check that the ConfigMap is referenced with `envFrom` and
that the Pod was restarted after a change:

```bash
kubectl -n hello rollout restart deployment/hello
```

## 2. Ingress returns `503 Service Temporarily Unavailable`

Almost always an **empty Endpoints** set.

```bash
kubectl -n hello get ingress hello -o wide
kubectl -n hello get svc hello -o wide
kubectl -n hello get endpointslice -l kubernetes.io/service-name=hello
kubectl -n hello get svc hello -o jsonpath='{.spec.selector}' ; echo
kubectl -n hello get pods --show-labels
```

`503` = no upstream; `502` = upstream refused (wrong `targetPort`); `504` = upstream too slow.

## 3. Pod is `Pending`

```bash
kubectl -n hello describe pod -l app.kubernetes.io/name=hello
kubectl -n hello get events --field-selector reason=FailedScheduling
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') | grep -A5 -i allocatable
```

Common causes: not enough resources for the `requests`, a `nodeSelector` that
matches nothing, or a taint without a toleration.

## 4. Pod is `CrashLoopBackOff`

```bash
kubectl -n hello describe pod <pod> | grep -A6 -i "Last State"
kubectl -n hello logs <pod> --previous
```

Exit code map: `1` config/app error, `127` binary missing, `137` OOM/SIGKILL,
`139` segfault. A `readOnlyRootFilesystem` that the app writes to is a classic
cause here — write to the mounted `emptyDir` at `/tmp` instead.

## 5. Pod is `OOMKilled`

```bash
kubectl -n hello describe pod <pod> | grep -A6 -i "Last State"   # exit 137
kubectl describe node <node> | grep -i -A3 MemoryPressure        # rule out node OOM
```

If memory usage climbs without bound it is a leak — raising the limit only
delays it. Set `requests == limits` for Guaranteed QoS on critical workloads.

## 6. Image pull fails (`ImagePullBackOff`)

```bash
kubectl -n hello describe pod <pod> | sed -n '/Events:/,$p'
```

The image must exist in minikube's Docker daemon:

```bash
eval $(minikube docker-env)
docker images kubernetes-challenge
```

If it is missing, rebuild (`make build`). Never rely on a registry for this
challenge — the image is built locally with `imagePullPolicy: IfNotPresent`.

## 7. PVC is `Pending` (storage layer)

```bash
kubectl -n hello get pvc
kubectl -n hello describe pvc <pvc>     # ProvisioningFailed: storageclass not found
kubectl get storageclass
kubectl get pv
```

A PVC referencing a non-existent StorageClass never binds. Create the
StorageClass or fix the claim. Note `spec.storageClassName` is immutable after
creation.

## 8. DNS fails inside the cluster

```bash
kubectl exec -n hello deploy/hello -- nslookup hello.hello.svc.cluster.local
kubectl get endpointslice -n kube-system -l kubernetes.io/service-name=kube-dns
```

If the `kube-dns` Service has no Endpoints, every Pod loses name resolution —
a cluster-wide, silent outage.

---

## Useful one-liners

```bash
# Everything at a glance
kubectl -n hello get deploy,rs,pod,svc,ingress,endpointslice

# Which Pods back the Service
kubectl -n hello get endpointslice -l kubernetes.io/service-name=hello \
  -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}{"  "}{.addresses[0]}{"\n"}{end}'

# Watch restarts over time
kubectl -n hello get pods -w

# Port-forward when the Ingress is suspect
kubectl -n hello port-forward svc/hello 8080:80
curl localhost:8080
```
