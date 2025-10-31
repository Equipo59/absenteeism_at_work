# Terraform Infrastructure

Infraestructura AWS para el proyecto Absenteeism API.

## 🏗️ Componentes Creados

- **VPC**: Red virtual aislada
- **Internet Gateway**: Acceso a internet
- **Public Subnet**: Subnet pública para EC2
- **Security Group**: Reglas de firewall (puertos 22, 80, 8000)
- **EC2 Instance**: Instancia para la API

## 🚀 Uso

### Configuración Inicial

```bash
cd infrastructure/terraform

# Copiar ejemplo de variables
cp terraform.tfvars.example terraform.tfvars

# Editar con tus valores
nano terraform.tfvars
```

### Aplicar Infraestructura

```bash
terraform init
terraform plan
terraform apply
```

### Ver Outputs

```bash
terraform output
```

### Destruir Infraestructura

```bash
terraform destroy
```

## 📝 Variables

| Variable | Descripción | Default |
|----------|-------------|---------|
| `aws_region` | Región AWS | `us-east-1` |
| `ec2_instance_type` | Tipo de instancia | `t3.micro` |
| `ec2_ami_id` | AMI ID (auto-detect si vacío) | `""` |
| `ec2_key_name` | Nombre del key pair | `""` |

## 🔍 AMI Auto-detección

Si `ec2_ami_id` está vacío, Terraform automáticamente encontrará el AMI más reciente de Ubuntu 22.04 LTS para tu región.

## 🔒 Seguridad

- Security Group permite:
  - SSH (22) desde cualquier IP
  - HTTP (80) desde cualquier IP
  - API (8000) desde cualquier IP

**⚠️ En producción, limita SSH solo a tu IP.**

