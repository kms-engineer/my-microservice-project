# Lesson 6 — Розгортання Django на Amazon EKS

Розгортання Django-застосунку з PostgreSQL на кластері Kubernetes (Amazon EKS), використовуючи Terraform для інфраструктури та Kubernetes-маніфести для деплою.

## Структура проєкту

```
lesson-6/
├── terraform/                    # Інфраструктура (IaC)
│   ├── main.tf                   # Підключення модулів
│   ├── backend.tf                # Бекенд для стейтів (S3 + DynamoDB)
│   ├── outputs.tf                # Виведення ресурсів
│   └── modules/
│       ├── s3-backend/           # S3-бакет та DynamoDB для стейтів
│       ├── vpc/                  # VPC, підмережі, шлюзи, маршрутизація
│       ├── ecr/                  # ECR-репозиторій для Docker-образів
│       └── eks/                  # EKS-кластер з Node Group
├── k8s/                          # Kubernetes-маніфести
│   ├── namespace.yaml            # Namespace django-app
│   ├── configmap.yaml            # ConfigMap з налаштуваннями
│   ├── secret.yaml               # Secret із секретами
│   ├── postgres.yaml             # PostgreSQL (Deployment + Service + PVC)
│   └── django-deployment.yaml    # Django (Deployment + LoadBalancer Service)
├── django_app/                   # Django-проєкт
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── pages/                        # Django-додаток pages
│   ├── views.py
│   ├── urls.py
│   └── apps.py
├── Dockerfile                    # Production Docker-образ (gunicorn)
├── .dockerignore
├── requirements.txt
├── manage.py
└── README.md
```

## Що нового у Lesson 6

- **Модуль EKS** — створює кластер Amazon EKS з IAM-ролями та Node Group
- **Kubernetes-маніфести** — деплой Django + PostgreSQL на EKS
- **Production Dockerfile** — gunicorn замість dev-сервера
- **ConfigMap та Secret** — конфігурація через Kubernetes-об'єкти

## Крок 1: Розгортання інфраструктури (Terraform)

```bash
cd lesson-6/terraform

# Закоментувати backend.tf (S3 ще не існує)
terraform init
terraform apply

# Розкоментувати backend.tf
terraform init -migrate-state
```

## Крок 2: Збірка та пуш Docker-образу в ECR

```bash
# Отримати URL ECR-репозиторію
ECR_URL=$(terraform -chdir=terraform output -raw ecr_repository_url)

# Авторизація в ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_URL

# Збірка образу
cd lesson-6
docker build -t django-app .

# Тегування та пуш
docker tag django-app:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

## Крок 3: Налаштування kubectl

```bash
# Оновити kubeconfig для підключення до кластера
aws eks update-kubeconfig --name eks-cluster-demo --region us-west-2

# Перевірка підключення
kubectl get nodes
```

## Крок 4: Деплой на Kubernetes

```bash
# Застосувати маніфести в правильному порядку
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/django-deployment.yaml

# Перевірка стану подів
kubectl get pods -n django-app
kubectl get svc -n django-app
```

## Крок 5: Доступ до застосунку

```bash
# Отримати зовнішню IP-адресу LoadBalancer
kubectl get svc django-service -n django-app

# Відкрити у браузері EXTERNAL-IP
```

## Основні команди

```bash
# Логи Django
kubectl logs -f deployment/django-app -n django-app

# Логи PostgreSQL
kubectl logs -f deployment/postgres -n django-app

# Масштабування
kubectl scale deployment django-app --replicas=3 -n django-app

# Видалення
kubectl delete -f k8s/
terraform -chdir=terraform destroy
```