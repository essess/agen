# agen

A small VHDL project which takes in a raw toothed wheel input from a crank sensor on a traditional internal combustion engine and produces an angle count as its output.

* up to 512 physical teeth supported
* generates up to 512 subteeth per tooth
* handles an RPM input in excess of 200KRPM
* handles multiple gaps per revolution (consider a Denso 36-2-2-2)
* gap sizes of 1 and 2 teeth are handled transparently and can be freely intermixed per revolution