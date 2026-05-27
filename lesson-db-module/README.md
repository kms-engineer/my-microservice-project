# Урок DB-Module — Гнучкий Terraform-модуль для баз даних

## Мета

Створити **універсальний продакшн-готовий модуль `rds`**, який вміє розгортати:

- **Звичайну RDS-базу** (`aws_db_instance`) — PostgreSQL / MySQL
- **Aurora-кластер** (`aws_rds_cluster` + `aws_rds_cluster_instance`)

Перемикання — одним прапором `use_aurora = true|false`. Решта змінних залишаються тими ж самими, що дозволяє багаторазово використовувати модуль у різних середовищах (dev / stage / prod).

## Як змінити тип БД, engine, клас інстансу

### Перемкнути RDS ↔ Aurora

У `main.tf` або через CLI:

```bash
# Aurora
terraform apply -var="use_aurora=true"

# Звичайна RDS
terraform apply -var="use_aurora=false"
```

> **Увага:** перемикання після створення = знищення + перестворення БД. Робіть бекап.

### Змінити engine на MySQL

```hcl
engine         = "mysql"
engine_version = "8.0"
family         = "mysql8.0"
port           = 3306
```

### Збільшити клас інстансу

```hcl
instance_class = "db.t3.large"   # було db.t3.micro
```

### Додати реплік у Aurora

```hcl
aurora_instance_count = 3   # 1 writer + 2 readers
```

### Змінити параметри (max_connections, work_mem...)

```hcl
parameter_group_parameters = {
  max_connections = "500"
  log_statement   = "ddl"
  work_mem        = "8192"
  shared_buffers  = "256MB"
}
```

Зверніть увагу: деякі параметри потребують перезапуску інстансу (`apply_immediately = true` вже виставлено в модулі).

---

## Як запустити

### 1. Передайте пароль БД через ENV

```bash
export TF_VAR_db_password='SuperSecret123!'
```

### 2. Ініціалізація

```bash
cd lesson-db-module
terraform init
```

### 3. Plan

```bash
# Звичайна RDS (за замовчуванням)
terraform plan -lock=false

# Aurora
terraform plan -lock=false -var="use_aurora=true"
```

### 4. Apply

```bash
terraform apply -lock=false -auto-approve
```

### 5. Перевірка

```bash
# Endpoint бази
terraform output db_endpoint
terraform output db_port

# Перевірити з EC2/EKS-поду в тому ж VPC
psql -h $(terraform output -raw db_endpoint) -p 5432 -U dbadmin -d appdb
```

### 6. Видалення

```bash
terraform destroy -auto-approve -lock=false
```