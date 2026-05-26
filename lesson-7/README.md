# Домашнє завдання до теми «Вивчення Helm»

## Крок 1: Створення інфраструктури через Terraform

1. Перейдіть до папки `lesson-7`:
   ```bash
   cd lesson-7
   ```
2. Ініціалізуйте Terraform та застосуйте конфігурацію:
   ```bash
   terraform init
   terraform apply -auto-approve or terraform apply -lock=false
   ```
---

## Крок 2: Збірка та завантаження образу в ECR

1. Отримайте URL ECR-репозиторію з виводу Terraform:
   ```bash
   ECR_URL=$(terraform output -raw ecr_repository_url)
   echo "ECR URL: $ECR_URL"
   ```
2. Авторизуйте Docker в AWS ECR:
   ```bash
   aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_URL
   ```
3. Зберіть Docker-образ:
   ```bash
   cd ..
   docker build -t django-app:latest -f lesson-6/Dockerfile lesson-6/
   ```
4. Тегуйте та завантажте образ у ECR:
   ```bash
   docker tag django-app:latest "${ECR_URL}:latest"
   docker push "${ECR_URL}:latest"
   ```

---

## Крок 3: Налаштування підключення до EKS

1. Оновіть локальний `kubeconfig` для авторизації в EKS-кластері:
   ```bash
   aws eks update-kubeconfig --name eks-cluster-demo --region us-west-2
   ```
2. Перевірте підключення до кластера:
   ```bash
   kubectl get nodes
   ```

---

## Крок 4: Розгортання за допомогою Helm-чарта

Helm-чарт `django-app`, який налаштовує деплоймент, сервіс типу `LoadBalancer`, ConfigMap для змінних середовища та `HorizontalPodAutoscaler` (HPA).

1. Перевірте валідність чарта:
   ```bash
   helm lint lesson-7/charts/django-app
   ```
2. Встановіть Helm-чарт (наприклад, з назвою релізу `django-release` в окремому namespace):
   ```bash
   kubectl create namespace django-app || true
   
   helm install django-release lesson-7/charts/django-app \
     --namespace django-app \
     --set image.repository="${ECR_URL}" \
     --set image.tag=latest
   ```

---

## Крок 5: Перевірка роботи та автоматичного масштабування (HPA)

### 1. Перевірка статусів ресурсів
Перевірте створені поди, сервіс та HPA:
```bash
kubectl get all -n django-app
```

Ви повинні побачити щонайменше **2 поди** Django (згідно з параметром `minReplicas: 2` в HPA) та сервіс типу `LoadBalancer` із зовнішньою адресою (наприклад, `*.us-west-2.elb.amazonaws.com`).

### 2. Доступ до застосунку
Отримайте публічну адресу LoadBalancer:
```bash
kubectl get svc django-release-django -n django-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
Відкрийте отриману адресу у браузері або зробіть запит через `curl`.

### 3. Тестування HPA (Автомасштабування)
HPA налаштовано на підтримку середнього навантаження CPU на рівні **70%**. При перевищенні цього ліміту кількість подів буде автоматично збільшуватись (максимум до **6 подів**).

Для тестування навантаження можна запустити тимчасовий контейнер для генерації HTTP-запитів:
```bash
kubectl run apache-bench -i --tty --rm --image=httpd --namespace django-app -- \
  ab -n 500000 -c 100 http://django-release-django/
```

В іншому вікні термінала спостерігайте за реакцією HPA:
```bash
kubectl get hpa django-release-hpa -n django-app -w
```
Ви помітите, як показник `TARGETS` зросте за межі 70%, і Kubernetes почне піднімати нові поди (`REPLICAS` збільшиться з 2 до 3, 4, 5 або 6). Після завершення навантаження HPA поступово зменшить кількість подів назад до 2.

---

## (Бонус) Налаштування Ingress із TLS

У чарті передбачено шаблон [ingress.yaml](lesson-7/charts/django-app/templates/ingress.yaml), який інтегрується з `ingress-nginx` та `cert-manager` для автоматичного отримання SSL/TLS сертифікатів від Let's Encrypt.

Для увімкнення Ingress оновіть секцію у [values.yaml](lesson-7/charts/django-app/values.yaml):
```yaml
ingress:
  enabled: true
  className: nginx
  host: your-django-app.com
  path: /
  pathType: Prefix
  tls: true
```
Та оновіть реліз Helm:
```bash
helm upgrade django-release lesson-7/charts/django-app -n django-app \
  --set image.repository=$ECR_URL \
  --set image.tag=latest
```
