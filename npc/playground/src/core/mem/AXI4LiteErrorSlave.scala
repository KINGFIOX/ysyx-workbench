package core.mem

import chisel3._
import chisel3.util._
import core.general.{AXI4LiteSlaveIO, AXI4LiteParams, AXI4LiteResp}

class AXI4LiteErrorSlave(params: AXI4LiteParams) extends Module {
  val io = IO(new Bundle {
    val axi = new AXI4LiteSlaveIO(params)
  })

  // ========== 读操作状态机 ==========
  object ReadState extends ChiselEnum {
    val idle, done = Value
  }

  private val read_state = RegInit(ReadState.idle)

  io.axi.ar.ready := (read_state === ReadState.idle)
  io.axi.r.valid := (read_state === ReadState.done)
  io.axi.r.bits.data := 0.U
  io.axi.r.bits.resp := AXI4LiteResp.DECERR

  switch(read_state) {
    is(ReadState.idle) {
      when(io.axi.ar.fire) {
        read_state := ReadState.done
      }
    }
    is(ReadState.done) {
      when(io.axi.r.fire) {
        read_state := ReadState.idle
      }
    }
  }

  // ========== 写操作状态机 ==========
  object WriteState extends ChiselEnum {
    val idle, done = Value
  }

  private val write_state = RegInit(WriteState.idle)
  private val aw_received = RegInit(false.B)
  private val w_received = RegInit(false.B)

  io.axi.aw.ready := (write_state === WriteState.idle) && !aw_received
  io.axi.w.ready := (write_state === WriteState.idle) && !w_received
  io.axi.b.valid := (write_state === WriteState.done)
  io.axi.b.bits.resp := AXI4LiteResp.DECERR

  switch(write_state) {
    is(WriteState.idle) {
      when(io.axi.aw.fire) {
        aw_received := true.B
      }
      when(io.axi.w.fire) {
        w_received := true.B
      }

      val aw_done = aw_received || io.axi.aw.fire
      val w_done = w_received || io.axi.w.fire

      when(aw_done && w_done) {
        write_state := WriteState.done
        aw_received := false.B
        w_received := false.B
      }
    }
    is(WriteState.done) {
      when(io.axi.b.fire) {
        write_state := WriteState.idle
      }
    }
  }
}
