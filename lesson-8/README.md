# Урок 8 — Jenkins: інсталяція та налаштування в Kubernetes

Цей проєкт демонструє встановлення та налаштування **Jenkins** у кластері Amazon EKS за допомогою **Terraform** та **Helm**. Також реалізовано налаштування **AWS EBS CSI Driver** для динамічного створення постійних дисків (Persistent Volumes) у хмарі AWS з використанням OIDC та IRSA.

---

## Що таке Jenkins?

**Jenkins** — це один із найпопулярніших інструментів автоматизації з відкритим кодом для реалізації процесів CI/CD (Continuous Integration / Continuous Delivery). Він дозволяє автоматизувати збірку, тестування, створення Docker-образів та деплой застосунків.

У цьому уроці Jenkins розгортається безпосередньо у кластері Kubernetes, використовуючи офіційний Helm-чарт.

---

## Мережеве сховище та AWS EBS CSI Driver

Для збереження налаштувань, збірок та даних користувачів Jenkins потребує постійного сховища (**Persistent Volume**).

У хмарі AWS для динамічного створення дисків (EBS) під запити Kubernetes-додатків використовується **AWS EBS CSI Driver**. У цьому проєкті його інтеграцію реалізовано за допомогою безпечного механізму **IRSA** (IAM Roles for Service Accounts):

1. **OIDC Provider** підтверджує автентичність запитів від Kubernetes-кластера до AWS.
2. Створюється IAM-роль `ebs-csi-irsa-role` із підключеною політикою `AmazonEBSCSIDriverPolicy`.
3. Спеціальний сервіс-акаунт (`ebs-csi-controller-sa`) отримує права на створення та монтування дисків AWS EBS «на льоту».

Завдяки цьому статус `PersistentVolumeClaim` (PVC) для Jenkins автоматично перейде в `Bound`, і йому виділиться 10 Гб дискового простору.

---

## Що таке Kaniko?

**Kaniko** — це утиліта, яка дозволяє створювати Docker-образи всередині контейнера без доступу до Docker-демона. Kaniko читає `Dockerfile`, збирає образ і пушить його напряму до реєстру (наприклад, Amazon ECR).

Це безпечніше та зручніше в Kubernetes-середовищах, бо не вимагає запуску Docker-in-Docker або root-доступу.

У Jenkins CI/CD пайплайнах Kaniko дозволяє:
1. Будувати образи
2. Пушити до ECR
3. Не турбуватись про демони, привілеї чи root

---

## Структура модулів Terraform у `lesson-8`

```text
lesson-8/
├── main.tf                  # Головний файл (підключення модулів vpc, ecr, eks, jenkins)
├── backend.tf               # Віддалений стейт Terraform в S3 + DynamoDB
├── outputs.tf               # Кореневі виводи (URL-адреси, релізи)
└── modules/
    ├── s3-backend/          # S3-бакет та DynamoDB
    ├── vpc/                 # Мережева інфраструктура
    ├── ecr/                 # Реєстр ECR для Django
    ├── eks/                 # Кластер EKS
    │   ├── eks.tf           # Конфігурація EKS та Node Group
    │   └── aws_ebs_csi_driver.tf # ✅ Налаштування OIDC, IAM IRSA ролі та EBS CSI Driver Addon
    └── jenkins/             # ✅ Модуль розгортання Jenkins через Helm
        ├── jenkins.tf       # StorageClass, IAM роль (Kaniko), ECR policy, Service Account, Helm release
        ├── values.yaml      # Налаштування Jenkins (плагіни, JCasC, credentials, seed-job)
        ├── variables.tf     # Опис змінних модуля (cluster_name, OIDC)
        ├── providers.tf     # Опис провайдерів (helm, kubernetes, aws)
        └── outputs.tf       # Вихідні змінні модуля
```

---

## Ресурси Jenkins-модуля (`jenkins.tf`)

| Ресурс | Призначення |
|--------|-------------|
| `kubernetes_storage_class_v1.ebs_sc` | StorageClass `ebs-sc` (gp3) для динамічного створення EBS-томів |
| `aws_iam_role.jenkins_kaniko_role` | IAM-роль для Jenkins agent (Kaniko) з IRSA |
| `aws_iam_role_policy.jenkins_ecr_policy` | Політика доступу до ECR (push образів) |
| `kubernetes_service_account.jenkins_sa` | Service Account з анотацією IRSA для Jenkins |
| `helm_release.jenkins` | Helm-реліз Jenkins v5.8.27 |

