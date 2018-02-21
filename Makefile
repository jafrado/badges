
all: png pdf

png:
	rm -fr badges
	./badges.pl final.csv
	cd badges; ../round_edges.csh; cd -
pdf:
	rm -fr orders
	mkdir -p orders
	cp -fr images orders
	./orders.pl orders.csv
	cd orders; pdflatex banquet-tickets.tex;pdflatex orders.tex; cd -

clean:
	rm -fr badges
	rm -fr orders

