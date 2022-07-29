# Masked implementation of Xoodyak
This is a side-channel protected hardware implementation of [Xoodyak](https://csrc.nist.gov/CSRC/media/Projects/lightweight-cryptography/documents/finalist-round/updated-spec-doc/xoodyak-spec-final.pdf), developed by Richard Haeussler and Abubakr Abdulgadir.

The masking scheme is configurable through the `SCA_GADGET` parameter in [design_pkg.vhd](src_rtl/design_pkg.vhd). Available options are:
- `"HPC3"`: Low-latency PINI Hardware Private Circuits [^1]
- `"HPC3+"`: HPC3+[^1] ensures additional resistance in presense of transition and glitch leakage
- `"DOM"`:  Domain-oriented Masking (DOM)


Number of random data input bits (RW) required for the selected schemes:

| Gadget    | RW   |
| --------- | ---- |
| DOM       | 384  |
| HPC3      | 768  |
| HPC3+     | 1152 |


The design is coded in VHDL hardware description language, and utilizes the latest version of GMU's [LWC Hardware API Development Package](https://github.com/GMUCERG/LWC).

Please see the accompanying [documentation](./docs/documentation.pdf) for further information.

[^1]: D. Knichel and A. Moradi, “Low-Latency Hardware Private Circuits,” 2022, https://eprint.iacr.org/2022/507
