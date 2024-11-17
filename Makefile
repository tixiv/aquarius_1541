
ACME=acme.exe
EXOMIZER=exomizer.exe
C1541=c1541

all: out/aquarius_1541.d64 out/aquarius_1541_packed.prg out/picture_packed.prg

.PHONY: clean
clean:
	rm -f out/*

.PHONY: outdir
outdir:
	mkdir -p out/
	
out/aquarius_1541.prg: aquarius_disk_controls.asm outdir
	$(ACME) -o $@ --format cbm $<

out/aquarius_1541_packed.prg: out/aquarius_1541.prg outdir
	$(EXOMIZER) sfx 0x80d -x3 -o $@ $<
	
out/picture_packed.prg: picture.prg
	$(EXOMIZER) sfx 0x80d -x3 -o $@ $<
	
out/aquarius_1541.d64: out/aquarius_1541_packed.prg out/picture_packed.prg outdir
	$(C1541) -format "aquarius 1541,41" d64 "$@"
	$(C1541) -attach "$@" -write out/aquarius_1541_packed.prg 'aquarius 1541'
	$(C1541) -attach "$@" -write out/picture_packed.prg 'fig. 1'
	$(C1541) -attach "$@" -dir
