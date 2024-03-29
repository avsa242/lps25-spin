{
---------------------------------------------------------------------------------------------------
    Filename:       sensor.pressure.lps25.spin
    Description:    Driver for the ST LPS25 Barometric Pressure sensor
    Author:         Jesse Burt
    Started:        Jun 22, 2021
    Updated:        Feb 6, 2024
    Copyright (c) 2024 - See end of file for terms of use.
---------------------------------------------------------------------------------------------------
}

#include "sensor.pressure.common.spinh"         ' pull in code common to all pressure sensors
#include "sensor.temp.common.spinh"             '   and temperature sensors

CON

    { default I/O settings; these can be overridden in the parent object }
    { /// default I/O settings; these can be overridden in the parent object }

    { I2C }
    SCL             = DEF_SCL
    SDA             = DEF_SDA
    I2C_FREQ        = DEF_HZ
    I2C_ADDR        = DEF_ADDR

    { SPI }
    CS              = 0
    SCK             = 1
    MOSI            = 2
    MISO            = 3

    { /// }


    SLAVE_WR        = core.SLAVE_ADDR
    SLAVE_RD        = core.SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    DEF_ADDR        = 0
    I2C_MAX_FREQ    = core.I2C_MAX_FREQ

' Operating modes
    SINGLE          = 0
    CONT            = 1

' Interrupt INT pin output modes
    PP              = 0                         ' push-pull
    OD              = 1                         ' open-drain

' FIFO Modes
    BYPASS          = 0
    FIFO            = 1
    STREAM          = 2
    STM2FIFO        = 3
    BYP2STM         = 4
    MEAN            = 6
    BYP2FIFO        = 7

VAR

    byte _CS

OBJ

{ SPI? }
#ifdef LPS25_SPI
{ decide: Bytecode SPI engine, or PASM? Default is PASM if BC isn't specified }
#   ifdef LPS25_SPI_BC
        spi:    "com.spi.25khz.nocog"           ' BC SPI engine
#   else
        spi:    "com.spi.1mhz"                  ' PASM SPI engine
#   endif
#else
{ no, not SPI - default to I2C }
#   define LPS25_I2C
{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#   ifdef LPS25_I2C_BC
        i2c:    "com.i2c.nocog"                 ' BC I2C engine
#   else
        i2c:    "com.i2c"                       ' PASM I2C engine
#   endif

#endif
    core: "core.con.lps25"                      ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB null()
' This is not a top-level object

#ifdef LPS25_I2C
PUB start(): status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom IO pins and I2C bus frequency
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)             ' wait for device startup
            if ( dev_id() == core.DEVID_RESP )  ' verify the device responds
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

#elseifdef LPS25_SPI

PUB start(): status
' Start the driver using default I/O settings
    return startx(CS, SCK, MOSI, MISO)


PUB startx(CS_PIN, SPC_PIN, SDI_PIN, SDO_PIN): status
' Start using custom IO pins and I2C bus frequency
    if (    lookdown(CS_PIN: 0..31) and lookdown(SPC_PIN: 0..31) and ...
            lookdown(SDI_PIN: 0..31) and lookdown(SDO_PIN: 0..31 ) )
        _CS := CS_PIN
        outa[_CS] := 1
        dira[_CS] := 1
        if ( status := spi.init(SPC_PIN, SDI_PIN, SDO_PIN, core.SPI_MODE) )
            time.usleep(core.T_POR)             ' wait for device startup
            if ( SDI_PIN == SDO_PIN )           ' use 3-wire SPI mode if MOSI/MISO are the same
                spi_mode(3)
            else
                spi_mode(4)
            if ( dev_id() == core.DEVID_RESP )  ' validate device
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE
#endif

PUB stop()
' Stop the driver
#ifdef LPS25_I2C
    i2c.deinit()
#elseifdef LPS25_SPI
    spi.deinit()
#endif

PUB defaults()
' Set factory defaults
    reset()

PUB preset_active()
' Like factory defaults, but
'   * Enable sensor power
'   * Set data rate to 25Hz
'   * Enable block data updates (private)
    reset()
    powered(true)
    blk_data_upd(true)
    press_data_rate(25)

PUB dev_id(): id
' Read device identification
    readreg(core.WHO_AM_I, 1, @id)

PUB fifo_data_overrun(): flag
' Flag indicating FIFO is full and at least one sample has been overwritten
'   Returns: TRUE (-1), or FALSE (0)
    readreg(core.FIFO_STATUS, 1, @flag)
    return (((flag >> core.OVR) & 1) == 1)

PUB fifo_empty(): flag
' Flag indicating FIFO is empty
'   Returns: TRUE (-1), or FALSE (0)
    readreg(core.FIFO_STATUS, 1, @flag)
    return (((flag >> core.EMPTY_FIFO) & 1) == 1)

PUB fifo_ena(state): curr_state
' Enable FIFO
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.CTRL_REG2, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.FIFO_EN
        other:
            return ((curr_state >> core.FIFO_EN) & 1) == 1

    state := ((curr_state & core.FIFO_EN_MASK) | state)
    writereg(core.CTRL_REG2, 1, @state)

PUB fifo_full(): flag
' Flag indicating FIFO is full (32 unread samples)
'   Returns: TRUE (-1), or FALSE (0)
    return fifo_lvl_high()

PUB fifo_int_mask(mask): curr_mask
' Set FIFO interrupt mask
'   Bits: 3..0
'       3: FIFO empty flag
'       2: FIFO threshold/watermark: full
'       1: FIFO full (FIFO mode), or overrun (STREAM mode)
'       0: data ready flag
    case mask
        %0000..%1111:
            writereg(core.CTRL_REG4, 1, @mask)
        other:
            curr_mask := 0
            readreg(core.CTRL_REG4, 1, @curr_mask)

PUB fifo_lvl_high(): flag
' Flag indicating FIFO is greater than or equal to level set with fifo_thresh()
'   Returns: TRUE (-1) or FALSE (0)
    readreg(core.FIFO_STATUS, 1, @flag)
    return (((flag >> core.FTH_FIFO) & 1) == 1)

PUB fifo_lvl_low(): flag
' Flag indicating FIFO is less than level set with fifo_thresh()
'   Returns: TRUE (-1) or FALSE (0)
    readreg(core.FIFO_STATUS, 1, @flag)
    return (((flag >> core.FTH_FIFO) & 1) == 0)

PUB fifo_mean_avgs(nr_samples): curr_samps
' Set number of samples used in moving average when fifo_mode() == MEAN
'   Valid values: 2, 4, 8, 16, 32
'   Any other value polls the chip and returns the current setting
    curr_samps := 0
    readreg(core.FIFO_CTRL, 1, @curr_samps)
    case nr_samples
        2, 4, 8, 16, 32:
            nr_samples -= 1
        other:
            return (curr_samps & core.WTM_POINT_BITS) + 1

    nr_samples := ((curr_samps & core.WTM_POINT_MASK) | nr_samples)
    writereg(core.FIFO_CTRL, 1, @nr_samples)

PUB fifo_mean_data_rate(rate): curr_rate
' Set FIFO output data rate when fifo_mode() == MEAN
'   Valid values:
'       0: data rate = press_data_rate()
'       1: data rate is decimated to 1Hz (internally, averaging still occurs at press_data_rate())
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core.CTRL_REG2, 1, @curr_rate)
    case rate
        0, 1:
            rate <<= core.FIFO_MEAN_DEC
        other:
            return ((curr_rate >> core.FIFO_MEAN_DEC) & 1)

    rate := ((curr_rate & core.FFO_MN_DEC_MASK) | rate)
    writereg(core.CTRL_REG2, 1, @rate)

PUB fifo_mode(mode): curr_mode
' Set FIFO operating mode
'   Valid values:
'       BYPASS (0): FIFO disabled
'       FIFO (1): collect data, then stop when FIFO is full
'       STREAM (2): continuously fill FIFO; oldest data discarded first
'       STM2FIFO (3): STREAM mode until trigger is deasserted, then FIFO mode
'       BYP2STM (4): BYPASS mode until trigger is deasserted, then STREAM mode
'       MEAN (6): moving average of n-set of samples (n set by fifo_mean_avgs())
'       BYP2FIFO (7): BYPASS mode until trigger is deasserted, then FIFO mode
'   Any other value polls the chip and returns the current setting
'   NOTE: When mode is MEAN, the FIFO is inactive. The data read by press_data() is the result of
'       the moving average
    curr_mode := 0
    readreg(core.FIFO_CTRL, 1, @curr_mode)
    case mode
        BYPASS, FIFO, STREAM, STM2FIFO, BYP2STM, MEAN, BYP2FIFO:
            mode <<= core.F_MODE
        other:
            return ((curr_mode >> core.F_MODE) & core.F_MODE_BITS)

    mode := ((curr_mode & core.F_MODE_MASK) | mode)
    writereg(core.FIFO_CTRL, 1, @mode)

PUB fifo_thresh(level): curr_lvl
' Set FIFO threshold/watermark level, in number of samples
'   Valid values: 1..32
'   Any other value polls the chip and returns the current setting
    curr_lvl := 0
    readreg(core.FIFO_CTRL, 1, @curr_lvl)
    case level
        1..32:
            level -= 1
        other:
            return ((curr_lvl & core.WTM_POINT_BITS)) + 1

    level := ((curr_lvl & core.WTM_POINT_MASK) | level)
    writereg(core.FIFO_CTRL, 1, @level)

PUB fifo_nr_unread(): nr_samples | isempty
' Number of unread samples currently in FIFO
'   Returns: 0..32
    readreg(core.FIFO_STATUS, 1, @nr_samples)
    isempty := (((nr_samples >> core.EMPTY_FIFO) & 1) == 1)
    nr_samples &= core.FSS_BITS
    ' a value of zero in the FSS field has a different meaning, depending on
    '   the EMPTY_FIFO field:
    if nr_samples == 0                          ' if FSS is 0:
        if isempty                              '  if EMPTY_FIFO is 0, then
            return 0                            '  there _are_ 0 unread samples
        else                                    '  however, if EMPTY_FIFO is 1,
            return 1                            '  it means there's 1 sample
    else                                        ' otherwise
        return (nr_samples + 1)                 '  nr_samples = FSS+1

PUB int_polarity(state): curr_state
' Set interrupt active state/polarity
'   Valid values:
'       0: active low
'       1: active high
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.CTRL_REG3, 1, @curr_state)
    case state
        0, 1:
            state <<= core.INT_H_L
        other:
            return ((curr_state >> core.INT_H_L) & 1)

    state := ((curr_state & core.INT_H_L_MASK) | state)
    writereg(core.CTRL_REG3, 1, @state)

PUB interrupt(): mask
' Read interrupt state
'   Returns: bitmask (2..0)
'       2: interrupt active
'       1: pressure low
'       0: pressure high
    mask := 0
    readreg(core.INT_SOURCE, 1, @mask)

PUB int_mask(mask): curr_mask
' Set interrupt mask
'   Bits: 1..0
'       1: pressure low
'       0: pressure high
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core.INTERRUPT_CFG, 1, @curr_mask)
    case mask
        %00..%11:
        other:
            return curr_mask & core.PE_BITS

    mask := ((curr_mask & core.PE_MASK) | mask)
    writereg(core.INTERRUPT_CFG, 1, @mask)

