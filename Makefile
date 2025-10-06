.PHONY: all uninstall

all:
	cp functions/mark.fish ~/.config/fish/functions/
	cp completions/mark.fish ~/.config/fish/completions/

uninstall:
	rm -f ~/.config/fish/functions/mark.fish
	rm -f ~/.config/fish/completions/mark.fish
