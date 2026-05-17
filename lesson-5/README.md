# Lesson 5 — Terraform Infrastructure on AWS

Terraform-проєкт для розгортання інфраструктури на AWS з модульним підходом.

## Структура проєкту

```
lesson-5/
├── main.tf              # Підключення модулів
├── backend.tf           # Бекенд для стейтів (S3 + DynamoDB)
├── outputs.tf           # Виведення ресурсів
├── modules/
│   ├── s3-backend/      # S3-бакет та DynamoDB для стейтів
│   ├── vpc/             # VPC, підмережі, шлюзи, маршрутизація
│   └── ecr/             # ECR-репозиторій для Docker-образів
└── README.md
```

## Модулі

**s3-backend** — створює S3-бакет з версіюванням для зберігання Terraform state та DynamoDB-таблицю для блокування стейтів.

**vpc** — розгортає VPC (10.0.0.0/16) з 3 публічними та 3 приватними підмережами, Internet Gateway, NAT Gateway та маршрутизацією.

**ecr** — створює ECR-репозиторій з автоматичним скануванням образів та lifecycle-політикою.

## Запуск

```bash
# 1. Закоментувати backend.tf (S3 ще не існує)
# 2. Ініціалізація та створення ресурсів
terraform init
terraform apply

# 3. Розкоментувати backend.tf
# 4. Перенести стейт у S3
terraform init -migrate-state
```

## Основні команди

```bash
terraform init       # Ініціалізація
terraform plan       # Перегляд змін
terraform apply      # Застосування змін
terraform destroy    # Видалення ресурсів
```

## Відновлення після destroy

1. Закоментувати `backend.tf`
2. `terraform init` → `terraform apply`
3. Розкоментувати `backend.tf`
4. `terraform init -reconfigure`
