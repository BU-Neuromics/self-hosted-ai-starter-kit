# Singularity container build targets
CONTAINERS = postgres.sif n8n.sif qdrant.sif ollama.sif neo4j.sif

# Default target
.PHONY: all
all: $(CONTAINERS)

# Individual container targets
postgres.sif: singularity/postgres.def
	sudo singularity build --force $@ $<

n8n.sif: singularity/n8n.def
	sudo singularity build --force $@ $<

qdrant.sif: singularity/qdrant.def
	sudo singularity build --force $@ $<

ollama.sif: singularity/ollama.def
	sudo singularity build --force $@ $<

neo4j.sif: singularity/neo4j.def
	sudo singularity build --force $@ $<

# Clean target to remove all containers
.PHONY: clean
clean:
	rm -f $(CONTAINERS)

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all      - Build all Singularity containers (default)"
	@echo "  clean    - Remove all built containers"
	@echo "  help     - Show this help message"
	@echo ""
	@echo "Individual container targets:"
	@echo "  postgres.sif - Build PostgreSQL container"
	@echo "  n8n.sif     - Build n8n container"
	@echo "  qdrant.sif  - Build Qdrant container"
	@echo "  ollama.sif  - Build Ollama container" 
