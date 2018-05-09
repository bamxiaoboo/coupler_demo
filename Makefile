NETCDFINC   :=  -I/opt/netCDF-intel13-without-hdf5/include
NETCDFLIB   :=  -L/opt/netCDF-intel13-without-hdf5/lib -lnetcdff -lnetcdf
FC=mpiifort
OPT= $(CCPL_LIB) $(CASE_LOCAL_INCL)
FFLAGS = -O2 -g -traceback -free -check all -heap-arrays -fp-stack-check

#Source code files, Object files and Target(Executable) filedefine
SRCS = $(wildcard *.f90)
OBJS = $(SRCS:.f90=.o)
TARGET = licom

MODSRCS = $(wildcard*.module)
MODOBJS =$(MODSRCS:.module=.o)
MODS =$(MODSRCS:.module=.mod)

#Generate Target file using Object files
$(TARGET): $(OBJS) $(MODOBJS)
	$(FC) -o $@ $^ $(OPT) $(NETCDFLIB) $(NETCDFINC) $(FFLAGS)

#Generate Object files using Source code files
%.o: %.f90 $(MODS)
	$(FC) $(OPT) $(NETCDFINC) $(FFLAGS) -c $<

$(MODS) $(MODOBJS):$(MODSRCS)
	$(FC) $(OPT) $(NETCDFINC) $(FFLAGS) -c$^

##Use "make run" can run the Target file
run:
	@./$(TARGET)

#Clean the Object files
clean:
	rm $(OBJS) $(MODOBJS) $(wildcard *.mod)

#Clean both the Object files and Target file
clean-all:
	rm $(TARGET) $(OBJS) $(MODOBJS) $(wildcard *.mod)


