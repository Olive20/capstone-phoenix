# Architecture

## Node topology

Three EC2 `t3.small` instances in a single VPC (`10.0.0.0/16`), one public subnet (`10.0.1.0/24`) in `eu-north-1a`.

| Node | Role | Private IP |
|---|---|---|
| `ip-10-0-1-39` | k3s server (control plane) | 10.0.1.39 |
| `ip-10-0-1-198` | k3s agent | 10.0.1.198 |
| `ip-10-0-1-66` | k3s agent, hosts `postgres-0` | 10.0.1.66 |

One availability zone, deliberately. EBS volumes are AZ-bound, so spreading nodes across zones would mean a Postgres PVC that cannot follow its pod. The failover requirement is node-level, not zone-level, so single-AZ satisfies it without the storage complication.

## Request flow

```
Browser
  → DNS: taskapp.oliveoparaocha.xyz → 51.20.133.199
  → EC2 security group (443 open to 0.0.0.0/0)
  → k3s ServiceLB → Traefik ingress controller
  → TLS terminated (Let's Encrypt cert via cert-manager)
  → path /api  → backend Service :5000 → Flask pod
  → path /     → frontend Service :80  → nginx pod
  → backend → postgres Service :5432 → postgres-0 (PVC)
```

Same-origin routing was chosen over separate `api.` and `taskapp.` hostnames: one certificate, one DNS record, and no CORS configuration in the application. The trade-off is that the frontend and backend cannot scale behind different ingress rules, which is irrelevant at this size.

## Network security

The security group is the only firewall; ufw is deliberately not enabled on the nodes, because two overlapping firewalls is a way to lock yourself out of your own infrastructure without gaining anything.

| Port | Source | Reason |
|---|---|---|
| 80, 443 | `0.0.0.0/0` | public web traffic, ACME HTTP-01 challenge |
| 22 | admin `/32` | SSH |
| 6443 | admin `/32` | kubectl from the operator's machine |
| 6443 | self-referencing | agents joining the server |
| 8472/udp | self-referencing | flannel VXLAN, pod network |
| 10250 | self-referencing | kubelet API, metrics-server |

The three internal rules use `referenced_security_group_id` rather than a CIDR: the rule says "any instance wearing this same security group," so adding a fourth node needs no firewall change and nothing is exposed publicly.

NetworkPolicy is enforced by kube-router, which k3s bundles by default. No separate CNI was installed. A default-deny policy covers the namespace, with explicit allows: Postgres accepts 5432 only from backend pods; backend accepts 5000 only from the frontend and from Traefik in `kube-system`; frontend accepts 80 only from Traefik.

## Single-server assumptions, and what fixes each

| Core requirement | The assumption it breaks |
|---|---|
| **Namespace + ConfigMap/Secret split** | On one box, config lives in a `.env` next to the code. Across a cluster, config must be an API object that any node can fetch, and secrets must be separable from non-secrets so the non-secret half can live in git. |
| **StatefulSet + PVC** | A container on one server writes to the host's disk and the disk is always there. In a cluster the pod may land anywhere, so storage must be requested as a claim and bound explicitly. |
| **2+ replicas, spread across nodes** | One server means one instance, and its failure is total. `topologySpreadConstraints` with `maxSkew: 1` prevents the scheduler from quietly placing both replicas on the same node — which would look like HA while providing none. |
| **Migrations as a Job** | With a single replica, running `alembic upgrade head` in the entrypoint is safe. With two replicas both start simultaneously and race on the same migration, and the loser can corrupt the alembic version table. A Job runs once, to completion, before anything serves traffic. |
| **Liveness / readiness / startup probes** | On one box you notice the process died. In a cluster nothing notices unless you tell it how to check. Readiness also gates traffic, which is what makes a rolling update safe. |
| **Resource requests and limits** | One server's resources are implicitly all yours. A scheduler needs requests to make placement decisions and limits to stop one pod starving its neighbours. |
| **RollingUpdate, `maxUnavailable: 0`** | Restarting a single-server app means downtime and you accept it. With replicas you can replace them one at a time — but only if the new pod is ready before the old one dies, and only if a `preStop` delay lets the service stop routing first. |
| **Ingress + cert-manager TLS** | One server means one nginx config and a manually renewed certificate. A cluster needs an ingress controller that discovers routes from the API, and certificate lifecycle that survives pods being replaced. |
| **Pinned image tags** | `:latest` on one box means you rebuild when you choose. Across replicas that reschedule independently, `:latest` means different nodes silently run different code. |

## Two failures worth recording

**The API ClusterIP was unreachable from every pod.** `kubectl get nodes` showed all three `Ready`, but CoreDNS, local-path-provisioner and metrics-server all failed identically with `dial tcp 10.43.0.1:443: i/o timeout`. The iptables NAT rules existed and looked correct. The endpoint behind the `kubernetes` service was the node's *public* IP, because the k3s install had been given `--node-external-ip`. A node cannot reach its own public address from inside a VPC — AWS translates it at the internet gateway — so every connection to the ClusterIP was DNAT'd to an unreachable destination. Removing the flag and reinstalling fixed it. `--tls-san` was kept, since it only adds the public IP as a valid name on the API certificate and does not affect routing.

**Postgres cannot reschedule.** k3s's default `local-path` provisioner binds a volume to the node that created it. If the node hosting `postgres-0` is drained or dies, the pod stays `Pending` because the volume cannot follow. The failover demonstration therefore drains a node that does not host Postgres. Fixing this properly means Longhorn or an EBS CSI driver, which is the correct answer for production and out of scope here.

## Deliberate omissions

`readOnlyRootFilesystem` was assessed and not applied. Both nginx and the Flask image write to their root filesystem at runtime — nginx to `/var/cache/nginx`, Python to `__pycache__` — so enabling it requires mounting an `emptyDir` at each write path. The remaining hardening is in place: `runAsNonRoot`, `runAsUser: 1000`, `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, and all capabilities dropped.

HPA was not implemented. Three Advanced items were chosen instead: NetworkPolicy, PodDisruptionBudget with graceful shutdown, and securityContext hardening.