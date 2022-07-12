# //----------------------------------------------------------------------//
# // The MIT License
# //
# // Copyright (c) 2008 Abhinav Agarwal, Alfred Man Cheuk Ng
# // Contact: abhiag@gmail.com
# //
# // Permission is hereby granted, free of charge, to any person
# // obtaining a copy of this software and associated documentation
# // files (the "Software"), to deal in the Software without
# // restriction, including without limitation the rights to use,
# // copy, modify, merge, publish, distribute, sublicense, and/or sell
# // copies of the Software, and to permit persons to whom the
# // Software is furnished to do so, subject to the following conditions:
# //
# // The above copyright notice and this permission notice shall be
# // included in all copies or substantial portions of the Software.
# //
# // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# // EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# // OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# // NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# // HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# // WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# // FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# // OTHER DEALINGS IN THE SOFTWARE.
# //----------------------------------------------------------------------//

#=======================================================================
# Makefile for Reed Solomon decoder
#-----------------------------------------------------------------------

default : all

# Sources
srcdir  = .
toplevel_module = mkTestBench

PRIMITIVE_POLY ?= "0b100011101"
K ?= 223
T ?= 16
N ?= 10
NERR ?= $(T)

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

# run the rs_model to generate the GF inverse logic and test files
input.dat ref_output.dat RSParameters.bsv:
	./rs_model.py -P $(PRIMITIVE_POLY) -K $(K) -T $(T) -N $(N) -Nerr $(NERR) -bsv RSParameters.bsv

BSC_COMP = bsc
BSC_FLAGS = -u -aggressive-conditions -keep-fires -no-show-method-conf \
	-steps-warn-interval 200000 -steps-max-intervals 10 -show-schedule +RTS -K4000M -RTS

BSC_VOPTS = -elab -verilog
BSC_BAOPTS = -sim

BDIR ?= build
VDIR ?= verilog
IDIR ?= info
SDIR ?= sim

# run gcc
file_interface.o: file_interface.cpp
	gcc -c -DDATA_FILE_PATH=\"./input.dat\" -DOUT_DATA_FILE_PATH=\"./output.dat\" file_interface.cpp -fPIC

# Run the bluespec compiler
$(BDIR)/$(toplevel_module).ba: RSParameters.bsv $(BDIR) $(VDIR) $(IDIR)
	$(BSC_COMP) $(BSC_FLAGS) -bdir $(BDIR) -info-dir $(IDIR) -vdir $(VDIR) $(BSC_VOPTS) mkReedSolomon.bsv
	$(BSC_COMP) $(BSC_FLAGS) -bdir $(BDIR) -info-dir $(IDIR) -vdir $(VDIR) $(BSC_BAOPTS) -g $(toplevel_module) $(toplevel_module).bsv

$(toplevel_module): $(BDIR)/$(toplevel_module).ba file_interface.o $(SDIR)
	$(BSC_COMP) $(BSC_BAOPTS) -simdir $(SDIR) -e $(toplevel_module) -o $(toplevel_module) $(BDIR)/*.ba file_interface.o

all: input.dat output.dat ref_output.dat
	diff -s -q output.dat ref_output.dat

output.dat: $(toplevel_module)
	./$(toplevel_module)

$(BDIR) $(VDIR) $(IDIR) $(SDIR):
	mkdir -p $@

# Create a schedule files
$(IDIR)/$(toplevel_module).sched: RSParameters.bsv $(BDIR) $(IDIR)
	$(BSC_COMP) $(BSC_FLAGS) -bdir $(BDIR) -info-dir $(IDIR) $(BSC_BAOPTS) -show-schedule -show-rule-rel \* \* -g $(toplevel_module) $(toplevel_module).bsv

#--------------------------------------------------------------------
# Clean up
#--------------------------------------------------------------------

.PHONY: clean
clean :
	rm -rf $(BDIR) $(VDIR) $(IDIR) $(SDIR) *.bo *.ba *.v *.sched *.so *.o $(toplevel_module) RSParameters.bsv *.dat

.PHONY: clean_dat
clean_dat :
	rm -rf *.dat
