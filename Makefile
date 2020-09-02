# Use a standard bash shell, avoid zsh or fish
SHELL:=/bin/bash

# Select the default target, when you are simply running "make"
.DEFAULT_GOAL:=lint

# local executables
pip:=./venv/bin/pip
pre-commit=./venv/bin/pre-commit

.PHONY: lint venv

venv:
	python3.7 -m venv venv
	$(pip) install pre-commit

lint:
	$(pre-commit) run --all-files
