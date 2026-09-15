# Infrastructure Cost

Region: `eu-north-1` (Stockholm). Prices are on-demand, USD, as of September 2026.

## Monthly breakdown

| Item | Qty | Unit | Monthly |
|---|---:|---|---:|
| EC2 `t3.small` (2 vCPU, 2 GiB) — k3s server | 1 | $0.0216/hr | $15.77 |
| EC2 `t3.small` — k3s agents | 2 | $0.0216/hr | $31.54 |
| EBS gp3 root volumes, 20 GiB | 3 | $0.088/GiB-mo | $5.28 |
| S3 — Terraform remote state | 1 | negligible | $0.02 |
| Data transfer out | ~5 GB | $0.09/GB after 100GB free | $0.00 |
| Domain `oliveoparaocha.xyz` | 1 | $2.04/yr | $0.17 |
| **Total** | | | **~$52.78** |

Not billed: the VPC, subnet, internet gateway, route tables, and security groups are free. Let's Encrypt certificates are free.

## Halving the cost

The compute is 89% of the bill, so that is the only lever worth pulling.

Moving both agents to **Spot instances** cuts their cost by roughly 70% — around $22/month saved — at the price of a two-minute interruption notice. That is an acceptable trade for worker nodes in this architecture: the app runs 2 replicas per tier with `topologySpreadConstraints` and PodDisruptionBudgets, so losing one agent triggers a reschedule rather than an outage. The control plane stays on-demand, because losing the k3s server loses the API.

Beyond that: **shutting the cluster down outside working hours** costs nothing to implement and saves about 65% if the cluster runs 8 hours a day on weekdays. For a capstone that is graded in a window rather than serving users, that is the larger saving. Combining both takes the bill under $20/month.

Verify current prices at https://aws.amazon.com/ec2/pricing/on-demand/ before relying on these figures.