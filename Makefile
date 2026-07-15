# Gemini CLI student sandbox — task runner.
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help setup start doctor test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Quickstart:  make setup && make doctor && make start"

setup: ## Install Gemini CLI, preload settings, validate the API key
	@bash scripts/setup.sh

start: ## Launch Gemini CLI (args: ARGS="...")
	@bash scripts/start.sh $(ARGS)

doctor: ## Verify CLI, settings, key, and a live round-trip
	@bash scripts/doctor.sh

test: ## Run the offline test suite (same as CI: lint + pytest, no secrets)
	@shellcheck --severity=error -e SC1091 scripts/*.sh 2>/dev/null || echo "(shellcheck not installed — skipping)"
	@for f in scripts/*.sh; do bash -n "$$f"; done
	@python3 -m pytest tests/ -q
