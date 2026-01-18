package perip

import chisel3._
import chisel3.util._
import general.AXI4LiteParams
import general.AXI4LiteSlaveIO

class UARTStub(params: AXI4LiteParams) extends Module {
  val io = IO(new Bundle {
    val axi = new AXI4LiteSlaveIO(params)
  })



}
