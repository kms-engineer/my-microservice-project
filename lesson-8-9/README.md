# Урок 8-9 — Домашнє завдання: Argo CD + CI/CD

## Мета

Реалізувати повний CI/CD-процес із використанням **Jenkins + Helm + Terraform + Argo CD**, який:

1. Автоматично збирає Docker-образ для Django-застосунку
2. Публікує образ в Amazon ECR
3. Оновлює Helm chart у репозиторії з правильним тегом
4. Синхронізує застосунок у кластері через Argo CD, який підхоплює зміни з Git

---

### Ключові можливості:
- **Auto Sync** — автоматична синхронізація при зміні в Git
- **Self Heal** — автоматичне відновлення стану, якщо хтось вручну змінив ресурси
- **Prune** — видалення ресурсів, яких більше немає в Git
- **Web UI** — наглядний інтерфейс для моніторингу стану застосунків

---

## Архітектура CI/CD

```text
Developer → Git Push → Jenkins (CI)  → Docker Build (Kaniko) → Push to ECR
                                     → Update values.yaml (image tag)
                                     → Git Push (updated tag)
Argo CD (CD)                         → Detects Git change → Sync to Kubernetes
```

---

## Компоненти рішення

### 1. Jenkins (CI)

Jenkins встановлено через Helm і автоматично налаштовано через JCasC:
- **Seed Job** — автоматично створює pipeline `goit-django-docker`
- **Kaniko** — збирає Docker-образи без Docker daemon
- **IRSA** — безпечний доступ до ECR через IAM роль

**CI Pipeline (Jenkinsfile):**
1. Клонує Git-репозиторій
2. Збирає Docker-образ через Kaniko
3. Пушить образ до ECR
4. Оновлює `image.tag` у `charts/django-app/values.yaml`
5. Пушить оновлений values.yaml назад у Git

### 2. Django Application

Django-застосунок розгортається автоматично через Argo CD:
- **PostgreSQL** — розгортається автоматично разом із Django в одному namespace (шаблон `postgres.yaml` у Helm-чарті)
- **Міграції БД** — виконуються автоматично при старті контейнера (`python manage.py migrate --noinput`) перед запуском Gunicorn
- **Helm chart** — містить усі необхідні ресурси: Deployment, Service, ConfigMap, HPA, PostgreSQL

### 3. Argo CD (CD)

Argo CD встановлено через Helm і автоматично створює Application:
- **Application** `django-app` — стежить за `charts/django-app/` у Git
- **Auto Sync** — при зміні values.yaml (нового тегу) автоматично деплоїть
- **Self Heal** + **Prune** — відновлює стан та прибирає зайві ресурси

### 4. Argo CD Application Template

```yaml
spec:
  source:
    repoURL: https://github.com/kms-engineer/my-microservice-project.git
    targetRevision: lesson-8-9
    path: charts/django-app
  destination:
    server: https://kubernetes.default.svc
    namespace: django
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Ресурси Terraform

| Модуль | Ресурс | Призначення |
|--------|--------|-------------|
| **jenkins** | `helm_release.jenkins` | Jenkins v5.8.27 через Helm |
| **jenkins** | `kubernetes_storage_class_v1.ebs_sc` | StorageClass ebs-sc (gp3) |
| **jenkins** | `aws_iam_role.jenkins_kaniko_role` | IAM роль для Kaniko (IRSA) |
| **jenkins** | `aws_iam_role_policy.jenkins_ecr_policy` | Дозволи на push до ECR |
| **jenkins** | `kubernetes_service_account.jenkins_sa` | SA з анотацією IRSA |
| **argo_cd** | `helm_release.argo_cd` | Argo CD v7.8.26 через Helm |
| **argo_cd** | `helm_release.argo_cd_apps` | Application + Repository через локальний чарт |

---

## Кроки виконання

### Крок 1: Як застосувати Terraform

1. Перейдіть до директорії проєкту:
   ```bash
   cd lesson-8-9
   ```

2. Ініціалізуйте Terraform (завантажить провайдери та модулі):
   ```bash
   terraform init
   ```

3. (Опціонально) Перевірте план змін перед застосуванням:
   ```bash
   terraform plan -lock=false
   ```

4. Застосуйте конфігурацію:
   ```bash
   terraform apply -lock=false -auto-approve
   ```

5. Після завершення підключіться до кластера:
   ```bash
   aws eks update-kubeconfig --name eks-cluster-demo --region us-west-2
   ```

6. Перевірте, що всі поди запущені:
   ```bash
   kubectl get pods -A
   ```
   Очікуваний результат — поди в namespace `jenkins`, `argocd` та `kube-system` у статусі `Running`.

---

### Крок 2: Як перевірити Jenkins job

1. **Отримайте URL Jenkins:**
   ```bash
   kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
   Скопіюйте hostname та відкрийте у браузері: `http://<hostname>`

