package blackbox

import chisel3._

class UartDummy extends ExtModule {
  val io = FlatIO(new Bundle {
    val clock = Input(Clock())
    val en_i = Input(Bool())
    val data_i = Input(UInt(32.W))
    val strb_i = Input(UInt(4.W))
  })

  addResource("UartDummy.sv")
}
