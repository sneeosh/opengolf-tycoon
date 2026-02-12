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

.PHONY: test run editor help

help:
	@echo "OpenGolf Tycoon - Available commands:"
	@echo "  make test    - Run unit tests"
	@echo "  make run     - Run the game"
	@echo "  make editor  - Open in Godot editor"
	@echo ""
	@echo "Override Godot path: make test GODOT=/path/to/godot"

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
