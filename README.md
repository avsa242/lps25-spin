# lps25-spin 
------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the ST LPS25 Barometric Pressure sensor.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.


## Salient Features

* I2C connection at up to 400kHz
* SPI connection at 1MHz (P1), up to 10MHz (P2), 3 or 4-wire mode
* Read barometric pressure data (ADC words or Pascals)
* Read temperature
* Interrupts: set mask, set active state, set INT pin output drive mode, set latching, set threshold, read state
* FIFO: set mode, set threshold/watermark, set interrupt mask, read flags
* Set pressure bias/offset
* Set sensor power


## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C or SPI engine (none if bytecode-based engine is used)
* sensor.pressure.common.spinh (provided by spin-standard-library)
* sensor.temp.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* sensor.pressure.common.spin2h (provided by p2-spin-standard-library)
* sensor.temp.common.spin2h (provided by p2-spin-standard-library)


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.8.0)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.8.0)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (6.8.0)       | NuCode       | Runtime bad (SPI)     |
| P2        | SPIN2    | FlexSpin (6.8.0)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* TBD

