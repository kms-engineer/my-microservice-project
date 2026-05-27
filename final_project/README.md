# Фінальний проєкт — DevOps інфраструктура на AWS

Повний CI/CD-стек на AWS, керований через Terraform: EKS + RDS + ECR + Jenkins + Argo CD + Prometheus/Grafana.

---

## Архітектура

```
                                Internet
                                    │
                          ┌─────────┴─────────┐
                          │   Internet GW     │
                          └─────────┬─────────┘
                                    │
            ┌───────────────────────┴───────────────────────┐
            │                  VPC 10.0.0.0/16              │
            │                                               │
            │   Public subnets (10.0.1-3.0/24)              │
            │   ├── NAT Gateway                             │
            │   ├── EKS workers (t3.medium x 3, autoscale)  │
            │   │   ├── jenkins ns        (CI)              │
            │   │   ├── argocd ns         (GitOps CD)       │
            │   │   ├── monitoring ns     (Prom + Grafana)  │
            │   │   └── django ns         (App)             │
            │   └── Load Balancers                          │
            │                                               │
            │   Private subnets (10.0.4-6.0/24)             │
            │   └── RDS PostgreSQL 15.18 (db.t3.micro)      │
            │       — or Aurora cluster if use_aurora=true  │
            │                                               │
            └───────────────────────────────────────────────┘

  ECR ─── Jenkins build ─── kaniko ─── push image ─── update Helm values
                                                       │
                                                       ▼
                                              Argo CD detects Git change
                                                       │
                                                       ▼
                                              Deploy to EKS (django ns)

  Prometheus scrapes metrics → Grafana dashboards
```

---

## Структура проєкту

```text
final_project/
├── main.tf                   # Підключення всіх модулів
├── backend.tf                # S3 + DynamoDB backend
├── outputs.tf                # Загальні виводи
├── README.md                 # Цей файл
│
├── modules/
│   ├── s3-backend/           # S3 bucket + DynamoDB для tfstate
│   ├── vpc/                  # VPC + public/private subnets + IGW + NAT
│   ├── ecr/                  # ECR repository для Docker-образів
│   ├── eks/                  # EKS cluster + node group + EBS CSI driver
│   ├── rds/                  # Універсальний модуль RDS / Aurora (з lesson-db-module)
│   ├── jenkins/              # Jenkins через Helm + IRSA для Kaniko
│   ├── argo_cd/              # Argo CD через Helm + Application/Repository
│   └── monitoring/           # ★ kube-prometheus-stack (Prometheus + Grafana)
│
├── charts/
│   └── django-app/           # Helm-чарт Django-застосунку (керується Argo CD)
│
└── Django/                   # Сорси Django-застосунку
    ├── app/                  # Код Django (manage.py, settings, views)
    ├── Dockerfile            # Білдиться Jenkins-pipeline через Kaniko
    ├── Jenkinsfile           # CI: clone → build → push to ECR → update Helm values
    └── docker-compose.yaml   # Локальна розробка (Django + Postgres)
```

---

## Компоненти

| Шар | Технологія | Як піднімається |
|-----|-----------|-----------------|
| Мережа | VPC, Subnets, IGW, NAT | `module.vpc` |
| Контейнерний реєстр | ECR | `module.ecr` |
| Kubernetes | EKS (1.29+) + managed node group + EBS CSI | `module.eks` |
| База даних | RDS PostgreSQL **або** Aurora (toggle `use_aurora`) | `module.rds` |
| CI | Jenkins + Kaniko (через IRSA) | `module.jenkins` + Helm |
| CD | Argo CD з app-of-apps | `module.argo_cd` + Helm |
| Моніторинг | kube-prometheus-stack (Prometheus, Grafana, AlertManager, Node Exporter, kube-state-metrics) | `module.monitoring` + Helm |
| Застосунок | Django + Gunicorn у Helm chart | Argo CD + `charts/django-app/` |

---

## Як запустити

### 1. Передумови

- AWS CLI налаштовано (`aws configure`)
- Terraform >= 1.0
- kubectl
- Helm (опціонально, для ручної перевірки релізів)

### 2. Bootstrap S3 backend (один раз)

S3-бакет та DynamoDB-таблиця для зберігання state потрібні **до** того, як можна використати їх як backend. Тому при першому запуску:

```bash
cd final_project

# Закоментуй увесь блок terraform { backend "s3" { ... } } у backend.tf
# Потім:
export TF_VAR_db_password='SuperSecret123!'
export TF_VAR_grafana_admin_password='admin'

terraform init
terraform apply -target=module.s3_backend -auto-approve
```

Після того як bucket + table створено — розкоментуй `backend.tf` та зроби:

```bash
terraform init -migrate-state    # Відповідь: yes
```

### 3. Повне розгортання

```bash
cd final_project
export TF_VAR_db_password='SuperSecret123!'
export TF_VAR_grafana_admin_password='admin'

terraform init
terraform plan
terraform apply
```

