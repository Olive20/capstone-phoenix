# Runbook

Operational procedures for the Phoenix cluster. Every command assumes:

```bash
export KUBECONFIG=$HOME/capstone-phoenix/infra/ansible/kubeconfig
```

---

## 1. Provision from zero

Prerequisites: AWS CLI configured, Terraform ≥ 1.11, Ansible ≥ 2.16, an SSH keypair at `~/.ssh/id_ed25519`, and a registered domain.

**Create the state bucket** (one-time, out of band — Terraform cannot create the bucket holding its own state):

```bash
export AWS_REGION=eu-north-1
export TF_STATE_BUCKET=phoenix-tfstate-$(openssl rand -hex 4)
aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"
aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Put the bucket name in `infra/terraform/backend.tf`.

**Provision infrastructure:**

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # then set admin_cidr to your IP
terraform init
terraform apply
terraform output
```

**Bring up the cluster:**

Copy the IPs from `terraform output` into `infra/ansible/inventory.ini`, then:

```bash
cd ../ansible
ansible all -m ping
ansible-playbook site.yml
kubectl get nodes
```

All three nodes should report `Ready`.

**Install platform components:**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Create the Secret** (never committed):

```bash
kubectl apply -f manifests/00-namespace.yaml
PGPASS=$(openssl rand -base64 24)
kubectl create secret generic taskapp-secret -n taskapp \
  --from-literal=POSTGRES_PASSWORD="$PGPASS" \
  --from-literal=DATABASE_PASSWORD="$PGPASS" \
  --from-literal=SECRET_KEY="$(openssl rand -base64 32)"
```

Both password keys must hold the same value: Postgres reads `POSTGRES_PASSWORD`, the app reads `DATABASE_PASSWORD`.

**Point DNS** at the control-plane public IP:

```
A    taskapp    <server_public_ip>    TTL 600
```

**Hand the cluster to GitOps:**

```bash
kubectl apply -f gitops/application.yaml
kubectl get application -n argocd
```

Argo CD syncs everything under `manifests/` from then on.

---

## 2. Deploy a change

Do not use `kubectl apply`. Argo CD owns the cluster and `selfHeal` reverts manual changes within seconds.

```bash
git add manifests/
git commit -m "..."
git push
```

Argo picks it up within ~3 minutes. To force it:

```bash
kubectl -n argocd patch application taskapp --type merge \
  -p '{"operation":{"sync":{}}}'
```

---

## 3. Scale

Edit `replicas` in the relevant manifest, commit, push. A manual `kubectl scale` is reverted by `selfHeal`.

---

## 4. Roll back

```bash
git revert <bad-commit-sha>
git push
```

Argo reconciles to the reverted state. For an emergency rollback of a Deployment only:

```bash
kubectl rollout undo deployment/backend -n taskapp
```

That is a temporary measure — Argo will restore the git state, so follow it with a revert commit.

---

## 5. Recovery procedures

### Locked out: `kubectl` or SSH times out

**Cause:** dynamic public IP changed; the security group still allows the old address.

```bash
cd infra/terraform
terraform apply -var="admin_cidr=$(curl -4 -s ifconfig.me)/32" -auto-approve
```

Then update `admin_cidr` in `terraform.tfvars` so the next plain apply does not revert it.

### A worker node dies

Pods reschedule automatically; PodDisruptionBudgets keep one replica of each tier available throughout.

```bash
kubectl get nodes
kubectl get pods -n taskapp -o wide
```

To drain deliberately:

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>
```

**Do not drain the node hosting `postgres-0`.** Storage is `local-path`, which is node-bound, so the pod cannot reschedule. Find it first:

```bash
kubectl get pod postgres-0 -n taskapp -o wide
```

### A backend pod is unhealthy

```bash
kubectl get pods -n taskapp -l app=backend
kubectl logs -n taskapp -l app=backend --tail=50
kubectl describe pod -n taskapp -l app=backend | tail -20
kubectl delete pod -n taskapp <pod-name>    # the Deployment replaces it
```

### A bad migration

Migrations run as a Job, not in the replicas' entrypoint, so a failure does not take the app down.

```bash
kubectl logs -n taskapp -l job-name=taskapp-migrate --tail=50
kubectl exec -n taskapp postgres-0 -- \
  psql -U taskapp -d taskapp -c "SELECT * FROM alembic_version;"
```

To downgrade one revision, run a one-off pod with the same image and env, overriding the command to `alembic downgrade -1`. Then revert the migration in git and redeploy.

### Certificate not issuing

```bash
kubectl get certificate,order,challenge -n taskapp
kubectl describe certificate taskapp-tls -n taskapp | tail -20
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=30
```

Let's Encrypt allows 5 failed validations per hostname per hour. If you hit that limit, switch the `cert-manager.io/cluster-issuer` annotation on the Ingress to `letsencrypt-staging`, confirm the path works, then switch back.

---

## 6. Tear down

```bash
cd infra/terraform
terraform destroy
```

The S3 state bucket is not managed by Terraform and must be emptied and deleted manually.