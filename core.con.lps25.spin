{
    --------------------------------------------
    Filename: core.con.lps25.spin
    Author: Jesse Burt
    Description: LPS25-specific low-level constants
    Copyright (c) 2021
    Started Jun 22, 2021
    Updated Jun 22, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ        = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR          = $5D << 1                  ' 7-bit format slave address
    T_POR               = 1_000                     ' startup time (usecs)

    DEVID_RESP          = $BD                       ' device ID expected response

' Register definitions
' RESERVED $00..$07
    REF_P_XL            = $08
    REF_P_L             = $09
    REF_P_H             = $0A
' RESERVED $0D..$0E
    WHO_AM_I            = $0F
    RES_CONF            = $10
' RESERVED $11..$1F
    CTRL_REG1           = $20
    CTRL_REG1_MASK      = $FF
        PD              = 7
        ODR             = 4
        DIFF_EN         = 3
        BDU             = 2
        RESET_AZ        = 1
        SIM             = 0
        ODR_BITS        = %111
        PD_MASK         = (1 << PD) ^ CTRL_REG1_MASK
        ODR_MASK        = (ODR_BITS << ODR) ^ CTRL_REG1_MASK
        DIFF_EN_MASK    = (1 << DIFF_EN) ^ CTRL_REG1_MASK
        BDU_MASK        = (1 << BDU) ^ CTRL_REG1_MASK
        RESET_AZ_MASK   = (1 << RESET_AZ) ^ CTRL_REG1_MASK
        SIM_MASK        = 1 ^ CTRL_REG1_MASK

    CTRL_REG2           = $21
    CTRL_REG3           = $22
    CTRL_REG4           = $23
    INTERRUPT_CFG       = $24
    INT_SOURCE          = $25
' RESERVED $26
    STATUS_REG          = $27
    PRESS_OUT_XL        = $28
    PRESS_OUT_L         = $29
    PRESS_OUT_H         = $2A
    TEMP_OUT_L          = $2B
    TEMP_OUT_H          = $2C
' RESERVED $2D
    FIFO_CTRL           = $2E
    FIFO_STATUS         = $2F
    THS_P_L             = $30
    THS_P_H             = $31
' RESERVED $32..$38
    RPDS_L              = $39
    RPDS_H              = $3A

PUB Null{}
' This is not a top-level object

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