2. **Увійдіть в Jenkins UI:**
   - **Username:** `admin`
   - **Password:** `admin123`

3. **Запустіть seed-job:**
   - На головній сторінці Jenkins побачите job **`seed-job`**
   - Натисніть на нього → **Build Now** (ліве меню)
   - Зачекайте, поки збірка завершиться
   - Seed-job автоматично створить pipeline **`goit-django-docker`**

4. **⚠️ Налаштуйте GitHub PAT (обов'язково перед першим запуском CI!):**
   - У `values.yaml` використовується placeholder-токен для безпеки (щоб не зберігати секрет у Git)
   - Перейдіть: **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
   - Знайдіть credential з ID **`github-token`** та натисніть іконку редагування
   - У полі **Password** вставте ваш реальний GitHub Personal Access Token (PAT)
     - Створити PAT: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token
     - Необхідний scope: **`repo`** (повний доступ до репозиторіїв)
   - Натисніть **Save**

5. **Запустіть CI pipeline:**
   - Поверніться на головну сторінку Jenkins
   - Відкрийте новостворений job **`goit-django-docker`**
   - Натисніть **Build Now**
   - Pipeline виконає:
     - Клонування Git-репозиторію
     - Збірку Docker-образу через Kaniko
     - Push образу до Amazon ECR
     - Оновлення `image.tag` у `charts/django-app/values.yaml`
     - Push оновленого values.yaml назад у Git

6. **Перевірте логи збірки:**
   - Натисніть на номер збірки (наприклад, `#1`) у Build History
   - Натисніть **Console Output**
   - Переконайтеся, що всі етапи пройшли без помилок

---

### Крок 3: Як побачити результат в Argo CD

1. **Отримайте URL Argo CD:**
   ```bash
   kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
   Відкрийте у браузері: `http://<hostname>`

2. **Отримайте пароль адміністратора:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

3. **Увійдіть в Argo CD UI:**
   - **Username:** `admin`
   - **Password:** результат команди вище

4. **Перевірте Application:**
   - На головній сторінці Argo CD побачите application **`django-app`**
   - Статус повинен бути:
     - **Sync Status:** `Synced` — стан у кластері відповідає Git
     - **Health Status:** `Healthy` — всі ресурси працюють
   - Натисніть на application, щоб побачити дерево ресурсів:
     - `Deployment` → `ReplicaSet` → `Pod(s)`
     - `Service` (LoadBalancer)
     - `ConfigMap`
     - `HorizontalPodAutoscaler`

5. **Як працює автоматична синхронізація:**
   - Коли Jenkins пушить оновлений `image.tag` у Git
   - Argo CD автоматично виявляє зміну (кожні ~3 хвилини)
   - Argo CD оновлює Deployment з новим образом
   - Поди перезапускаються з новою версією
   - Статус повертається до `Synced` + `Healthy`

6. **Перевірка через CLI:**
   ```bash
   # Статус application
   kubectl get applications -n argocd

   # Поди Django-застосунку
   kubectl get pods -n django

   # Сервіс Django (URL для доступу)
   kubectl get svc -n django
   ```

---

## Видалення всіх ресурсів

Після перевірки обов'язково видаліть усі ресурси, щоб уникнути зайвих витрат:

```bash
terraform destroy -auto-approve -lock=false
```
