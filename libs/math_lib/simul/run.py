#!/usr/bin/python

from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Add Verification Components
vu.add_verification_components()

# Creater base lib
lib = vu.add_library("base_lib")
lib.add_source_files("../../base_lib/*.vhd")

# Creater base lib
lib = vu.add_library("mem_lib")
lib.add_source_files("../../mem_lib/*.vhd")

# Create library 'lib'
lib = vu.add_library("axis_lib")
lib.add_source_files("../../axis_lib/*.vhd")

# Create library 'lib'
lib = vu.add_library("math_lib")
lib.add_source_files("../*.vhd")

# Add all TBs
lib = vu.add_library("math_lib_tb")
lib.add_source_files("*.vhd")

adder_test = lib.entity("axis_parallel_adder_tb") 

for test in adder_test.get_tests():
    if test.name == "axis_add_test_0":
        test.set_generic("data_width_g" , 32)
        test.set_generic("num_words_g"   , 6)

# Run vunit function
vu.main()