Розгортання займає ~20–25 хвилин:
- VPC + NAT — 2 хв
- EKS cluster — 12-15 хв
- RDS — 8-10 хв (паралельно)
- Helm-релізи (Jenkins, Argo CD, Monitoring) — 5-7 хв

### 4. Підключення до кластера

```bash
aws eks update-kubeconfig --name final-project-eks --region us-west-2
kubectl get nodes
```

### 5. Перевірка стану ресурсів

```bash
kubectl get all -n jenkins
kubectl get all -n argocd
kubectl get all -n monitoring
kubectl get all -n django
```

---

## Доступ до сервісів

### Jenkins

```bash
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```
Відкрити: http://localhost:8080
Логін: `admin` / `admin123` (див. `modules/jenkins/values.yaml`)

### Argo CD

```bash
kubectl port-forward svc/argocd-server 8081:443 -n argocd
```
Відкрити: https://localhost:8081
Логін: `admin`
Пароль:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Grafana

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
```
Відкрити: http://localhost:3000
Логін: `admin` / значення `TF_VAR_grafana_admin_password`

Готові дашборди (з коробки kube-prometheus-stack):
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Node Exporter / Nodes
- Kubernetes / Networking / Cluster

### Prometheus

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
```
Відкрити: http://localhost:9090

---

## CI/CD флоу

1. Розробник пушить код у Git
2. **Jenkins** (`seed-job` → `goit-django-docker`):
   - Клонує репозиторій
   - Білдить Docker-образ через **Kaniko** (без Docker daemon, з правами IRSA)
   - Пушить образ у **ECR**
   - Оновлює `image.tag` у `charts/django-app/values.yaml`
   - Пушить оновлений values.yaml назад у Git
3. **Argo CD** виявляє зміну в Git (кожні ~3 хв)
4. Argo CD автоматично оновлює Deployment у EKS з новим образом
5. **Prometheus** збирає метрики з нових подів, **Grafana** показує

---

## RDS ↔ Aurora перемикання

Модуль `rds` універсальний — одна змінна `use_aurora` контролює тип БД:

```bash
# Звичайна RDS (за замовчуванням)
terraform apply

# Aurora кластер
terraform apply -var="use_aurora=true"
```

Деталі — у `modules/rds/`.

---

## Автомасштабування

| Шар | Як масштабується |
|-----|------------------|
| **EKS Nodes** | Managed node group (`min=2, max=5, desired=3`) — додає інстанси при тиску |
| **Django Pods** | HPA у `charts/django-app/templates/hpa.yaml` — масштабує за CPU |
| **Argo CD** | Auto Sync + Self-Heal — підтримує бажаний стан |
| **Prometheus** | Persistent storage 10 GB, retention 7 днів |

---

## Видалення інфраструктури

⚠️ **Важливо: правильний порядок видалення!**

Якщо просто `terraform destroy` — Terraform спробує видалити S3 bucket із tfstate **разом** із усіма ресурсами, що ламає процес.

**Безпечний порядок:**

```bash
# 1. Видали всі ресурси крім S3 backend
terraform destroy -target=module.monitoring \
                  -target=module.argo_cd \
                  -target=module.jenkins \
                  -target=module.rds \
                  -target=module.eks \
                  -target=module.ecr \
                  -target=module.vpc

# 2. (Опціонально) Видали S3 + DynamoDB вручну, коли state більше не потрібен
aws s3 rb s3://mykyta-terraform-state-bucket --force
aws dynamodb delete-table --table-name terraform-locks --region us-west-2
```

---

## Безпека

- **IAM**: EKS workers і Jenkins ServiceAccount мають IRSA (IAM Roles for Service Accounts) — токени не зберігаються в подах
- **VPC**: RDS у **приватних** підмережах, недоступна з інтернету
- **Security Groups**: RDS приймає трафік тільки з CIDR VPC (`10.0.0.0/16`)
- **ECR**: scan_on_push = true — кожен образ сканується на вразливості
- **Secrets**:
  - `TF_VAR_db_password` через environment, не у Git
  - Grafana пароль через `TF_VAR_grafana_admin_password`
  - Argo CD initial password — у Kubernetes Secret
- **Terraform state**: зашифрований у S3 (`encrypt = true`)

---

## Критерії оцінювання — відповідність

| Критерій | Бал | Реалізація |
|----------|-----|------------|
| Коректна архітектура | 20 | VPC з public/private, EKS у public, RDS у private |
| Безпека (VPC, IAM, SG) | 20 | IRSA для Jenkins і EBS CSI, SG для RDS, шифрування state |
| Застосунок з CI/CD | 30 | Jenkins (Kaniko) → ECR → Argo CD → EKS |
| Моніторинг + автомасштабування | 20 | kube-prometheus-stack + HPA + EKS node group autoscale |
| Документація | 10 | Цей README |
| **Разом** | **100** | |
