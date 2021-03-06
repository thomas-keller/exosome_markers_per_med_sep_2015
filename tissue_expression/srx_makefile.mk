#!/usr/bin/make -f

include ../common_variables.mk

BOWTIE_INDEX_DIR=../ref_seqs/
COMMON_MAKEFILE=../common_makefile.mk

include srx_info.mk

ifeq ($(NREADS),1)
FASTQ_FILES:=$(patsubst %,%.fastq.gz,$(SRRS))
TOPHAT_FASTQ_ARGUMENT:=$(shell echo $(FASTQ_FILES)|sed 's/  */,/g')
else
FASTQ_FILES:=$(patsubst %,%_1.fastq.gz,$(SRRS))  $(patsubst %,%_2.fastq.gz,$(SRRS))
TOPHAT_FASTQ_ARGUMENT:=$(shell echo $(patsubst %,%_1.fastq.gz,$(SRRS))|sed 's/  */,/g') $(shell echo $(patsubst %,%_2.fastq.gz,$(SRRS))|sed 's/  */,/g')
endif

SRR_FILES=$(patsubst %,%.sra,$(SRRS))

get_srr: $(SRR_FILES)

$(SRR_FILES): %.sra:
	rsync -avP "rsync://ftp-trace.ncbi.nlm.nih.gov/sra/sra-instant/reads/ByRun/sra/SRR/$(shell echo -n $*|sed 's/\(SRR[0-9][0-9][0-9]\).*/\1/')/$*/$*.sra" $@;

make_fastq: $(FASTQ_FILES)

ifeq ($(NREADS),1)
$(FASTQ_FILES): %.fastq.gz: %.sra
else
%_1.fastq.gz %_2.fastq.gz: %.sra
endif
	$(MODULE) load sratoolkit/2.3.5-2; \
	fastq-dump -B --split-3 --gzip $^;


include $(COMMON_MAKEFILE)
