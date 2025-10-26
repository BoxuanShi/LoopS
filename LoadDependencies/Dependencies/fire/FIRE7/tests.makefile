.PHONY: all clean_temp build compressors split storage prime_hints_generator hints modular lbases lthreads sep special preferred_rules reconstruct reconstructWith reconstructNE reconstructN reconstructd reconstruct_mpi reconstructd2mpi reconstructd23mpi reconstructd3mpi dummy_doublebox reconstructWithMP eqgen eqgen_combination eqgen6 eqgen5 eqgen_fourloop nb0 nb0_combi nb0_combi_eqgen eqgen_trim_tower394 eqgen_de_tower366 eqgen_de_tower366_all doublebox_two_stage

default: flint

ifeq ($(calc),)
calc := flint
endif

ifeq ($(diffcalc),)
diffcalc := flint
endif

EXEC := bin/FIRE7
EXECp := $(EXEC)p
EXECmp := $(EXEC)mp
EXECnp := $(EXEC)np
EXECmnp := $(EXEC)mnp

TESTSDIR = ./tests
DIFFTOOL= tools/diff
SORTTOOL= tools/topo_sort

ALL_LIBS := fermat pari form ginac cocoa maxima macaulay nemo math maple symbolica flint

.PHONY: $(ALL_LIBS)

.PHONY: test_all_lib test_best_lib mathematica

test:
	echo $(MAKEFILE_LIST)
	echo $(lastword $(MAKEFILE_LIST))

THIS_FILE := $(lastword $(MAKEFILE_LIST))

$(ALL_LIBS):
	make -f $(THIS_FILE) all calc=$@

test_all_lib: $(ALL_LIBS)

test_best_lib: fermat flint

mathematica:
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

all: | clean_temp build boxs compressors split storage hints modular lbases lthreads sep special preferred_rules lbases_modular reconstructWith reconstructWithMP

build:
	make -f Makefile
	@echo ""

