SHELL := /bin/bash

.PHONY: install update uninstall validate archive

install:
	./install.sh

update:
	./update.sh

uninstall:
	./uninstall.sh

validate:
	@set -e; \
	for f in install.sh update.sh uninstall.sh tools/*.sh bin/* dotfiles/.config/dwl/start; do \
	  case "$$f" in *.py) ;; *) bash -n "$$f" ;; esac; \
	done; \
	python3 -m py_compile lib/*.py tools/*.py; \
	python3 tools/repo-check.py; \
	echo 'syntax validation OK'

archive:
	@name="$$(basename "$$(pwd)")"; cd ..; \
	tar --exclude-vcs --exclude='*/__pycache__' --exclude='*.pyc' -czf "$$name.tar.gz" "$$name"; \
	zip -qr "$$name.zip" "$$name" -x '*/.git/*' '*/__pycache__/*' '*.pyc'; \
	echo "../$$name.tar.gz"; echo "../$$name.zip"
