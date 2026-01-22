package core.mem

import chisel3._
import chisel3.util._
import chisel3.util.random.LFSR
import core.common.HasCoreParameter
import core.general.{AXI4LiteSlaveIO, AXI4LiteParams, AXI4LiteResp}
import core.dpi.{PmemRead, PmemWrite}

class AXI4LitePmemSlave(params: AXI4LiteParams) extends Module with HasCoreParameter {
  val io = IO(new Bundle {
    val axi = new AXI4LiteSlaveIO(params)
  })

  private val counter = RegInit(0.U(8.W))

  private def delay(n: Int) : UInt = {
    // LFSR(n)
    1.U
  }

  // ========== 读操作状态机 ==========
  object ReadState extends ChiselEnum {
    val idle, reading, latch, done = Value
  }

  // 锁存
  private val read_state = RegInit(ReadState.idle)
  private val read_addr_reg = RegInit(0.U(params.addrWidth.W))
  private val read_data_reg = RegInit(0.U(params.dataWidth.W))

  // AR
  io.axi.ar.ready := (read_state === ReadState.idle)

  // R
  io.axi.r.valid := (read_state === ReadState.done)
  io.axi.r.bits.data := read_data_reg
  io.axi.r.bits.resp := AXI4LiteResp.OKAY

  // DPI - 使用新的 Chisel DPI API
  private val readDpiEnable = WireDefault(false.B)
  private val readDpiData = PmemRead(readDpiEnable, read_addr_reg, 4.U(32.W))

  switch(read_state) {
    is(ReadState.idle) {
      when(io.axi.ar.fire) {
        read_state := ReadState.reading
        read_addr_reg := io.axi.ar.bits.addr
        counter := delay(4)
      }
    }
    is(ReadState.reading) {
      when(counter === 0.U) {
        read_state := ReadState.latch
        readDpiEnable := true.B
      }.otherwise {
        counter := counter - 1.U
      }
    }
    is(ReadState.latch) {
      read_state := ReadState.done
      read_data_reg := readDpiData
    }
    is(ReadState.done) {
      when(io.axi.r.fire) {
        read_state := ReadState.idle
      }
    }
  }

  // ========== 写操作状态机 ==========
  object WriteState extends ChiselEnum {
    val idle, writing, done = Value
  }

  private val write_state = RegInit(WriteState.idle)

  // AW 和 W 通道可能不同顺序到达，需要分别记录
  private val aw_received = RegInit(false.B)
  private val w_received  = RegInit(false.B)

  // 锁存
  private val write_addr_reg = RegInit(0.U(params.addrWidth.W))
  private val write_data_reg = RegInit(0.U(params.dataWidth.W))
  private val write_strb_reg = RegInit(0.U(params.strbWidth.W))

  // DPI - 使用新的 Chisel DPI API
  private val writeDpiEnable = WireDefault(false.B)
  PmemWrite(writeDpiEnable, write_addr_reg, write_strb_reg, write_data_reg)

  // AW
  io.axi.aw.ready := (write_state === WriteState.idle) && !aw_received

  // W
  io.axi.w.ready := (write_state === WriteState.idle) && !w_received

  // B
  io.axi.b.valid     := (write_state === WriteState.done)
  io.axi.b.bits.resp := AXI4LiteResp.OKAY

  switch(write_state) {
    is(WriteState.idle) {
      when(io.axi.aw.fire) {
        write_addr_reg := io.axi.aw.bits.addr
        aw_received := true.B
      }

      when(io.axi.w.fire) {
        write_data_reg := io.axi.w.bits.data
        write_strb_reg := io.axi.w.bits.strb
        w_received := true.B
      }

      val aw_done = aw_received || io.axi.aw.fire
      val w_done  = w_received || io.axi.w.fire

      when(aw_done && w_done) {
        when(io.axi.aw.fire) {
          write_addr_reg := io.axi.aw.bits.addr
        }
        when(io.axi.w.fire) {
          write_data_reg := io.axi.w.bits.data
          write_strb_reg := io.axi.w.bits.strb
        }
        counter := delay(4)
        write_state := WriteState.writing
        aw_received := false.B
        w_received  := false.B
      }
    }
    is(WriteState.writing) {
      when(counter === 0.U) {
        writeDpiEnable := true.B
        write_state := WriteState.done
      }.otherwise {
        counter := counter - 1.U
      }
    }
    is(WriteState.done) {
      when(io.axi.b.fire) {
        write_state := WriteState.idle
      }
    }
  }
}