clean_temp:
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/outputs/*
	rm -rf ${TESTSDIR}/hints/*
	rm -rf ${TESTSDIR}/storage/*
	rm -rf ${TESTSDIR}/doublebox/one_pass.tmp
	@echo ""

compressors: | clean_temp basiccomp zlib zstd snappy

basiccomp:
	@echo "*** Testing #memory option"
	@echo "*** Testing different compressors"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_none > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_none.tables
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_lz4 > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_lz4.tables
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_lz4fast > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_lz4fast.tables
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_lz4hc > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_lz4hc.tables
	@echo ""

ifeq ($(findstring --enable-zlib,$(shell cat previous_options)),--enable-zlib)
zlib:
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_zlib > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_zlib.tables
else
zlib:
	@echo "*** zlib compressor option skipped"
endif

ifeq ($(findstring --enable-zstd,$(shell cat previous_options)),--enable-zstd)
zstd:
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_zstd > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_zstd.tables
else
zstd:
	@echo "*** zstd compressor option skipped"
endif

ifeq ($(findstring --enable-snappy,$(shell cat previous_options)),--enable-snappy)
snappy:
	${EXEC} --calc ${calc} -c ${TESTSDIR}/c_snappy > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/c_snappy.tables
else
snappy:
	@echo "*** snappy compressor option skipped"
endif

split:
	@echo "*** Testing split masters mode"
	${EXEC} --calc ${calc} -c examples/box_split > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.1-1.tables ${TESTSDIR}/outputs/box.1-1.tables

storage: clean_temp
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/storage/*
	@echo "*** Testing #bucket, #storage options"
	${EXEC} --calc ${calc} --forward -c ${TESTSDIR}/db_storage >/dev/null
	rm -rf ${TESTSDIR}/db/*
	@echo "*** Now the backward stage"
	${EXEC} --calc ${calc} --backward -c ${TESTSDIR}/db_storage > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/db_storage.tables ${TESTSDIR}/outputs/db_storage.tables
	@echo ""
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/storage/*
	@echo "*** Now all modular, to be compared later"
	${EXECp} --calc ${calc} --variables 100_17_1 -c ${TESTSDIR}/db_storage >/dev/null
	cp ${TESTSDIR}/outputs/db_storage_100_17_1.tables ${TESTSDIR}/outputs/db_storage_100_17_1_copy.tables
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/storage/*
	@echo "*** Now forward again"
	${EXEC} --calc ${calc} --forward -c ${TESTSDIR}/db_storage >/dev/null
	rm -rf ${TESTSDIR}/db/*
	@echo "*** And backward with prime"
	${EXECp} --calc ${calc} --backward --variables 100_17_1 -c ${TESTSDIR}/db_storage > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/outputs/db_storage_100_17_1.tables ${TESTSDIR}/outputs/db_storage_100_17_1_copy.tables
	@echo ""

prime_hint_generator: clean_temp
	@echo "*** Testing #prime, #small options"
	@echo "*** Generating hints"
	${EXECp} --calc ${calc} -c ${TESTSDIR}/prime_hint > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/prime.tables ${TESTSDIR}/outputs/prime.tables
	@echo ""

boxs: clean_temp
	@echo "*** Basic test with global symmetries"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/boxs > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/boxs.tables ${TESTSDIR}/outputs/boxs.tables
	@echo ""

special: clean_temp
	@echo "*** Testing #allIBP, #pos_pref options"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/ibp > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/box.tables ${TESTSDIR}/outputs/special.tables
	@echo ""

lbases: clean_temp
	@echo "*** Testing #lbases, #wrap option"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/lbases > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/lbases.tables ${TESTSDIR}/outputs/lbases.tables
	@echo ""

lbases_modular: clean_temp
	@echo "*** Testing #lbases with modular approach"
	${EXECp} --calc ${calc} -v 100_1 -c ${TESTSDIR}/lbases > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/lbases_modular.tables ${TESTSDIR}/outputs/lbases_100_1.tables
	@echo ""

preferred_rules: clean_temp
	@echo "*** Testing #preferred, #rules options"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/pref_rules > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/preferred_rules.tables ${TESTSDIR}/outputs/preferred_rules.tables
	@echo ""

mix: | clean_temp prime_hint_generator
	rm -rf ${TESTSDIR}/db/*
	rm -rf ${TESTSDIR}/storage/*
	@echo "*** Testing mixed options"
	- timeout 15 ${EXEC} --calc ${calc} -c ${TESTSDIR}/mix > /dev/null
	${EXEC} --calc ${calc} -c ${TESTSDIR}/mix > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/preferred_rules.tables ${TESTSDIR}/outputs/mix.tables
	@echo ""

lthreads: clean_temp
	@echo "*** Testing lthreads"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/lthreads > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/db_storage.tables ${TESTSDIR}/outputs/lthreads.tables
	@echo ""

sep: clean_temp
	@echo "*** Testing separate workers"
	${EXEC} --calc ${calc} -c ${TESTSDIR}/sep > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/db_storage.tables ${TESTSDIR}/outputs/sep.tables
	@echo ""

modular: clean_temp
	@echo "*** Testing modular calculations and one-pass mode"
	${EXECp} --calc ${calc} --variables 100_100_1 -c ${TESTSDIR}/modular > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/modular.tables ${TESTSDIR}/outputs/modular_100_100_1.tables
#	${EXECp} --calc ${calc} --variables 100_100_1 -c ${TESTSDIR}/modular > /dev/null
	${DIFFTOOL} --calc ${diffcalc} ${TESTSDIR}/etalon/modular.tables ${TESTSDIR}/outputs/modular_100_100_1.tables
	@echo ""

dummy_doublebox: clean_temp
	@echo Running analytic doublebox with 3 variables
	${EXEC} --calc ${calc} -c examples/doublebox3N > /dev/null
	@echo Now dummy "reconstructing" it from substituted values
	mpirun -np 4 bin/FIRE7_MPI --delete_tables --calc ${calc} -R substitute --reconstruct -T 8_8_14 -P 3 -I 80_90_100 -E -c examples/doublebox3N > /dev/null
	${DIFFTOOL} -V --calc ${diffcalc} --variables t_s_d tests/outputs/doublebox_t_s_d_0.tables tests/outputs/doublebox.tables
	rm tests/outputs/doublebox_*
	@echo And same with zippel
	mpirun -np 4 bin/FIRE7_MPI --delete_tables --calc ${calc} -R substitute -Z --reconstruct -T 8_8_14 -P 3 -I 80_90_100 -E -S -c examples/doublebox3N > /dev/null
	${DIFFTOOL} -V --calc ${diffcalc} --variables t_s_d tests/outputs/doublebox_t_s_d_0.tables tests/outputs/doublebox.tables

reconstruct_math: clean_temp
	@echo "*** Testing rational reconstruction, requires Mathematica"
	bin/FIRE7 -c examples/box --quiet
	examples/run_box_prime
	math < examples/reconstruct_box_prime.m
	diff temp/diff.out ${TESTSDIR}/etalon/diff.out

reconstructd2mpi: clean_temp
	@echo "*** Testing rational+Thiele+balanced reconstruction with 2 variables with mpi"
	bin/FIRE7 -c examples/doublebox_t-3 --calc ${calc} --quiet
	examples/run_doublebox2_prime_mpi ${calc}
	${DIFFTOOL} --calc ${diffcalc} --calc ${calc} tests/outputs/doublebox_s_d_0.tables tests/outputs/doublebox_t-3.tables

reconstructd23mpi: clean_temp
	@echo "*** Testing rational+Thiele+balanced reconstruction with 2 variables of 3 with mpi"
	bin/FIRE7 -c examples/doublebox_t-3 --calc ${calc} --quiet
	examples/run_doublebox2_of_3_prime_mpi ${calc}
	${DIFFTOOL} --calc ${diffcalc} --calc ${calc} tests/outputs/doublebox_3_s_d_0.tables tests/outputs/doublebox_t-3.tables

reconstructd3mpi: clean_temp
	@echo "*** Testing rational+Thiele+balanced reconstruction with 3 variables with mpi"
	bin/FIRE7 -c examples/doublebox3N --calc ${calc} --quiet
	examples/run_doublebox3_prime_mpi ${calc}
	${DIFFTOOL} --calc ${diffcalc} --calc ${calc} tests/outputs/doublebox_t_s_d_0.tables tests/outputs/doublebox.tables

drange := $(shell seq 100 125)
reconstruct:
	for d in ${drange}; do tools/reconstruct --method rational --calc ${calc} "tests/outputs/box_$${d}_0.tables" 4; done
	tools/reconstruct --method thiele --calc ${calc} tests/outputs/box_d_0.tables 100:125 > /dev/null
	${DIFFTOOL} --calc ${diffcalc} tests/outputs/box_d_0.tables ${TESTSDIR}/etalon/box_rec.tables

reconstructWith: | clean_temp
	@echo "*** Testing rational+Thiele reconstruction with 1 variable"
	examples/run_box_prime --calc ${calc} > /dev/null
	for p in 1 2 3; do tools/reconstruct --method thiele --prime $${p} --calc ${calc} --reconstruction_variable d_100 "tests/outputs/box_d_$${p}.tables" 26; done
	tools/reconstruct --method rational --calc ${calc} tests/outputs/box_d_0.tables 3 > /dev/null
	${DIFFTOOL} --calc ${diffcalc} tests/outputs/box_d_0.tables ${TESTSDIR}/etalon/box_rec.tables

reconstructWithMP: | clean_temp
	@echo "*** Testing rational+Thiele reconstruction with 1 variable in multiprime mode"
	for p in 1 2 3; do ${EXECmp} --calc ${calc} -v 100+_$${p} -c examples/box --QUIET; done
	for p in 1 2 3; do ${EXECmp} --calc ${calc} -v 116+_$${p} -c examples/box --QUIET; done
	for p in 1 2 3; do tools/reconstruct --method thiele --prime $${p} --calc ${calc} --reconstruction_variable d_100 -M "tests/outputs/box_d_$${p}.tables" 26; done
	tools/reconstruct --method rational --calc ${calc} tests/outputs/box_d_0.tables 3 > /dev/null

reconstructN:
	for p in 1 2 3; do tools/reconstruct --method thiele --prime $${p} --calc ${calc} --reconstruction_variable d_100 "tests/outputs/box_d_$${p}.tables" 26; done
	tools/reconstruct --method rational --calc ${calc} tests/outputs/box_d_0.tables 3 > /dev/null
	${DIFFTOOL} --calc ${diffcalc} tests/outputs/box_d_0.tables ${TESTSDIR}/etalon/box_rec.tables

reconstructNE: | clean_temp
	@echo "*** Testing rational+Thiele reconstruction with 1 variable and large variables and new order"
	examples/run_box_prime_exp --calc ${calc} > /dev/null
	for p in 1 2 3; do tools/reconstruct --method thiele --prime $${p} --calc ${calc} --reconstruction_variable d_7 --geometric "tests/outputs/box_d_$${p}.tables" 26; done
	tools/reconstruct --method rational --calc ${calc} tests/outputs/box_d_0.tables 3 > /dev/null
	${DIFFTOOL} --calc ${diffcalc} tests/outputs/box_d_0.tables ${TESTSDIR}/etalon/box_rec.tables

reconstruct_mpi:
	@echo "*** Testing rational reconstruction and mpi prime rune, requires Mathematica and openmpi"
	bin/FIRE7 -c examples/box --quiet
	examples/run_box_prime_mpi
	cp temp/box.tables temp/box_single.tables
	math < examples/reconstruct_box_prime.m
	${DIFFTOOL} --calc ${diffcalc} temp/diff.out ${TESTSDIR}/etalon/diff.out

eqgen_combination: clean_temp
	rm -f temp/boc.plan.warmup
	@echo "*** Testing eqgen_external_solver for reducing linear combinations of integrals."
	${EXECp} -P ../temp/boc.plan -c examples/boxc --variables 100_1 --calc ${calc} --quiet
	mv tests/outputs/boxc_100_1.tables tests/outputs/boxc_100_1.tables.orig
	${EXECnp} -P ../temp/boc.plan -c examples/boxc --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/boxc_100_1.tables tests/outputs/boxc_100_1.tables.orig
	${EXECnp} -P ../temp/boc.plan -c examples/boxc --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/boxc_100_1.tables tests/outputs/boxc_100_1.tables.orig

eqgen: clean_temp
	rm -f temp/*.warmup
	@echo "*** Testing eqgen_external_solver"
	${EXECp} -P ../temp/bom.plan -c examples/boxm --variables 100_1 --calc ${calc} --quiet
	mv tests/outputs/box_100_1.1-3.tables tests/outputs/box_100_1.1-3.tables.orig
	${EXECnp} -P ../temp/bom.plan -c examples/boxm --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.1-3.tables tests/outputs/box_100_1.1-3.tables.orig
	${EXECnp} -P ../temp/bom.plan -c examples/boxm --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.1-3.tables tests/outputs/box_100_1.1-3.tables.orig
	@echo
	${EXECp} -P ../temp/bo.plan -c examples/box --variables 100_1 --calc ${calc} --quiet
	mv tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	${EXECnp} -P ../temp/bo.plan -c examples/box --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	${EXECnp} -P ../temp/bo.plan -c examples/box --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	@echo
	${EXECp} -P ../temp/bor.plan -c examples/boxr --variables 100_1 --calc ${calc} --quiet
	mv tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	${EXECnp} -P ../temp/bor.plan -c examples/boxr --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	${EXECnp} -P ../temp/bor.plan -c examples/boxr --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	@echo
	${EXECp} -P ../temp/dbo.plan -c examples/doublebox --variables 43_57_79_1 --calc ${calc} --quiet
	mv tests/outputs/doublebox_43_57_79_1.tables tests/outputs/doublebox_43_57_79_1.tables.orig
	${EXECnp} -P ../temp/dbo.plan -c examples/doublebox --variables 43_57_79_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/doublebox_43_57_79_1.tables tests/outputs/doublebox_43_57_79_1.tables.orig
	${EXECnp} -P ../temp/dbo.plan -c examples/doublebox --variables 43_57_79_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/doublebox_43_57_79_1.tables tests/outputs/doublebox_43_57_79_1.tables.orig
	@echo
	${EXECp} -P ../temp/boh.plan -c examples/boxh --variables 100_1 --calc ${calc} --quiet
	mv tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	${EXECnp} -P ../temp/boh.plan -c examples/boxh --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	${EXECnp} -P ../temp/boh.plan -c examples/boxh --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/box_100_1.tables tests/outputs/box_100_1.tables.orig
	@echo
	${EXECp} -P ../temp/v2.plan -c examples/v2 --variables 100_1 --calc ${calc} --quiet
	mv temp/v2_100_1.tables temp/v2_100_1.tables.orig
	${EXECnp} -P ../temp/v2.plan -c examples/v2 --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} temp/v2_100_1.tables temp/v2_100_1.tables.orig
	${EXECnp} -P ../temp/v2.plan -c examples/v2 --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} temp/v2_100_1.tables temp/v2_100_1.tables.orig
	@echo
	${EXECp} -P ../temp/v2l.plan -c examples/v2l --variables 100_1 --calc ${calc} --quiet
	mv temp/v2_100_1.tables temp/v2_100_1.tables.orig
	${EXECnp} -P ../temp/v2l.plan -c examples/v2l --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} temp/v2_100_1.tables temp/v2_100_1.tables.orig
	${EXECnp} -P ../temp/v2l.plan -c examples/v2l --variables 100_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} temp/v2_100_1.tables temp/v2_100_1.tables.orig
	@echo
	${EXECp} -P ../../temp/b1-88.plan -c examples/b1/b1-88 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-88_41^1_53^2_67^1_89^1_101^1_113^1_1.171-179.tables tests/outputs/b1-88_41^1_53^2_67^1_89^1_101^1_113^1_1.171-179.tables.orig
	${EXECnp} -P ../../temp/b1-88.plan -c examples/b1/b1-88 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-88_41^1_53^2_67^1_89^1_101^1_113^1_1.171-179.tables tests/outputs/b1-88_41^1_53^2_67^1_89^1_101^1_113^1_1.171-179.tables.orig
	${EXECnp} -P ../../temp/b1-88.plan -c examples/b1/b1-88 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-88_41^1_53^2_67^1_89^1_101^1_113^1_1.171-179.tables tests/outputs/b1-88_41^1_53^2_67^1_89^1_101^1_113^1_1.171-179.tables.orig
	@echo
	${EXECp} -P ../../temp/b1-87.plan -c examples/b1/b1-87 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-87_41^1_53^2_67^1_89^1_101^1_113^1_1.137-170.tables tests/outputs/b1-87_41^1_53^2_67^1_89^1_101^1_113^1_1.137-170.tables.orig
	${EXECnp} -P ../../temp/b1-87.plan -c examples/b1/b1-87 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-87_41^1_53^2_67^1_89^1_101^1_113^1_1.137-170.tables tests/outputs/b1-87_41^1_53^2_67^1_89^1_101^1_113^1_1.137-170.tables.orig
	${EXECnp} -P ../../temp/b1-87.plan -c examples/b1/b1-87 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-87_41^1_53^2_67^1_89^1_101^1_113^1_1.137-170.tables tests/outputs/b1-87_41^1_53^2_67^1_89^1_101^1_113^1_1.137-170.tables.orig
	@echo
	${EXECmp} -P ../../temp/b1-87.plan -c examples/b1/b1-87 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-87_41^1_53^2+_67^1_89^1_101^1_113^1_1.137-170.tables tests/outputs/b1-87_41^1_53^2+_67^1_89^1_101^1_113^1_1.137-170.tables.orig
	${EXECmnp} -P ../../temp/b1-87.plan -c examples/b1/b1-87 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-87_41^1_53^2+_67^1_89^1_101^1_113^1_1.137-170.tables tests/outputs/b1-87_41^1_53^2+_67^1_89^1_101^1_113^1_1.137-170.tables.orig

eqgen6: clean_temp
	rm -f temp/b1-86.plan.warmup
	${EXECp} -P ../../temp/b1-86.plan -c examples/b1/b1-86 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-86_41^1_53^2_67^1_89^1_101^1_113^1_1.80-136.tables tests/outputs/b1-86_41^1_53^2_67^1_89^1_101^1_113^1_1.80-136.tables.orig
	${EXECnp} -P ../../temp/b1-86.plan --calc_option full_pivoting -c examples/b1/b1-86 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
#	${DIFFTOOL} --calc ${calc} tests/outputs/b1-86_41^1_53^2_67^1_89^1_101^1_113^1_1.80-136.tables tests/outputs/b1-86_41^1_53^2_67^1_89^1_101^1_113^1_1.80-136.tables.orig
	${EXECnp} -P ../../temp/b1-86.plan -c examples/b1/b1-86 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-86_41^1_53^2_67^1_89^1_101^1_113^1_1.80-136.tables tests/outputs/b1-86_41^1_53^2_67^1_89^1_101^1_113^1_1.80-136.tables.orig
	time ${EXECmp} -P ../../temp/b1-86.plan -c examples/b1/b1-86 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-86_41^1_53^2+_67^1_89^1_101^1_113^1_1.80-136.tables tests/outputs/b1-86_41^1_53^2+_67^1_89^1_101^1_113^1_1.80-136.tables.orig
	time ${EXECmnp} -P ../../temp/b1-86.plan -c examples/b1/b1-86 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-86_41^1_53^2+_67^1_89^1_101^1_113^1_1.80-136.tables tests/outputs/b1-86_41^1_53^2+_67^1_89^1_101^1_113^1_1.80-136.tables.orig

eqgen5: clean_temp
	rm -f temp/b1-85.plan.warmup
	time ${EXECp} -P ../../temp/b1-85.plan -c examples/b1/b1-85 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-85_41^1_53^2_67^1_89^1_101^1_113^1_1.29-79.tables tests/outputs/b1-85_41^1_53^2_67^1_89^1_101^1_113^1_1.29-79.tables.orig
#	time ${EXECnp} -P ../../temp/b1-85.plan -c examples/b1/b1-85 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
#	time ${EXECnp} -P ../../temp/b1-85.plan -c examples/b1/b1-85 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
#	${DIFFTOOL} --calc ${calc} tests/outputs/b1-85_41^1_53^2_67^1_89^1_101^1_113^1_1.29-79.tables tests/outputs/b1-85_41^1_53^2_67^1_89^1_101^1_113^1_1.29-79.tables.orig
	# test again with full pivoting
	rm -f temp/b1-85.plan.warmup
	time ${EXECnp} --calc_options full_pivoting -P ../../temp/b1-85.plan -c examples/b1/b1-85 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	time ${EXECnp} --calc_options full_pivoting -P ../../temp/b1-85.plan -c examples/b1/b1-85 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-85_41^1_53^2_67^1_89^1_101^1_113^1_1.29-79.tables tests/outputs/b1-85_41^1_53^2_67^1_89^1_101^1_113^1_1.29-79.tables.orig
	time ${EXECmp} -P ../../temp/b1-85.plan -c examples/b1/b1-85 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-85_41^1_53^2+_67^1_89^1_101^1_113^1_1.29-79.tables tests/outputs/b1-85_41^1_53^2+_67^1_89^1_101^1_113^1_1.29-79.tables.orig
	time ${EXECmnp} -P ../../temp/b1-85.plan -c examples/b1/b1-85 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-85_41^1_53^2+_67^1_89^1_101^1_113^1_1.29-79.tables tests/outputs/b1-85_41^1_53^2+_67^1_89^1_101^1_113^1_1.29-79.tables.orig

eqgen4: clean_temp
	rm -f temp/b1-84.plan.warmup
	${EXECp} -P ../../temp/b1-84.plan -c examples/b1/b1-84 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-84_41^1_53^2_67^1_89^1_101^1_113^1_1.10-28.tables tests/outputs/b1-84_41^1_53^2_67^1_89^1_101^1_113^1_1.10-28.tables.orig
	${EXECnp} -P ../../temp/b1-84.plan --calc_option full_pivoting -c examples/b1/b1-84 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
#	${DIFFTOOL} --calc ${calc} tests/outputs/b1-84_41^1_53^2_67^1_89^1_101^1_113^1_1.10-28.tables tests/outputs/b1-84_41^1_53^2_67^1_89^1_101^1_113^1_1.10-28.tables.orig
	${EXECnp} -P ../../temp/b1-84.plan -c examples/b1/b1-84 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-84_41^1_53^2_67^1_89^1_101^1_113^1_1.10-28.tables tests/outputs/b1-84_41^1_53^2_67^1_89^1_101^1_113^1_1.10-28.tables.orig
	time ${EXECmp} -P ../../temp/b1-84.plan -c examples/b1/b1-84 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-84_41^1_53^2+_67^1_89^1_101^1_113^1_1.10-28.tables tests/outputs/b1-84_41^1_53^2+_67^1_89^1_101^1_113^1_1.10-28.tables.orig
	time ${EXECmnp} -P ../../temp/b1-84.plan -c examples/b1/b1-84 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-84_41^1_53^2+_67^1_89^1_101^1_113^1_1.10-28.tables tests/outputs/b1-84_41^1_53^2+_67^1_89^1_101^1_113^1_1.10-28.tables.orig

eqgen3: clean_temp
	rm -f temp/b1-83.plan.warmup
	${EXECp} -P ../../temp/b1-83.plan -c examples/b1/b1-83 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-83_41^1_53^2_67^1_89^1_101^1_113^1_1.1-9.tables tests/outputs/b1-83_41^1_53^2_67^1_89^1_101^1_113^1_1.1-9.tables.orig
	${EXECnp} -P ../../temp/b1-83.plan -c examples/b1/b1-83 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
#	${DIFFTOOL} --calc ${calc} tests/outputs/b1-83_41^1_53^2_67^1_89^1_101^1_113^1_1.1-9.tables tests/outputs/b1-83_41^1_53^2_67^1_89^1_101^1_113^1_1.1-9.tables.orig
	${EXECnp} -P ../../temp/b1-83.plan -c examples/b1/b1-83 --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-83_41^1_53^2_67^1_89^1_101^1_113^1_1.1-9.tables tests/outputs/b1-83_41^1_53^2_67^1_89^1_101^1_113^1_1.1-9.tables.orig
	time ${EXECmp} -P ../../temp/b1-83.plan -c examples/b1/b1-83 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-83_41^1_53^2+_67^1_89^1_101^1_113^1_1.1-9.tables tests/outputs/b1-83_41^1_53^2+_67^1_89^1_101^1_113^1_1.1-9.tables.orig
	time ${EXECmnp} -P ../../temp/b1-83.plan -c examples/b1/b1-83 --large_variables --variables 41^1_53^2+_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/b1-83_41^1_53^2+_67^1_89^1_101^1_113^1_1.1-9.tables tests/outputs/b1-83_41^1_53^2+_67^1_89^1_101^1_113^1_1.1-9.tables.orig

eqgen_fourloop: clean_temp
	rm -f temp/tower366top.plan.warmup
	rm -f examples/tower366top_trimmed.plan.warmup
	@echo "*** Testing eqgen_external_solver for 4-loop maximal-cut IBP"
	@echo "*** Running ${EXECp}"
	/usr/bin/time -v ${EXECp} -P ../temp/tower366top.plan -c examples/tower366top --variables 37_73_1 --calc ${calc} --quiet
	mv tests/outputs/tower366top_37_73_1.1-22.tables tests/outputs/tower366top_37_73_1.1-22.tables.orig
	@echo "*** Running ${EXECnp} for warmup"
	/usr/bin/time -v ${EXECnp} -P ../temp/tower366top.plan -c examples/tower366top --variables 37_73_1 --calc ${calc} --quiet
	@echo "*** Running ${EXECnp} for production"
	/usr/bin/time -v ${EXECnp} -P ../temp/tower366top.plan -c examples/tower366top --variables 37_73_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/tower366top_37_73_1.1-22.tables tests/outputs/tower366top_37_73_1.1-22.tables.orig
	@echo "*** Running ${EXECnp} for with hand-coded .plan file (warmup)"
	/usr/bin/time -v ${EXECnp} -P tower366top_trimmed.plan -c examples/tower366top --variables 37_73_1 --calc ${calc} --quiet
	@echo "*** Running ${EXECnp} for with hand-coded .plan file (production)"
	/usr/bin/time -v ${EXECnp} -P tower366top_trimmed.plan -c examples/tower366top --variables 37_73_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${calc} tests/outputs/tower366top_37_73_1.1-22.tables tests/outputs/tower366top_37_73_1.1-22.tables.orig

eqgen_trim_b1: clean_temp
	rm -f temp/*.warmup
	rm -f examples/b1/*.warmup
	# FIRE7p run
	/usr/bin/time -v ${EXECp} -P b1-cut.plan -c examples/b1/b1-cut --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	mv tests/outputs/b1-cut_41^1_53^2_67^1_89^1_101^1_113^1_1.tables tests/outputs/b1-cut_41^1_53^2_67^1_89^1_101^1_113^1_1.tables.orig
	# FIRE7np warmup run with hard-coded .plan file
	/usr/bin/time -v ${EXECnp} -P b1-cut-trimmed.plan -c examples/b1/b1-cut --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	# Don't compare the .tables files yet! The .tables file produced by the warmup run does not contain the correct final reduction rules.
	# FIRE7np production run with hard-coded .plan file and with .warmup file
	/usr/bin/time -v ${EXECnp} -P b1-cut-trimmed.plan -c examples/b1/b1-cut --large_variables --variables 41^1_53^2_67^1_89^1_101^1_113^1_1 --calc ${calc} --quiet
	# Now compare tables
	${DIFFTOOL} tests/outputs/b1-cut_41^1_53^2_67^1_89^1_101^1_113^1_1.tables tests/outputs/b1-cut_41^1_53^2_67^1_89^1_101^1_113^1_1.tables.orig

nb0: clean_temp
	mpirun -np 5 bin/FIRE7_MPI -Z -M --reconstruct -P 3 -E -S --calc ${calc} -c examples/nb0/nb0-de
	more tests/outputs/*.limits

nb0_combi: clean_temp
	mpirun -np 5 bin/FIRE7_MPI -Z -M --reconstruct -P 3 -E -S --calc ${calc} -c examples/nb0/nb0-deru
	more tests/outputs/*.limits

nb0_combi_eqgen: clean_temp
	mpirun -np 5 bin/FIRE7_MPI -e -Z -M --reconstruct -P 3 -E -S --calc ${calc} -c examples/nb0/nb0-deru
	more tests/outputs/*.limits

eqgen_trim_tower394: clean_temp
	rm -f examples/tower394/*.{warmup,steps,step2,sorting}
	# To generate tower394_cut10.config from scratch, run "julia --project=extra/FireHelper extra/FireHelper/src/write_cut_configs.jl examples/tower394/tower394.config examples/tower394/spanningCuts.m"
	# FIRE7np warmup run with hard-coded .plan file, producing a .warmup file
	/usr/bin/time -v ${EXECnp} -P cut-trimmed.plan -W cut-trimmed_cut10.warmup --calc_options full_pivoting -c examples/tower394/tower394_cut10 --large_variables --variables 37_73_1 --calc ${calc} --quiet
	# FIRE7np production run with hard-coded .plan file and with .warmup file, producing a .steps file
	/usr/bin/time -v ${EXECnp} -P cut-trimmed.plan -W cut-trimmed_cut10.warmup -c examples/tower394/tower394_cut10 --record_steps cut-trimmed_cut10.steps --large_variables --variables 37_73_1 --calc ${calc} --quiet
	# Important: run again with different variables to see if the .steps file remains the same
	/usr/bin/time -v ${EXECnp} -P cut-trimmed.plan -W cut-trimmed_cut10.warmup -c examples/tower394/tower394_cut10 --record_steps cut-trimmed_cut10.steps2 --large_variables --variables 73_37_2 --calc ${calc} --quiet
	diff -q examples/tower394/cut-trimmed_cut10.steps examples/tower394/cut-trimmed_cut10.steps2
	mv tests/outputs/tower394_cut10_37_73_1.1-49.tables tests/outputs/tower394_cut10_37_73_1.1-49.tables.old
	# process the .steps file to produce the topological sorting file
	${SORTTOOL} examples/tower394/cut-trimmed_cut10.steps -o examples/tower394/cut-trimmed_cut10.sorting
	/usr/bin/time -v ${EXECnp} -P cut-trimmed.plan -W cut-trimmed_cut10.warmup -c examples/tower394/tower394_cut10 --topo_sort cut-trimmed_cut10.sorting --large_variables --variables 37_73_1 --calc ${calc} --quiet
	# Now compare tables from runs with or without using the topological sorting file
	${DIFFTOOL} tests/outputs/tower394_cut10_37_73_1.1-49.tables.old tests/outputs/tower394_cut10_37_73_1.1-49.tables

doublebox_two_stage: clean_temp
	rm -f examples/doublebox-rank4.plan.warmup
	rm -f examples/doublebox-rank4-sym.plan.warmup
	${EXECp} -c examples/doublebox-rank4-sym --variables 43_57_79_1 --calc ${calc} --quiet
	mv tests/outputs/doublebox-rank4-sym_43_57_79_1.1-8.tables tests/outputs/doublebox-rank4-sym_43_57_79_1.1-8.tables.orig
	#warmup
	${EXECnp} -P doublebox-rank4.plan -c examples/doublebox-rank4 --variables 43_57_79_1 --calc ${calc} --quiet
	#production
	${EXECnp} -P doublebox-rank4.plan -c examples/doublebox-rank4 --variables 43_57_79_1 --printall 1 --calc ${calc} --quiet
	sed -i 's/89004004000000000000000000002/888888888888888888/g' tests/outputs/doublebox-rank4_43_57_79_1.tables
	#warmup for second run
	${EXECnp} -P doublebox-rank4-sym.plan -c examples/doublebox-rank4-sym --variables 43_57_79_1 --calc ${calc} --quiet
	#production for second run
	${EXECnp} -P doublebox-rank4-sym.plan -c examples/doublebox-rank4-sym --variables 43_57_79_1 --calc ${calc} --quiet
	${DIFFTOOL} --calc ${diffcalc} tests/outputs/doublebox-rank4-sym_43_57_79_1.1-8.tables.orig tests/outputs/doublebox-rank4-sym_43_57_79_1.1-8.tables
