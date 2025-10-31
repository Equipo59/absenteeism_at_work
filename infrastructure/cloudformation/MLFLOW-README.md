# MLflow Tracking Server Infrastructure

Infrastructura AWS para el servidor de tracking MLflow usando ECS Fargate.

## 🏗️ Componentes Creados

- **Security Groups**: Reglas de firewall para ALB y ECS
- **Application Load Balancer**: Balanceador para la UI de MLflow
- **Target Group**: Grupo de destino en puerto 5000
- **ECS Cluster**: Cluster Fargate dedicado
- **ECS Service**: Servicio con 1 tarea
- **Task Definition**: Definición de contenedor (256 CPU, 512MB RAM)
- **IAM Roles**: Roles para ejecución y tareas ECS
- **CloudWatch Logs**: Logs centralizados

## 🔗 Integración con Infraestructura Principal

Este stack utiliza la infraestructura principal (`absenteeism-infrastructure`) como referencia:

- **VPC**: Usa la misma VPC
- **Subnets**: Usa las mismas subnets públicas
- **Isolated**: Security groups y load balancer independientes

## 🚀 Deployment

### Despliegue Automático (GitHub Actions)

El despliegue se ejecuta automáticamente al hacer push a la rama `master`:

```bash
git checkout master
git add .
git commit -m "Deploy MLflow"
git push origin master
```

### Despliegue Manual

**Requisitos previos:**
1. Debe existir el stack `absenteeism-infrastructure`
2. Obtener VPC ID y Subnet IDs del stack principal

```bash
# Obtener VPC ID
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name absenteeism-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' \
  --output text \
  --region us-east-1)

# Obtener Subnet IDs
SUBNET1=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=production-public-subnet-1" \
  --query 'Subnets[0].SubnetId' \
  --output text)

SUBNET2=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=production-public-subnet-2" \
  --query 'Subnets[0].SubnetId' \
  --output text)

# Desplegar
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/mlflow-infrastructure.yaml \
  --stack-name mlflow-infrastructure \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EnvironmentName=production \
    ContainerImage=ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mlflow-tracking:latest \
    VPCId=$VPC_ID \
    PublicSubnet1Id=$SUBNET1 \
    PublicSubnet2Id=$SUBNET2 \
  --region us-east-1
```

### Ver Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name mlflow-infrastructure \
  --query 'Stacks[0].Outputs' \
  --output table
```

### Destruir Infraestructura

```bash
aws cloudformation delete-stack --stack-name mlflow-infrastructure
```

## 📊 Arquitectura

```
Internet
   ↓
Application Load Balancer (ALB)
   ↓
Target Group (Health check: /health)
   ↓
ECS Fargate Service
   ↓
Docker Container (MLflow)
   ↓
CloudWatch Logs
```

## 🔒 Seguridad

- Security Groups restringen el tráfico:
  - ALB: HTTP (80) y MLflow (5000) desde internet
  - ECS: Solo tráfico desde ALB en puerto 5000
- IAM roles con permisos mínimos necesarios
- Contenedores aislados en red VPC

## 📝 Parámetros

| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `EnvironmentName` | Nombre del entorno | `production` |
| `ContainerImage` | URI de la imagen Docker | `mlflow-tracking:latest` |
| `VPCId` | ID de la VPC | (requerido) |
| `PublicSubnet1Id` | ID de la primera subnet pública | (requerido) |
| `PublicSubnet2Id` | ID de la segunda subnet pública | (requerido) |

## 💰 Costos Estimados

- ECS Fargate: ~$15/mes (1 task, 24/7)
- Application Load Balancer: ~$16/mes
- CloudWatch Logs: ~$0.50/mes
- **Total: ~$31/mes**

## ⚠️ Notas

- El servicio inicia con 1 tarea.
- Los logs se retienen por 7 días.
- Health checks verifican `/health` cada 30 segundos.
- El storage es local al contenedor (se pierde al reiniciar). Para producción, considerar S3 backend.

## 🔄 Storage Persistente (Recomendado para Producción)

Para almacenar experiments y artifacts de forma persistente:

1. Crear un bucket S3 para MLflow
2. Modificar la Task Definition para montar un volumen EFS o usar S3 como backend

```yaml
Environment:
  - Name: MLFLOW_BACKEND_STORE_URI
    Value: sqlite:///mlflow/mlruns/db.sqlite
  - Name: MLFLOW_DEFAULT_ARTIFACT_ROOT
    Value: s3://your-mlflow-bucket/artifacts/
```