---

## Плагіни, які встановлюються в Jenkins

Через конфігурацію `values.yaml` автоматично встановлюються наступні розширення:

| Плагін | Призначення |
|--------|-------------|
| **kubernetes** | Створення динамічних агентів-подів для збірки коду |
| **workflow-aggregator** | Підтримка Pipeline-as-Code (`Jenkinsfile`) |
| **git** / **github** | Інтеграція з Git-репозиторіями |
| **configuration-as-code** (JCasC) | Опис налаштувань Jenkins у YAML |
| **credentials-binding** | Безпечна передача секретів у збірки |
| **docker-plugin** / **docker-workflow** | Робота з Docker у пайплайнах |
| **job-dsl** | Автоматичне створення job'ів через код |

---

## Jenkins Configuration as Code (JCasC)

### Credentials

Автоматично створюється `usernamePassword` credential з ID `github-token`:
- **username**: GitHub юзернейм
- **password**: GitHub PAT (Personal Access Token)

### Seed Job

Автоматично створюється job `seed-job`, який:
1. Клонує `infra` репозиторій з GitHub
2. Використовує `github-token` credentials для доступу
3. Створює pipeline `goit-django-docker`, який читає `Jenkinsfile` із репозиторію

---

## Jenkinsfile (CI-процес)

Pipeline використовує Kaniko для збірки Docker-образу та пушу в ECR:

```groovy
pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-sa
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.16.0-debug
      command: ["sleep"]
      args: ["99d"]
"""
    }
  }

  environment {
    ECR_REGISTRY = "<account-id>.dkr.ecr.us-west-2.amazonaws.com"
    IMAGE_NAME   = "app"
    IMAGE_TAG    = "latest"
  }

  stages {
    stage('Build & Push Docker Image') {
      steps {
        container('kaniko') {
          sh '/kaniko/executor --context `pwd` --dockerfile `pwd`/Dockerfile --destination=$ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG --cache=true'
        }
      }
    }
  }
}
```

---

## Крок 1: Запуск інфраструктури та деплой Jenkins

Перейдіть до директорії `lesson-8` та запустіть розгортання:

```bash
cd lesson-8
terraform init
terraform apply -lock=false -auto-approve
```

*Примітка: Флаг `-lock=false` використовується для спрощення першого запуску, якщо таблиця DynamoDB створюється вперше.*

---

## Крок 2: Перевірка роботи та підключення до Jenkins

1. Оновіть `kubeconfig` для авторизації в EKS-кластері:
   ```bash
   aws eks update-kubeconfig --name eks-cluster-demo --region us-west-2
   ```

2. Перевірте статус подів у namespace `jenkins` (зачекайте, поки под перейде у статус `Running`):
   ```bash
   kubectl get pods -n jenkins
   ```

3. Перевірте PersistentVolumeClaim (переконайтеся, що диск успішно примонтовано):
   ```bash
   kubectl get pvc -n jenkins
   ```
   Статус має змінитися з `Pending` на **`Bound`** завдяки роботі EBS CSI драйвера.

---

## Крок 3: Доступ до веб-інтерфейсу Jenkins

1. Отримайте публічну адресу LoadBalancer, виділену для Jenkins:
   ```bash
   kubectl get svc -n jenkins
   ```
   Або скористайтеся виводом конкретного hostname:
   ```bash
   kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. Відкрийте отриману URL-адресу у браузері на порту **80** (наприклад, `http://<external-dns-name>`).

3. **Дані для входу** (налаштовані за замовчуванням у `values.yaml`):
   - **Username**: `admin`
   - **Password**: `admin123`

---

## Крок 4: Запуск CI-пайплайну

1. Після входу в Jenkins UI побачите job `seed-job`
2. Натисніть **Build Now** — seed-job створить pipeline `goit-django-docker`
3. Pipeline автоматично клонує репозиторій, збирає Docker-образ через Kaniko та пушить його в ECR
