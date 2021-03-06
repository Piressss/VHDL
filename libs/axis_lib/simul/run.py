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

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("../*.vhd")

# Add all TBs
lib = vu.add_library("axis_lib_tb")
lib.add_source_files("*.vhd")

counter_test = lib.entity("axi_stream_count_gen_tb") 
counter_test.set_generic("counter_bits_g", 15)

fifo_test = lib.entity("axis_fifo_tb")
for test in fifo_test.get_tests():
    if test.name == "axis_fifo_test0":
        test.set_generic("addr_width_g", 12)
        test.set_generic("data_width_g", 14)
        test.set_generic("user_width_g", 2)
        test.set_generic("fifo_register_g", "true")
    elif test.name == "axis_fifo_test1":
        test.set_generic("addr_width_g", 11)
        test.set_generic("data_width_g", 13)
        test.set_generic("user_width_g", 0)
        test.set_generic("fifo_register_g", "true")
    elif test.name == "axis_fifo_test2":
        test.set_generic("addr_width_g", 11)
        test.set_generic("data_width_g", 13)
        test.set_generic("user_width_g", 3)
        test.set_generic("fifo_register_g", "false")
    elif test.name == "axis_fifo_test3":
        test.set_generic("addr_width_g", 11)
        test.set_generic("data_width_g", 12)
        test.set_generic("user_width_g", 4)
        test.set_generic("fifo_register_g", "true")


# Run vunit function
vu.main()
