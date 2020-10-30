////////////////////////////////////////////////////////////////////
// Values
////////////////////////////////////////////////////////////////////
`define WIDTH_MSG_CNT_BYTES  2
`define WIDTH_MSG_LEN_BYTES  2

`define BITS_PER_BYTE        8

`define WIDTH_OUT_DATA_BYTES `MAX_MSG_BYTES
`define WIDTH_IN_EMPTY_BITS  $clog2(`WIDTH_IN_DATA_BYTES)

`define WIDTH_IN_DATA_BITS   (`WIDTH_IN_DATA_BYTES  * `BITS_PER_BYTE)
`define WIDTH_OUT_DATA_BITS  (`WIDTH_OUT_DATA_BYTES * `BITS_PER_BYTE)

////////////////////////////////////////////////////////////////////
// Functions
////////////////////////////////////////////////////////////////////
`define bitwidth_of_cnt(x)   $clog2(x);
`define bitwidth_of_val(x)   $clog2(x + 1);

`define ceil(x,y)            ( x % y)      ? \
                             ((x / y) + 1) : \
                             ( x / y);
