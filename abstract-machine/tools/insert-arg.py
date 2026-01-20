#!/usr/bin/env python3

from sys import argv

#insert-arg: image
#	@python3 $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) $(MAINARGS_PLACEHOLDER) "$(mainargs)"
# argv[1] = $(IMAGE).bin
# argv[2] = $(MAINARGS_MAX_LEN)
# argv[3] = $(MAINARGS_PLACEHOLDER)
# argv[4] = "$(mainargs)"

bin = argv[1]
max_len = int(argv[2])
placeholder = argv[3]
mainargs = argv[4]

if len(mainargs) >= max_len:
    print("Error: mainargs should not be longer than {0} bytes\n".format(max_len))
    exit(1)
print(f"mainargs={ format(mainargs) }")

fp = open(bin, 'r+b')
data = fp.read()
idx = data.find(str.encode(placeholder))
if idx == -1:
    print("Error: placeholder not found!\n")
    exit(1)
fp.seek(idx)
mainargs_pad = str.encode(mainargs) + ((max_len - len(mainargs)) * str.encode("\0"))
if len(mainargs_pad) != max_len:
    print("Error: len(mainargs_pad) != max_len\n")
    exit(1)
fp.write(mainargs_pad)
fp.close()
