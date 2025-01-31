# Self-Hosted AI Starter Kit with Terraform and Singularity

This repository contains a Terraform and Singularity-based deployment for running a self-hosted AI infrastructure stack. The stack includes n8n for workflow automation, PostgreSQL for database storage, Qdrant for vector storage, and Ollama for AI model serving.

## Prerequisites

- Terraform (>= 1.0.0)
- Singularity/Apptainer
- NVIDIA drivers and CUDA (for GPU support)

## Components

The deployment consists of the following services:

- **n8n**: Workflow automation platform
- **PostgreSQL**: Database for n8n
- **Qdrant**: Vector database for AI applications
- **Ollama**: AI model serving platform

## Directory Structure

```
.
├── main.tf                    # Terraform main configuration
├── terraform.tfvars.example   # Example Terraform variables
├── manage.sh                  # Management script for services
├── singularity/
│   ├── postgres.def          # PostgreSQL container definition
│   ├── n8n.def              # n8n container definition
│   ├── qdrant.def           # Qdrant container definition
│   └── ollama.def           # Ollama container definition
└── storage/                  # Persistent storage directories
    ├── n8n_storage/
    ├── postgres_storage/
    ├── ollama_storage/
    └── qdrant_storage/
```

## Setup Instructions

### 1. Initialize Terraform

Initialize Terraform to download required providers:

```bash
terraform init
```

### 2. Configure Variables

Copy the example variables file and configure it with your desired values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your preferred settings:

```hcl
postgres_user = "n8n"
postgres_password = "your_secure_password"
postgres_db = "n8n"
n8n_encryption_key = "your_encryption_key"
n8n_jwt_secret = "your_jwt_secret"
```

### 3. Apply Terraform Configuration

Create the necessary infrastructure:

```bash
terraform apply
```

### 4. Prepare Management Script

Make the management script executable:

```bash
chmod +x manage.sh
```

### 5. Build Containers

Build all Singularity containers:

```bash
./manage.sh build
```

### 6. Start Services

Start all services in either CPU or GPU mode:

```bash
# For CPU-only mode
./manage.sh start cpu

# For GPU support
./manage.sh start gpu
```

### 7. Stop Services

To stop all running services:

```bash
./manage.sh stop
```

## Service Access

After starting the services, they will be available at the following addresses:

- n8n: http://localhost:5678
- Qdrant: http://localhost:6333
- Ollama: http://localhost:11434
- PostgreSQL: localhost:5432

## Environment Variables

The system uses the following environment variables, which can be set in `terraform.tfvars`:

- `postgres_user`: PostgreSQL username
- `postgres_password`: PostgreSQL password
- `postgres_db`: PostgreSQL database name
- `n8n_encryption_key`: Encryption key for n8n
- `n8n_jwt_secret`: JWT secret for n8n user management

## Storage

Persistent storage is managed through bind mounts in the following directories:

- `storage/n8n_storage`: n8n data and configurations
- `storage/postgres_storage`: PostgreSQL database files
- `storage/ollama_storage`: Ollama model storage
- `storage/qdrant_storage`: Qdrant vector database storage

## GPU Support

GPU support is available for Ollama when starting services with the `gpu` parameter. This requires:

1. NVIDIA drivers installed on the host system
2. CUDA toolkit
3. Singularity built with GPU support

To use GPU support:

```bash
./manage.sh start gpu
```

## Troubleshooting

1. **Service Startup Issues**
   - Check service logs using `singularity instance list` to verify running instances
   - Ensure all required ports are available
   - Verify storage directories have correct permissions

2. **Database Connection Issues**
   - Ensure PostgreSQL is fully initialized before starting n8n
   - Verify database credentials in `terraform.tfvars`

3. **GPU Support**
   - Run `nvidia-smi` to verify GPU is properly recognized
   - Ensure Singularity is built with GPU support
   - Check CUDA toolkit installation

## Notes

- The services communicate via localhost since Singularity containers share the host network namespace
- Environment variables are managed through Terraform and passed to containers
- GPU support is handled through Singularity's `--nv` flag
- Service orchestration is managed through the shell script instead of Docker Compose

## Security Considerations

1. Always change default passwords and secrets in `terraform.tfvars`
2. Keep your `terraform.tfvars` file secure and never commit it to version control
3. Consider implementing additional network security measures for production deployments
4. Regularly update container images for security patches
