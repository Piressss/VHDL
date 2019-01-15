#!/usr/bin/python

from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Add Verification Components
vu.add_verification_components()

# Create library 'lib'
lib = vu.add_library("mem_lib")
lib.add_source_files("../*.vhd")

# Add all TBs
lib = vu.add_library("mem_lib_tb")
lib.add_source_files("*.vhd")
ram_test = lib.entity("ram_tb")

for test in ram_test.get_tests():
    if test.name == "ram_register_test":
        test.set_generic("addr_width_g", 10)
        test.set_generic("register_en_g", "true")
    elif test.name == "ram_no_register_test":
        test.set_generic("addr_width_g", 11)
        test.set_generic("register_en_g", "false")

# Run vunit function
vu.main()
