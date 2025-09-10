include paths.inc

.PHONY: all clean_temp build compressors storage prime_hints_generator hints modular lbases lthreads sep_fermat special preferred_rules math
default: all

ifeq ($(calc),)
calc := fermat
endif

EXEC= bin/FIRE6
EXECp= ${EXEC}p
TESTSDIR = ./tests

all: | clean_temp build boxs compressors storage hints modular lbases lthreads sep_fermat special preferred_rules

math:
	rm -rf tests/math/temp/*
	math < tests/math/box_stage_1.m > /dev/null
	diff tests/math/temp/box.start tests/math/etalon/box.start
	math < tests/math/box_stage_2.m > /dev/null
	diff tests/math/temp/box_F.m tests/math/etalon/box_F.m
	diff tests/math/temp/box.rules tests/math/etalon/box.rules
	math < tests/math/box_stage_3.m > /dev/null
	diff tests/math/temp/box_Fr.m tests/math/etalon/box_Fr.m
	math < tests/math/box_stage_4.m > /dev/null
	diff tests/math/temp/box.tables tests/math/etalon/box.tables
	math < tests/math/box_stage_5.m > /dev/null
	diff tests/math/temp/boxs.start tests/math/etalon/boxs.start
	math < tests/math/box_stage_6.m > /dev/null
	diff tests/math/temp/box_Fs.m tests/math/etalon/box_Fr.m
	math < tests/math/v2_stage_1.m > /dev/null
	diff tests/math/temp/v2.start tests/math/etalon/v2.start
	math < tests/math/v2_stage_2.m > /dev/null
	math < tests/math/v2_stage_3.m > /dev/null
	diff tests/math/temp/v2_F.m tests/math/etalon/v2_F.m
	math < tests/math/v2_stage_4.m > /dev/null
	diff tests/math/temp/v2.sbases tests/math/etalon/v2.sbases
	math < tests/math/v2_stage_5.m > /dev/null
	diff tests/math/temp/diff.m tests/etalon/diff.out

reconstruct:
	@echo "*** Testing rational reconstruction, requires Mathematica"
	bin/FIRE6 -c examples/box --quiet
	cp tests/outputs/box.tables tests/outputs/box_single.tables
	examples/run_box_prime
	math < examples/reconstruct_box_prime.m
	diff temp/diff.out ${TESTSDIR}/etalon/diff.out

build:
	make -f Makefile
	@echo ""

clean_temp:
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/outputs/*
	rm -rf ${TESTSDIR}/hints/*
	rm -rf ${TESTSDIR}/storage/*
	@echo ""

compressors: | clean_temp basiccomp zlib zstd snappy

basiccomp:
	@echo "*** Testing #memory option"
	@echo "*** Testing different compressors"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_none > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_none.tables
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_lz4 > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_lz4.tables
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_lz4fast > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_lz4fast.tables
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_lz4hc > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_lz4hc.tables
	@echo ""

ifeq ($(findstring --enable-zlib,$(shell cat previous_options)),--enable-zlib)
zlib:
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_zlib > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_zlib.tables
else
zlib:
	@echo "*** zlib compressor option skipped"
endif

ifeq ($(findstring --enable-zstd,$(shell cat previous_options)),--enable-zstd)
zstd:
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_zstd > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_zstd.tables
else
zstd:
	@echo "*** zstd compressor option skipped"
endif

ifeq ($(findstring --enable-snappy,$(shell cat previous_options)),--enable-snappy)
snappy:
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_snappy > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_snappy.tables
else
snappy:
	@echo "*** snappy compressor option skipped"
endif

storage: clean_temp
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/storage/*
	@echo "*** Testing #bucket, #storage options"
	- timeout -s 9 30 ${EXEC} --calc ${calc} -c ${TESTSDIR}/db_storage >/dev/null
	rm -rf ${TESTSDIR}/db/*
	@echo "*** Dropping FIRE, starting anew on existing storage"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/db_storage > /dev/null
	${DIFF} ${TESTSDIR}/etalon/db_storage.tables ${TESTSDIR}/outputs/db_storage.tables
	@echo ""

prime_hint_generator: clean_temp
	@echo "*** Testing #prime, #small options"
	@echo "*** Generating hints"
	${EXECp} -c ${TESTSDIR}/prime_hint > /dev/null
	${DIFF} ${TESTSDIR}/etalon/prime.tables ${TESTSDIR}/outputs/prime.tables
	@echo ""

hints: | clean_temp prime_hint_generator
	@echo "*** Testing #hint option"
	@echo "*** Reading from hint files"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/hinted > /dev/null
	${DIFF} ${TESTSDIR}/etalon/hinted_true.tables ${TESTSDIR}/outputs/hinted.tables
	@echo ""

boxs: clean_temp
	@echo "*** Basic test with global symmetries"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/boxs > /dev/null
	${DIFF} ${TESTSDIR}/etalon/boxs.tables ${TESTSDIR}/outputs/boxs.tables
	@echo ""

special: clean_temp
	@echo "*** Testing #allIBP, #pos_pref options"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/ibp > /dev/null
	${DIFF} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/special.tables
	@echo ""

lbases: clean_temp
	@echo "*** Testing #lbases, #wrap option"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/lbases > /dev/null
	${DIFF} ${TESTSDIR}/etalon/lbases.tables ${TESTSDIR}/outputs/lbases.tables
	@echo ""

preferred_rules: clean_temp
	@echo "*** Testing #preferred, #rules options"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/pref_rules > /dev/null
	${DIFF} ${TESTSDIR}/etalon/preferred_rules.tables ${TESTSDIR}/outputs/preferred_rules.tables
	@echo ""

mix: | clean_temp prime_hint_generator
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/storage/*
	@echo "*** Testing mixed options"
	- timeout 15 ${EXEC} --calc ${calc} -c ${TESTSDIR}/mix > /dev/null
	${EXEC} --calc ${calc} -c ${TESTSDIR}/mix > /dev/null
	${DIFF} ${TESTSDIR}/etalon/preferred_rules.tables ${TESTSDIR}/outputs/mix.tables
	@echo ""

ifeq ($(findstring --enable-lthreads,$(shell cat previous_options)),--enable-lthreads)
lthreads: clean_temp
	@echo "*** Testing lthreads"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/lthreads > /dev/null
	${DIFF} ${TESTSDIR}/etalon/db_storage.tables ${TESTSDIR}/outputs/lthreads.tables
	@echo ""
else
lthreads:
	@echo "*** Skipping lthreads test"
endif

sep_fermat: clean_temp
	@echo "*** Testing separate fermat workers"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/sep_fermat > /dev/null
	${DIFF} ${TESTSDIR}/etalon/db_storage.tables ${TESTSDIR}/outputs/sep_fermat.tables
	@echo ""

modular: clean_temp
	@echo "*** Testing modular calculations"
	${EXECp} --variables 100-100-1 -c ${TESTSDIR}/modular > /dev/null
	${DIFF} ${TESTSDIR}/etalon/modular.tables ${TESTSDIR}/outputs/modular-100-100-1.tables
	@echo ""
