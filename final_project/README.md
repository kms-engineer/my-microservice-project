# Фінальний проєкт — DevOps інфраструктура на AWS

Повний CI/CD-стек: VPC + EKS + RDS + ECR + Jenkins + Argo CD + Prometheus/Grafana, керований через Terraform.

## Як запустити

### 1. Bootstrap S3 backend (один раз)

```bash
cd final_project
export TF_VAR_db_password='SuperSecret123!'
export TF_VAR_grafana_admin_password='admin'

# Закоментуй блок backend "s3" у backend.tf, потім:
terraform init
terraform apply -target=module.s3_backend -auto-approve

# Розкоментуй backend.tf, потім:
terraform init -migrate-state
```

### 2. Повне розгортання (~20–25 хв)

```bash
terraform apply
```

### 3. Підключення до кластера

```bash
aws eks update-kubeconfig --name final-project-eks --region us-west-2
kubectl get all -n jenkins
kubectl get all -n argocd
kubectl get all -n monitoring
```

## Доступ до сервісів

```bash
# Jenkins — http://localhost:8080  (admin / admin123)
kubectl port-forward svc/jenkins 8080:8080 -n jenkins

# Argo CD — https://localhost:8081  (admin / <kubectl secret>)
kubectl port-forward svc/argocd-server 8081:443 -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Grafana — http://localhost:3000  (admin / $TF_VAR_grafana_admin_password)
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

# Prometheus — http://localhost:9090
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
```

## RDS ↔ Aurora

```bash
terraform apply                          # звичайна RDS
terraform apply -var="use_aurora=true"   # Aurora-кластер
```

## Видалення

```bash
terraform destroy -target=module.monitoring \
                  -target=module.argo_cd \
                  -target=module.jenkins \
                  -target=module.rds \
                  -target=module.eks \
                  -target=module.ecr \
                  -target=module.vpc
```
