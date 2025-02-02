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
resource "null_resource" "storage_dirs" {
  for_each = toset([
    "n8n_storage",
    "n8n_shared",
    "postgres_storage/data",
    "postgres_storage/run",
    "postgres_storage/log",
    "ollama_storage",
    "qdrant_storage",
    "neo4j_storage/data",
    "neo4j_storage/logs",
    "neo4j_storage/conf"
  ])

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/storage/${each.value}
      chmod 0750 ${path.module}/storage/${each.value}
    EOT
  }

  # This ensures the directories are only created once and not deleted on destroy
  triggers = {
    dir_path = "${path.module}/storage/${each.value}"
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

variable "neo4j_password" {
  type      = string
  sensitive = true
  description = "Password for Neo4j admin user"
}

# PostgreSQL Instance
resource "null_resource" "postgres_instance" {
  depends_on = [null_resource.storage_dirs]

  provisioner "local-exec" {
    command = <<-EOT
      singularity instance start \
        --containall \
        --bind ${path.module}/storage/postgres_storage/data:/var/lib/postgresql/data \
        --bind ${path.module}/storage/postgres_storage/run:/var/run/postgresql \
        --bind ${path.module}/storage/postgres_storage/log:/var/log/postgresql \
        --env POSTGRES_DB=${var.postgres_db} \
        --env POSTGRES_USER=${var.postgres_user} \
        --env POSTGRES_PASSWORD=${var.postgres_password} \
        postgres.sif \
        postgres
      sleep 3
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance list | grep postgres -q && singularity instance stop postgres || true"
  }
}

# Create n8n environment file
resource "local_file" "n8n_env_file" {
  depends_on = [null_resource.storage_dirs]
  filename = "${path.module}/storage/env-file.txt"
  content = <<-EOT
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=localhost
DB_POSTGRESDB_USER=${var.postgres_user}
DB_POSTGRESDB_PASSWORD=${var.postgres_password}
N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
N8N_ENCRYPTION_KEY=${var.n8n_encryption_key}
N8N_USER_MANAGEMENT_JWT_SECRET=${var.n8n_jwt_secret}
N8N_USER_FOLDER=/home/node/
N8N_CONFIG_FILES=/home/node/.n8n/config.json
EOT
  file_permission = "0600"
}

# Create n8n config file
resource "local_file" "n8n_config_file" {
  depends_on = [null_resource.storage_dirs]
  filename = "${path.module}/storage/n8n_storage/config.json"
  content = jsonencode({
    "encryptionKey" = var.n8n_encryption_key
  })
  file_permission = "0600"
}

# n8n Instance
resource "null_resource" "n8n_instance" {
  depends_on = [null_resource.postgres_instance, local_file.n8n_env_file]

  provisioner "local-exec" {
    command = <<-EOT
      singularity instance start \
        --containall \
        --env-file ${path.module}/storage/env-file.txt \
        --bind ${path.module}/storage/n8n_storage:/home/node/ \
        --bind ${path.module}/storage/n8n_shared:/data/shared \
        n8n.sif \
        n8n
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance list | grep n8n -q && singularity instance stop n8n || true"
  }
}

# Qdrant Instance
resource "null_resource" "qdrant_instance" {
  depends_on = [null_resource.storage_dirs]

  provisioner "local-exec" {
    command = <<-EOT
      singularity instance start \
        --containall \
        --bind ${path.module}/storage/qdrant_storage:/qdrant/storage \
        qdrant.sif \
        qdrant
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance list | grep qdrant -q && singularity instance stop qdrant || true"
  }
}

# Ollama Instance
resource "null_resource" "ollama_instance" {
  depends_on = [null_resource.storage_dirs]

  provisioner "local-exec" {
    command = <<-EOT
      singularity instance start \
        --containall \
        --nv \
        --bind ${path.module}/storage/ollama_storage:/root/.ollama \
        --env OLLAMA_MODELS=/root/.ollama/ \
        ollama.sif \
        ollama
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance list | grep ollama -q && singularity instance stop ollama || true"
  }

  triggers = {
    use_gpu = var.use_gpu
  }
}

# Neo4j Instance
resource "null_resource" "neo4j_instance" {
  depends_on = [null_resource.storage_dirs]

  provisioner "local-exec" {
    command = <<-EOT
      singularity instance start \
        --containall \
        --bind ${path.module}/storage/neo4j_storage/data:/var/lib/neo4j/data \
        --bind ${path.module}/storage/neo4j_storage/logs:/var/lib/neo4j/logs \
        --bind ${path.module}/storage/neo4j_storage/conf:/var/lib/neo4j/conf \
        --env NEO4J_AUTH=neo4j/${var.neo4j_password} \
        --env NEO4J_server_memory_pagecache_size=512M \
        --env NEO4J_server_memory_heap_initial__size=512M \
        --env NEO4J_server_memory_heap_max__size=1G \
        neo4j.sif \
        neo4j
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "singularity instance list | grep neo4j -q && singularity instance stop neo4j || true"
  }
}

# Output the storage paths for use in Singularity containers
output "storage_paths" {
  value = {
    for dir in null_resource.storage_dirs : dir.triggers.dir_path => dirname(dir.triggers.dir_path)
  }
}

# Output service status
output "service_endpoints" {
  value = {
    n8n      = "http://localhost:5678"
    qdrant   = "http://localhost:6333"
    ollama   = "http://localhost:11434"
    postgres = "postgresql://localhost:5432"
    neo4j    = "bolt://localhost:7687"
  }
} 