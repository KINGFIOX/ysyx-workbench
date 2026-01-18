package mem

import chisel3._
import chisel3.util._
import general.{AXI4LiteSlaveIO, AXI4LiteParams, AXI4LiteResp}
import dpi.DifftestSkipRef


class AXI4LiteCLINTSlave(params: AXI4LiteParams) extends Module {
  val io = IO(new Bundle {
    val axi = new AXI4LiteSlaveIO(params)
  })

  // ========== MMIO 寄存器 ==========
  private val mtime = RegInit(0.U(64.W))
  mtime := mtime + 1.U

  private val lookupTable = Seq(
    "ha000_0048".U -> mtime(31, 0),
    "ha000_004c".U -> mtime(63, 32),
  )

  // ========== 读操作状态机 ==========
  object ReadState extends ChiselEnum {
    val idle, done = Value
  }

  // 锁存
  private val read_state = RegInit(ReadState.idle)
  private val read_data_reg = RegInit(0.U(params.dataWidth.W))
  private val read_found_reg = RegInit(false.B)

  // AR
  io.axi.ar.ready := (read_state === ReadState.idle)

  // R
  io.axi.r.valid := (read_state === ReadState.done)
  io.axi.r.bits.data := read_data_reg
  io.axi.r.bits.resp := Mux( read_found_reg, AXI4LiteResp.OKAY, AXI4LiteResp.DECERR )

  DifftestSkipRef( io.axi.ar.fire )

  switch(read_state) {
    is(ReadState.idle) {
      when(io.axi.ar.fire) {
        read_state := ReadState.done
        val found = WireDefault(false.B)
        for ( (addr, data) <- lookupTable ) {
          when ( io.axi.ar.bits.addr === addr ) {
            found := true.B
            read_data_reg := data
          }
        }
        read_found_reg := found
      }
    }
    is(ReadState.done) {
      when(io.axi.r.fire) {
        read_state := ReadState.idle
      }
    }
  }

  // ========== 写操作状态机 (dummy) ==========
  object WriteState extends ChiselEnum {
    val idle, done = Value
  }

  private val write_state = RegInit(WriteState.idle)
  private val aw_received = RegInit(false.B)
  private val w_received = RegInit(false.B)

  io.axi.aw.ready := (write_state === WriteState.idle) && !aw_received
  io.axi.w.ready := (write_state === WriteState.idle) && !w_received
  io.axi.b.valid := (write_state === WriteState.done)
  io.axi.b.bits.resp := AXI4LiteResp.OKAY

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
