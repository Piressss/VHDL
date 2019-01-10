#!/usr/bin/python

from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Add Verification Components
vu.add_verification_components()

# Create library 'lib'
lib = vu.add_library("axis_lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("../*.vhd")

# Add all TBs
lib = vu.add_library("axis_lib_tb")
lib.add_source_files("*.vhd")
lib.set_generic("counter_bits_g", 15)

# Run vunit function
vu.main()
