MITgcm.jl
=========
Post-processing utilities for the MITgcm.

Goals
-----
This package aims to provide similar utility to the Python packages developed by
Ryan Abernathy and Ian Fenty, with a simpler interface. The data objects that users
work with will work just like raw arrays and provide an experience more similar to
the older `gcmfaces` Matlab package by Gael Forget.

In comparison with Gael's Julia package, this one should offer better performance
by exploiting the full potential of Julia's type system.

The first priority when developing this package is memory efficiency so that it will
be useful to work with large datasets even on ordinary workstation hardware. CPU
efficiency is sacrificed to this end, but is a secondary priority. Finally, ease of
use is considered for users unfamiliar with the Julia language.

