{
    --------------------------------------------
    Filename: sensor.pressure.lps25.i2c.spin
    Author: Jesse Burt
    Description: Driver for the ST LPS25 Barometric Pressure sensor
    Copyright (c) 2021
    Started Jun 22, 2021
    Updated Jun 24, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR          = core#SLAVE_ADDR
    SLAVE_RD          = core#SLAVE_ADDR|1

    DEF_SCL           = 28
    DEF_SDA           = 29
    DEF_HZ            = 100_000
    I2C_MAX_FREQ      = core#I2C_MAX_FREQ

' Temperature scales
    C               = 0
    F               = 1

VAR

    byte _temp_scale

OBJ

' choose an I2C engine below
    i2c : "com.i2c"                             ' PASM I2C engine (up to ~800kHz)
    core: "core.con.lps25"                      ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate pins and bus freq
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            if i2c.present(SLAVE_WR)            ' test device bus presence
                if deviceid{} == core#DEVID_RESP' validate device 
                    return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB Stop{}

    i2c.deinit{}

PUB Defaults{}
' Set factory defaults
    reset{}

PUB Preset_Active{}
' Like factory defaults, but
'   * Enable sensor power
'   * Set data rate to 25Hz
'   * Enable block data updates (private)
    reset{}
    powered(true)
    blockdataupdate(true)
    pressdatarate(25)

PUB DeviceID{}: id
' Read device identification
    readreg(core#WHO_AM_I, 1, @id)

PUB Powered(state): curr_state
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#PD
        other:
            return ((curr_state >> core#PD) & 1) == 1

    state := ((curr_state & core#PD_MASK) | state)
    writereg(core#CTRL_REG1, 1, @state)

PUB PressBias(offs): curr_offs
' Set pressure bias/offset
'   Valid values: -32768..32767
'   Any other value polls the chip and returns the current setting
    case offs
        -32768..32767:
            writereg(core#RPDS_L, 2, @offs)
        other:
            curr_offs := 0
            readreg(core#RPDS_L, 2, @curr_offs)
            return

PUB PressData{}: press_adc
' Read pressure data
'   Returns: s24
    readreg(core#PRESS_OUT_XL, 3, @press_adc)

PUB PressDataOverrun{}: flag
' Flag indicating pressure data has overrun
    readreg(core#STATUS_REG, 1, @flag)
    return ((flag & core#POVR) <> 0)

PUB PressDataRate(rate): curr_rate
' Set pressure output data rate, in Hz
'   Valid values: 0, 1, 7, 12 (12.5), 25
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        0, 1, 7, 12, 25:
            rate := lookdownz(rate: 0, 1, 7, 12, 25) << core#ODR
        other:
            curr_rate := (curr_rate >> core#ODR) & core#ODR_BITS
            return lookupz(curr_rate: 0, 1, 7, 12, 25)

    rate := ((curr_rate & core#ODR_MASK) | rate)
    writereg(core#CTRL_REG1, 1, @rate)

PUB PressDataReady{}: flag
' Flag indicating pressure data ready
    readreg(core#STATUS_REG, 1, @flag)
    return ((flag & core#PDRDY) <> 0)

PUB PressOSR(ratio): curr_ratio
' Set pressure output data oversampling ratio
'   Valid values: 8, 32, 128, 512
'   Any other value polls the chip and returns the current setting
    curr_ratio := 0
    readreg(core#RES_CONF, 1, @curr_ratio)
    case ratio
        8, 32, 128, 512:
            ratio := lookdownz(ratio: 8, 32, 128, 512)
        other:
            curr_ratio &= core#AVGP_BITS
            return lookupz(curr_ratio: 8, 32, 128, 512)

    ratio := ((curr_ratio & core#AVGP_MASK) | ratio)
    writereg(core#RES_CONF, 1, @ratio)

PUB PressPascals{}: press_p
' Read pressure data, in tenths of a Pascal
    return ((pressdata{} * 100) / 4096) * 10

PUB Reset{} | tmp
' Reset the device
    tmp := core#RESET
    writereg(core#CTRL_REG2, 1, @tmp)

PUB TempData{}: temp_adc
' Read temperature data
'   Returns: s16
    readreg(core#TEMP_OUT_L, 2, @temp_adc)
    return ~~temp_adc

PUB TempDataOverrun{}: flag
' Flag indicating temperature data has overrun
    readreg(core#STATUS_REG, 1, @flag)
    return ((flag & core#TOVR) <> 0)

PUB TempDataReady{}: flag
' Flag indicating temperature data ready
    readreg(core#STATUS_REG, 1, @flag)
    return ((flag & core#TDRDY) <> 0)

PUB Temperature{}: temp
' Current temperature, in hundredths of a degree
'   Returns: Integer
'   (e.g., 2105 is equivalent to 21.05 deg C)
    temp := calctemp(tempdata{})
    case _temp_scale
        C:
        F:
            return ((temp * 9_00) / 5_00) + 32_00

PUB TempScale(scale): curr_scale
' Set temperature scale used by Temperature method
'   Valid values:
'      *C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F:
            _temp_scale := scale
        other:
            return _temp_scale

PRI blockDataUpdate(state): curr_state
' Enable block data updates - don't update output data until
'   H (MSB), L (MB) and XL (LSB) updated
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#BDU
        other:
            return ((curr_state >> core#BDU) & 1) == 1

    state := ((curr_state & core#BDU_MASK) | state)
    writereg(core#CTRL_REG1, 1, @state)

PRI calcTemp(temp_word): temp_c | whole, part
' Calculate temperature in degrees Celsius, given ADC word
    return ((temp_word * 100) / 480) + 42_50

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        core#REF_P_XL, core#PRESS_OUT_XL, core#TEMP_OUT_L, core#THS_P_L, {
}       core#RPDS_L:
            reg_nr |= core#MB_I2C               ' set multi-byte r/w bit
        $0F, $10, $20..$27, $2E..$2F:
        other:                                  ' invalid reg_nr
            return

    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg_nr
    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.start{}
    i2c.wr_byte(SLAVE_RD)

    ' read LSByte to MSByte
    i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c#NAK)
    i2c.stop{}

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        core#REF_P_XL, core#THS_P_L, core#RPDS_L:
            reg_nr |= core#MB_I2C               ' set multi-byte r/w bit
        $10, $20..$24, $2E:
        other:                                  ' invalid reg_nr
            return

    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg_nr
    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, 2)

    ' write LSByte to MSByte
    i2c.wrblock_lsbf(ptr_buff, nr_bytes)
    i2c.stop{}

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
