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
kubectl get nodes
kubectl get all -n jenkins
kubectl get all -n argocd
kubectl get all -n monitoring
```

### 4. Запустити CI/CD pipeline (обов'язково — без цього ECR порожній, Django не запуститься)

Поди Django після кроку 2 будуть у `ImagePullBackOff` — це нормально, бо ECR ще порожній. Запусти pipeline:

1. Відкрий Jenkins (URL отримай з `kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`). Логін `admin` / `admin123`.
2. **Manage Jenkins → Credentials → System → Global → github-token → Edit** — встав свій GitHub Personal Access Token (`repo` scope).
3. На головній сторінці запусти **seed-job → Build Now**. Створиться пайплайн `goit-django-docker`.
4. **goit-django-docker → Build Now**. Pipeline побудує образ через Kaniko, запушить у ECR, оновить tag у `charts/django-app/values.yaml` і запушить у гілку `final_project`.
5. Argo CD підхопить зміну протягом ~3 хв і задеплоїть Django. Можна форсувати:
   ```bash
   kubectl -n argocd patch app django-app --type merge -p '{"operation":{"sync":{}}}'
   ```

## Доступ до сервісів

```bash
# Django app — через LoadBalancer
kubectl get svc django-app-django -n django -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# відкрий http://<hostname>

# Jenkins — http://<elb-hostname> або port-forward
kubectl port-forward svc/jenkins 8080:80 -n jenkins
# → http://localhost:8080  (admin / admin123)

# Argo CD — через ELB або port-forward
kubectl port-forward svc/argocd-server 8081:443 -n argocd
# → https://localhost:8081  (admin / <password нижче>)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# → http://localhost:3000  (admin / $TF_VAR_grafana_admin_password)

# Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# → http://localhost:9090
```

## RDS ↔ Aurora

```bash
terraform apply                          # звичайна RDS (за замовчуванням)
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

> Не використовуй просто `terraform destroy` — воно знесе S3-бакет із tfstate разом з усім. S3 + DynamoDB видаляй окремо вручну.

## Технічні нотатки

- **Instance type:** `t3.small` (Free Tier акаунти блокують t3.medium і вище)
- **Node count:** `desired_size = 4` (Prometheus + Jenkins + Argo CD + Django + postgres не вміщуються на 3 нодах через ліміт max-pods=11 на t3.small)
- **Provider auth:** Helm/Kubernetes провайдери використовують exec-based auth (`aws eks get-token`) замість `aws_eks_cluster` data-source — інакше plan падає коли EKS ще не існує.
- **S3 backend bucket:** `mykyta-final-project-state` — глобально-унікальне ім'я, не конфліктує з іншими проєктами.
