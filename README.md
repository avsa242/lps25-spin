# lps25-spin 
------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the ST LPS25 Barometric Pressure sensor.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) ~~or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P)~~. Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

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
* 1 extra core/cog for the PASM I2C engine
*or*
* 1 extra core/cog for the PASM SPI engine

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FlexSpin (tested with 6.0.0-beta)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [ ] TBD

