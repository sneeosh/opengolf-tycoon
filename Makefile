# OpenGolf Tycoon Makefile

# Godot executable - override with: make test GODOT=/path/to/godot
GODOT ?= $(shell \
	if [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then \
		echo "/Applications/Godot.app/Contents/MacOS/Godot"; \
	elif [ -x "$(HOME)/Downloads/Godot.app/Contents/MacOS/Godot" ]; then \
		echo "$(HOME)/Downloads/Godot.app/Contents/MacOS/Godot"; \
	elif command -v godot >/dev/null 2>&1; then \
		echo "godot"; \
	else \
		echo ""; \
	fi)

# Override with the Python environment containing Pillow and the API SDKs.
VISUAL_PYTHON ?= python3

.PHONY: test run editor visual-check visual-audit help

help:
	@echo "OpenGolf Tycoon - Available commands:"
	@echo "  make test    - Run unit tests"
	@echo "  make run     - Run the game"
	@echo "  make editor  - Open in Godot editor"
	@echo "  make visual-check - Check visual pipeline dependencies"
	@echo "  make visual-audit - Inventory committed PNG dimensions"
	@echo ""
	@echo "Override Godot path: make test GODOT=/path/to/godot"
	@echo "Override visual Python: make visual-check VISUAL_PYTHON=/path/to/python"

test:
	@if [ -z "$(GODOT)" ]; then \
		echo "Error: Godot not found. Set GODOT variable."; \
		exit 1; \
	fi
	@echo "Running tests with: $(GODOT)"
	@$(GODOT) --headless --path . -s addons/gut/gut_cmdln.gd

run:
	@if [ -z "$(GODOT)" ]; then \
		echo "Error: Godot not found. Set GODOT variable."; \
		exit 1; \
	fi
	@$(GODOT) --path .

editor:
	@if [ -z "$(GODOT)" ]; then \
		echo "Error: Godot not found. Set GODOT variable."; \
		exit 1; \
	fi
	@$(GODOT) --editor --path .

visual-check:
	@$(VISUAL_PYTHON) .agents/skills/opengolf-visual-pipeline/scripts/check_environment.py

visual-audit:
	@$(VISUAL_PYTHON) .agents/skills/opengolf-visual-pipeline/scripts/audit_assets.py assets