PUB int_mode(mode): curr_mode
' Set interrupt pin output mode
'   Valid values:
'       PP (0): Push-pull
'       OD (1): Open-drain
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core.CTRL_REG3, 1, @curr_mode)
    case mode
        PP, OD:
            mode <<= core.PP_OD
        other:
            return ((curr_mode >> core.PP_OD) & 1)

    mode := ((curr_mode & core.PP_OD_MASK) | mode)
    writereg(core.CTRL_REG3, 1, @mode)

PUB int_ena(state): curr_state
' Enable interrupt generation
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.CTRL_REG1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.DIFF_EN
        other:
            return (((curr_state >> core.DIFF_EN) & 1) == 1)

    state := ((curr_state & core.DIFF_EN_MASK) | state)
    writereg(core.CTRL_REG1, 1, @state)

PUB int_latch_ena(state): curr_state
' Latch interrupts
'   Valid values:
'       FALSE (0): interrupt clears when condition is no longer met
'       TRUE (-1, 1): interrupt clears only when state is read with interrupt()
    curr_state := 0
    readreg(core.INTERRUPT_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.LIR
        other:
            return (((curr_state >> core.LIR) & 1) == 1)

    state := ((curr_state & core.LIR_MASK) | state)
    writereg(core.INTERRUPT_CFG, 1, @state)

PUB measure() | tmp
' Perform measurement
    tmp := core.MEASURE
    writereg(core.CTRL_REG2, 1, @tmp)

PUB opmode(mode): curr_mode
' Set operating mode
'   Valid values:
'       SINGLE (0): Single-shot/standby
'       CONT (1): Continuous measurement
'   Any other value polls the chip and returns the current setting
'   NOTE: If press_data_rate() is set to _any_ non-zero value, this method will
'       return '1' for the current setting
'   NOTE: CONT sets output data rate to 1Hz
    case mode
        SINGLE:
            press_data_rate(0)
        CONT:
            press_data_rate(1)
        other:
            return ||(press_data_rate(-2) <> 0)

PUB powered(state): curr_state
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.CTRL_REG1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.PD
        other:
            return ((curr_state >> core.PD) & 1) == 1

    state := ((curr_state & core.PD_MASK) | state)
    writereg(core.CTRL_REG1, 1, @state)

PUB press_bias(offs): curr_offs
' Set pressure bias/offset
'   Valid values: -32768..32767
'   Any other value polls the chip and returns the current setting
    case offs
        -32768..32767:
            writereg(core.RPDS_L, 2, @offs)
        other:
            curr_offs := 0
            readreg(core.RPDS_L, 2, @curr_offs)
            return

PUB press_data(): press_adc
' Read pressure data
'   Returns: s24
    readreg(core.PRESS_OUT_XL, 3, @press_adc)

PUB press_data_overrun(): flag
' Flag indicating pressure data has overrun
    readreg(core.STATUS_REG, 1, @flag)
    return ((flag & core.POVR) <> 0)

PUB press_data_rate(rate): curr_rate
' Set pressure output data rate, in Hz
'   Valid values: 0, 1, 7, 12 (12.5), 25
'   Any other value polls the chip and returns the current setting
'   NOTE: A value of 0 is equivalent to setting opmode(SINGLE)
    curr_rate := 0
    readreg(core.CTRL_REG1, 1, @curr_rate)
    case rate
        0, 1, 7, 12, 25:
            rate := lookdownz(rate: 0, 1, 7, 12, 25) << core.ODR
        other:
            curr_rate := (curr_rate >> core.ODR) & core.ODR_BITS
            return lookupz(curr_rate: 0, 1, 7, 12, 25)

    rate := ((curr_rate & core.ODR_MASK) | rate)
    writereg(core.CTRL_REG1, 1, @rate)

PUB press_data_rdy(): flag
' Flag indicating pressure data ready
    readreg(core.STATUS_REG, 1, @flag)
    return ((flag & core.PDRDY) <> 0)

PUB press_int_set_thresh(thresh)
' Set threshold for pressure interrupt source, in hPa
'   Valid values: 0..1260 (clamped to range)
    thresh := (0 #> thresh <# 1260) * 16
    writereg(core.THS_P_L, 2, @thresh)
 
PUB press_int_thresh(): curr_thr
' Get threshold for pressure interrupt source, in hPa
    curr_thr := 0
    readreg(core.THS_P_L, 2, @curr_thr)
    return (curr_thr / 16)

PUB press_osr(ratio): curr_ratio
' Set pressure output data oversampling ratio
'   Valid values: 8, 32, 128, 512
'   Any other value polls the chip and returns the current setting
    curr_ratio := 0
    readreg(core.RES_CONF, 1, @curr_ratio)
    case ratio
        8, 32, 128, 512:
            ratio := lookdownz(ratio: 8, 32, 128, 512)
        other:
            curr_ratio &= core.AVGP_BITS
            return lookupz(curr_ratio: 8, 32, 128, 512)

    ratio := ((curr_ratio & core.AVGP_MASK) | ratio)
    writereg(core.RES_CONF, 1, @ratio)

PUB press_ref_lvl(): press
' Get reference pressure level
    press := 0
    readreg(core.REF_P_XL, 3, @press)
    return press

PUB press_set_ref_lvl(press)
' Set reference pressure level, in Pascals
'   Valid values: 0..409_599 (0 to disable; clamped to range)
    press := ((0 #> press <# 409_599) / 100) * 4096
    writereg(core.REF_P_XL, 3, @press)

PUB press_word2pa(p_word): p_pa
' Convert pressure ADC word to pressure in Pascals
    return ((p_word * 100) / 4096) * 10

PUB reset() | tmp
' Reset the device
    tmp := core.RESET
    writereg(core.CTRL_REG2, 1, @tmp)

PUB temp_data(): temp_adc
' Read temperature data
'   Returns: s16
    readreg(core.TEMP_OUT_L, 2, @temp_adc)
    return ~~temp_adc

PUB temp_data_overrun(): flag
' Flag indicating temperature data has overrun
    readreg(core.STATUS_REG, 1, @flag)
    return ((flag & core.TOVR) <> 0)

PUB temp_data_rdy(): flag
' Flag indicating temperature data ready
    readreg(core.STATUS_REG, 1, @flag)
    return ((flag & core.TDRDY) <> 0)

PUB temp_osr(ratio): curr_ratio
' Set temperature output data oversampling ratio
'   Valid values: 8, 16, 32, 64
'   Any other value polls the chip and returns the current setting
    curr_ratio := 0
    readreg(core.RES_CONF, 1, @curr_ratio)
    case ratio
        8, 16, 32, 64:
            ratio := lookdownz(ratio: 8, 16, 32, 64) << core.AVGT
        other:
            curr_ratio := (curr_ratio >> core.AVGT) & core.AVGT_BITS
            return lookupz(curr_ratio: 8, 16, 32, 64)

    ratio := ((curr_ratio & core.AVGT_MASK) | ratio)
    writereg(core.RES_CONF, 1, @ratio)

PUB temp_word2deg(temp_word): temp
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    temp := ((temp_word * 100) / 480) + 42_50
    case _temp_scale
        C:
            return temp
        F:
            return ((temp * 9_00) / 5_00) + 32_00
        other:
            return FALSE

PRI blk_data_upd(state): curr_state
' Enable block data updates - don't update output data until
'   H (MSB), L (MB) and XL (LSB) updated
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core.CTRL_REG1, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.BDU
        other:
            return ((curr_state >> core.BDU) & 1) == 1

    state := ((curr_state & core.BDU_MASK) | state)
    writereg(core.CTRL_REG1, 1, @state)

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate reg #
        core.REF_P_XL, core.PRESS_OUT_XL, core.TEMP_OUT_L, core.THS_P_L, core.RPDS_L:
#ifdef LPS25_I2C
            reg_nr |= core.MB_I2C               ' set multi-byte r/w bit
#elseifdef LPS25_SPI
            reg_nr |= core.MS_SPI               ' set multi-byte r/w bit
#endif
        $0F, $10, $20..$27, $2E..$2F:
        other:                                  ' invalid reg_nr
            return

#ifdef LPS25_I2C
    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.start()
    i2c.wr_byte(SLAVE_RD)

    ' read LSByte to MSByte
    i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c.NAK)
    i2c.stop()
#elseifdef LPS25_SPI
    outa[_CS] := 0
    spi.wr_byte(reg_nr | core.READ_SPI)
    spi.rdblock_lsbf(ptr_buff, nr_bytes)
    outa[_CS] := 1

#endif

PRI spi_mode(mode)
' Set SPI interface mode
'   3: 3-wire
'   4: 4-wire
'   Any other value is ignored
    case mode
        3, 4:
            ' 3-wire mode clears the bit, 4-wire sets it
            ' subtract 3 from the param, so it's 0 or 1,
            ' then flip the bit
            mode := ((mode - 3) ^ 1)
        other:
            return

    writereg(core.CTRL_REG1, 1, @mode)

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr                                 ' validate reg #
        core.REF_P_XL, core.THS_P_L, core.RPDS_L:
#ifdef LPS25_I2C
            reg_nr |= core.MB_I2C               ' set multi-byte r/w bit
#elseifdef LPS25_SPI
            reg_nr |= core.MS_SPI               ' set multi-byte r/w bit
#endif
        $10, $20..$24, $2E:
        other:                                  ' invalid reg_nr
            return

#ifdef LPS25_I2C
    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)

    ' write LSByte to MSByte
    i2c.wrblock_lsbf(ptr_buff, nr_bytes)
    i2c.stop()
#elseifdef LPS25_SPI
    outa[_CS] := 0
    spi.wr_byte(reg_nr)
    spi.wrblock_lsbf(ptr_buff, nr_bytes)
    outa[_CS] := 1
#endif

DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

