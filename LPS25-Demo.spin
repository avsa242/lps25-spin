{
    --------------------------------------------
    Filename: LPS25-Demo.spin
    Author: Jesse Burt
    Description: Demo of the LPS25 driver
    Copyright (c) 2021
    Started Jun 22, 2021
    Updated Sep 28, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-defined constants
    SER_BAUD    = 115_200
    LED         = cfg#LED1

' I2C configuration
    I2C_SCL     = 28
    I2C_SDA     = 29
    I2C_HZ      = 400_000

' SPI configuration
    SPI_CS      = 0
    SPI_SPC     = 1
    SPI_SDI     = 2
    SPI_SDO     = 3                             ' 4-wire SPI only
    SPI_SDIO    = 2                             ' 3-wire SPI only
' --

    C           = 0
    F           = 1
    DAT_X_COL   = 25

OBJ

    cfg   : "core.con.boardcfg.flip"
    ser   : "com.serial.terminal.ansi"
    time  : "time"
    int   : "string.integer"
    press : "sensor.pressure.lps25.i2cspi"

PUB Main{}

    setup{}
    press.preset_active{}                       ' set defaults, but enable
                                                '   sensor power
    press.tempscale(C)                          ' C, F
    repeat
        ser.position(0, 3)
        presscalc{}
        tempcalc{}

PUB PressCalc{}

    repeat until press.pressdataready{}
    ser.str(string("Barometric pressure (Pa):"))
    ser.positionx(DAT_X_COL)
    decimal(press.presspascals{}, 10)
    ser.clearline{}
    ser.newline{}

PUB TempCalc{}

    repeat until press.tempdataready{}
    ser.str(string("Temperature: "))
    ser.positionx(DAT_X_COL)
    decimal(press.temperature, 100)
    ser.clearline{}
    ser.newline{}

PRI Decimal(scaled, divisor) | whole[4], part[4], places, tmp, sign
' Display a scaled up number as a decimal
'   Scale it back down by divisor (e.g., 10, 100, 1000, etc)
    whole := scaled / divisor
    tmp := divisor
    places := 0
    part := 0
    sign := 0
    if scaled < 0
        sign := "-"
    else
        sign := " "

    repeat
        tmp /= 10
        places++
    until tmp == 1
    scaled //= divisor
    part := int.deczeroed(||(scaled), places)

    ser.char(sign)
    ser.dec(||(whole))
    ser.char(".")
    ser.str(part)
    ser.chars(" ", 5)


PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

#ifdef LPS25_I2C
    if press.startx(I2C_SCL, I2C_SDA, I2C_HZ)
        ser.strln(string("LPS25 driver started (I2C)"))
#elseifdef LPS25_SPI3W
    if press.startx(SPI_CS, SPI_SPC, SPI_SDIO)
        ser.strln(string("LPS25 driver started (SPI-3 wire)"))
#elseifdef LPS25_SPI4W
    if press.startx(SPI_CS, SPI_SPC, SPI_SDI, SPI_SDO)
        ser.strln(string("LPS25 driver started (SPI-4 wire)"))
#endif
    else
        ser.strln(string("LPS25 driver failed to start - halting"))
        repeat

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
