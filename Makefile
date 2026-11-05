# Symlink this repo into the WoW: Forever AddOns folder so edits apply on /reload.
WOW_ADDONS ?= /Applications/World of Warcraft/_forever_/Interface/AddOns
NAME        = PadLabels

.PHONY: install uninstall check

install:
	mkdir -p "$(WOW_ADDONS)"
	ln -sfn "$(CURDIR)" "$(WOW_ADDONS)/$(NAME)"
	@echo "Linked $(WOW_ADDONS)/$(NAME) -> $(CURDIR)"

uninstall:
	rm -f "$(WOW_ADDONS)/$(NAME)"

check:
	luajit -e 'assert(loadfile("$(NAME).lua")); print("syntax ok")'
