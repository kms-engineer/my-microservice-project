# Lesson 7 — Створення власного Helm-чарта для Django-проєкту

Власний Helm-чарт для розгортання Django-застосунку на Kubernetes.

## Структура чарта

```
lesson-7/
└── django-chart/
    ├── Chart.yaml              # Опис чарта (назва, версія)
    ├── values.yaml             # Конфігурації за замовчуванням
    └── templates/              # Шаблони Kubernetes-ресурсів
        ├── deployment.yaml     # Deployment для Django
        ├── service.yaml        # Service (ClusterIP)
        ├── configmap.yaml      # ConfigMap зі змінними середовища
        └── ingress.yaml        # Ingress (опціонально, для доступу через домен)
```

## Що робить кожен файл

| Файл | Призначення |
|------|-------------|
| `Chart.yaml` | Метадані чарта: назва, версія, опис |
| `values.yaml` | Значення за замовчуванням: образ, порт, конфігурація БД |
| `templates/deployment.yaml` | Pod з Django-контейнером, env з ConfigMap |
| `templates/service.yaml` | Kubernetes Service (порт 80 → 8000) |
| `templates/configmap.yaml` | Змінні середовища для Django (Postgres config) |
| `templates/ingress.yaml` | Доступ через домен (вимкнено за замовчуванням) |

## Налаштування

### 1. Вказати свій Docker-образ

Відредагуйте `values.yaml`:

```yaml
image:
  repository: <AWS_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/lesson-6-ecr
  tag: latest
```

### 2. Налаштувати підключення до бази даних

```yaml
config:
  POSTGRES_HOST: db
  POSTGRES_PORT: "5432"
  POSTGRES_USER: django_user
  POSTGRES_DB: django_db
  POSTGRES_PASSWORD: pass9764gd
```

### 3. (Опціонально) Увімкнути Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  host: django.example.com
  path: /
  pathType: Prefix
  tls: true
```

## Команди

```bash
# Перехід у директорію чарта
cd lesson-7/django-chart

# Встановлення чарта в кластер
helm install my-django .

# Перевірка статусу
helm list
kubectl get pods
kubectl get svc

# Оновлення після змін
helm upgrade my-django .

# Видалення
helm uninstall my-django
```

## Результат

Після `helm install` у кластері з'являться:
- **Deployment** `my-django-django` — pod з Django-контейнером
- **Service** `my-django-django` — ClusterIP-сервіс на порту 80
- **ConfigMap** `my-django-config` — змінні середовища для Django
- **Ingress** (якщо `ingress.enabled: true`) — доступ через домен

## Корисні команди Helm

```bash
# Перегляд згенерованих маніфестів без встановлення
helm template my-django .

# Перевірка чарта на помилки
helm lint .

# Перегляд історії релізів
helm history my-django
```
