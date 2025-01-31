terraform {
  required_version = ">= 1.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
  }
}

# Create directories for persistent storage
resource "local_file" "storage_dirs" {
  for_each = toset([
    "n8n_storage",
    "postgres_storage",
    "ollama_storage",
    "qdrant_storage"
  ])
  filename = "${path.module}/storage/${each.value}/.keep"
  content  = ""

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/storage/${each.value}"
  }
}

# Build Singularity containers
resource "null_resource" "build_postgres_container" {
  depends_on = [local_file.storage_dirs]

  provisioner "local-exec" {
    command = "singularity build --fakeroot postgres.sif singularity/postgres.def"
  }

  triggers = {
    def_file = filemd5("${path.module}/singularity/postgres.def")
  }
}

resource "null_resource" "build_n8n_container" {
  depends_on = [local_file.storage_dirs]

  provisioner "local-exec" {
    command = "singularity build --fakeroot n8n.sif singularity/n8n.def"
  }

  triggers = {
    def_file = filemd5("${path.module}/singularity/n8n.def")
  }
}

resource "null_resource" "build_qdrant_container" {
  depends_on = [local_file.storage_dirs]

  provisioner "local-exec" {
    command = "singularity build --fakeroot qdrant.sif singularity/qdrant.def"
  }

  triggers = {
    def_file = filemd5("${path.module}/singularity/qdrant.def")
  }
}

resource "null_resource" "build_ollama_container" {
  depends_on = [local_file.storage_dirs]

  provisioner "local-exec" {
    command = "singularity build --fakeroot ollama.sif singularity/ollama.def"
  }

  triggers = {
    def_file = filemd5("${path.module}/singularity/ollama.def")
  }
}

# Variables
variable "postgres_user" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_db" {
  type    = string
  default = "n8n"
}

variable "n8n_encryption_key" {
  type      = string
  sensitive = true
}

variable "n8n_jwt_secret" {
  type      = string
  sensitive = true
}

variable "use_gpu" {
  type    = bool
  default = false
  description = "Whether to enable GPU support for Ollama"
}

# PostgreSQL Instance
resource "null_resource" "postgres_instance" {
  depends_on = [local_file.storage_dirs, null_resource.build_postgres_container]

  provisioner "local-exec" {
    command = "singularity instance start --bind ${path.module}/storage/postgres_storage:/var/lib/postgresql/data postgres.sif postgres"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance stop postgres || true"
  }
}

# Wait for PostgreSQL to be ready
resource "null_resource" "postgres_wait" {
  depends_on = [null_resource.postgres_instance]

  provisioner "local-exec" {
    command = "sleep 10"  # Simple wait for PostgreSQL to initialize
  }
}

# n8n Instance
resource "null_resource" "n8n_instance" {
  depends_on = [null_resource.postgres_wait, null_resource.build_n8n_container]

  provisioner "local-exec" {
    command = "singularity instance start --bind ${path.module}/storage/n8n_storage:/home/node/.n8n --bind shared:/data/shared n8n.sif n8n"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance stop n8n || true"
  }

  # Set environment variables for n8n
  triggers = {
    postgres_user     = var.postgres_user
    postgres_password = var.postgres_password
    postgres_db       = var.postgres_db
    encryption_key    = var.n8n_encryption_key
    jwt_secret        = var.n8n_jwt_secret
  }
}

# Qdrant Instance
resource "null_resource" "qdrant_instance" {
  depends_on = [local_file.storage_dirs, null_resource.build_qdrant_container]

  provisioner "local-exec" {
    command = "singularity instance start --bind ${path.module}/storage/qdrant_storage:/qdrant/storage qdrant.sif qdrant"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance stop qdrant || true"
  }
}

# Ollama Instance
resource "null_resource" "ollama_instance" {
  depends_on = [local_file.storage_dirs, null_resource.build_ollama_container]

  provisioner "local-exec" {
    command = var.use_gpu ? (
      "singularity instance start --nv --bind ${path.module}/storage/ollama_storage:/root/.ollama ollama.sif ollama"
    ) : (
      "singularity instance start --bind ${path.module}/storage/ollama_storage:/root/.ollama ollama.sif ollama"
    )
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance stop ollama || true"
  }

  triggers = {
    use_gpu = var.use_gpu
  }
}

# Output the storage paths for use in Singularity containers
output "storage_paths" {
  value = {
    for dir in local_file.storage_dirs : dir.filename => dirname(dir.filename)
  }
}

# Output service status
output "service_endpoints" {
  value = {
    n8n      = "http://localhost:5678"
    qdrant   = "http://localhost:6333"
    ollama   = "http://localhost:11434"
    postgres = "postgresql://localhost:5432"
  }
} 