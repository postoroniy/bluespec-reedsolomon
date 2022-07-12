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

default : mkTestBench

# Bluespec sources
srcdir  = .
sim_srcdir = $(srcdir)/simulate

toplevel_module = mkTestBench

cppdir = $(srcdir)

cppsrcs = $(cppdir)/preproc.cpp

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

# compile & run the preproc to generate the GF inverse logic.

preproc.o: $(notdir $(cppsrcs))
	$(CXX) -c -o preproc.o preproc.cpp

preproc: preproc.o
	$(CXX) -o preproc preproc.o

GFInv.bsv: preproc
	./preproc RSParameters.bsv GFInv.bsv

BSC_COMP = bsc
BSC_FLAGS = -u -aggressive-conditions -keep-fires -no-show-method-conf \
	-steps-warn-interval 200000 -steps-max-intervals 10 -show-schedule +RTS -K4000M -RTS

BSC_VOPTS = -elab -verilog
BSC_BAOPTS = -sim

BDIR = build
VDIR = verilog
IDIR = info
SDIR = sim

# run gcc
file_interface.o: file_interface.cpp
	gcc -c -DDATA_FILE_PATH=\"./input.dat\" -DOUT_DATA_FILE_PATH=\"./output.dat\" file_interface.cpp -fPIC

# Run the bluespec compiler
mkTestBench.ba: GFInv.bsv $(BDIR) $(VDIR) $(IDIR)
	$(BSC_COMP) $(BSC_FLAGS) -bdir $(BDIR) -info-dir $(IDIR) -vdir $(VDIR) $(BSC_VOPTS) mkReedSolomon.bsv
	$(BSC_COMP) $(BSC_FLAGS) -bdir $(BDIR) -info-dir $(IDIR) -vdir $(VDIR) $(BSC_BAOPTS) -g $(toplevel_module) $(toplevel_module).bsv

mkTestBench: mkTestBench.ba file_interface.o $(SDIR)
	$(BSC_COMP) $(BSC_BAOPTS) -simdir $(SDIR) -e $(toplevel_module) $(BDIR)/*.ba file_interface.o

$(BDIR) $(VDIR) $(IDIR) $(SDIR):
	mkdir -p $@

# Create a schedule file
schedule_rpt = schedule.rpt
$(schedule_rpt):
	$(BSC_COMP) $(BSC_FLAGS) -bdir $(BDIR) $(BSC_BAOPTS) -show-schedule -show-rule-rel \* \* -g $(toplevel_module) $(toplevel_module).bsv

#--------------------------------------------------------------------
# Clean up
#--------------------------------------------------------------------

junk += $(schedule_rpt) diff.out $(BDIR) $(VDIR) $(IDIR) $(SDIR)

.PHONY: clean
clean :
	rm -rf $(junk) *.cxx *.h *.so *.o a.out preproc GFInv.bsv
