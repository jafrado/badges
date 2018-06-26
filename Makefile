
all: png pdf split

png duracard:
	rm -fr badges-duracard
	./badge_dc_3x4.pl final.csv
	cd badges-duracard; ../round_edges.csh; cd -

ticketprinting:
	rm -fr badges-ticket-printing
	./badges.pl final.csv
	cd badges-ticket-printing; ../round_edges.csh; cd -

duracard_hanger:
	rm -fr badges-duracard
	./badge_dc_cr80.pl final.csv
	./badge_dc_hanger.pl final.csv
	cd badges-duracard; ../round_edges.csh; cd -

pdf:
	rm -fr orders
	mkdir -p orders
	cp -fr images orders
	./orders.pl orders.csv
	cd orders; pdflatex banquet-tickets.tex;pdflatex orders.tex; pdflatex bistro-dinners.tex; cd -
	rm -fr signups
	mkdir -p signups
	cp -fr images signups
	./signups.pl signups.csv	
	cd signups; pdflatex range-duty.tex; cd -

split2:
	rm -f badgelist.csv
	cd badges-duracard; rm *.csv; cd -
	cd badges-duracard; ls -t *.jpg >../badgelist.csv; cd - 
	mv badgelist.csv badges-duracard

split:
	rm -f badgelist.csv
	cd badges-duracard; rm *.csv; cd -
	cd badges-duracard; ls -t *.jpg >../badgelist.csv; cd - 
#	sort -u badgelist.csv
	mv badgelist.csv badges-duracard

clean:
	rm -fr badges
	rm -fr orders
	rm -fr signups

