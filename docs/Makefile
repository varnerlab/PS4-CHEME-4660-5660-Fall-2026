NAME := PS4-Mathematical-Companion
.PHONY: all clean
all:
	latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir=build $(NAME).tex
	cp build/$(NAME).pdf $(NAME).pdf
clean:
	rm -rf build
