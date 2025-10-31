# CloudFormation Infrastructure

Infrastructura AWS para el proyecto Absenteeism API usando ECS Fargate.

## 🏗️ Componentes Creados

- **VPC**: Red virtual aislada (10.0.0.0/16)
- **Internet Gateway**: Acceso a internet
- **Public Subnets**: 2 subnets públicas en diferentes AZs
- **Application Load Balancer**: Balanceador para la API
- **Target Group**: Grupo de destino en puerto 8000
- **ECS Cluster**: Cluster Fargate
- **ECS Service**: Servicio con 1 tarea
- **Task Definition**: Definición de contenedor (256 CPU, 512MB RAM)
- **Security Groups**: Reglas de firewall para ALB y ECS
- **IAM Roles**: Roles para ejecución y tareas ECS
- **CloudWatch Logs**: Logs centralizados

## 🚀 Deployment

### Despliegue Automático (GitHub Actions)

El despliegue se ejecuta automáticamente al hacer push a la rama `web`:

```bash
git checkout web
git merge master
git push origin web
```

### Despliegue Manual

```bash
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/infrastructure.yaml \
  --stack-name absenteeism-infrastructure \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EnvironmentName=production \
    ContainerImage=ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/absenteeism-api:latest \
  --region us-east-1
```

### Ver Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name absenteeism-infrastructure \
  --query 'Stacks[0].Outputs' \
  --output table
```

### Destruir Infraestructura

```bash
aws cloudformation delete-stack --stack-name absenteeism-infrastructure
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
Docker Container (FastAPI)
   ↓
CloudWatch Logs
```

## 🔒 Seguridad

- Security Groups restringen el tráfico:
  - ALB: HTTP (80) y API (8000) desde internet
  - ECS: Solo tráfico desde ALB en puerto 8000
- IAM roles con permisos mínimos necesarios
- Contenedores aislados en red VPC privada

## 📝 Parámetros

| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `EnvironmentName` | Nombre del entorno | `production` |
| `ContainerImage` | URI de la imagen Docker | `absenteeism-api:latest` |

## 💰 Costos Estimados

- ECS Fargate: ~$15/mes (1 task, 24/7)
- Application Load Balancer: ~$16/mes
- NAT Gateway: No necesario (Public IP en Fargate)
- CloudWatch Logs: ~$0.50/mes
- **Total: ~$31/mes**

## ⚠️ Notas

- El servicio inicia con 1 tarea. Para producción, considera aumentar a 2+ tareas.
- Los logs se retienen por 7 días. Ajusta `RetentionInDays` según necesites.
- Health checks verifican `/health` cada 30 segundos.

