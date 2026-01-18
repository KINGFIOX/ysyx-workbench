package mem

import chisel3._
import chisel3.util._
import chisel3.util.random.LFSR
import common.HasCoreParameter
import general.{AXI4LiteSlaveIO, AXI4LiteParams, AXI4LiteResp}
import dpi.DifftestSkipRef

class AXI4LiteUartSlave(params: AXI4LiteParams) extends Module with HasCoreParameter {
  val io = IO(new Bundle {
    val axi = new AXI4LiteSlaveIO(params)
  })

  private val counter = RegInit(0.U(8.W))

  // ========== 读操作状态机(dummy) ==========
  object ReadState extends ChiselEnum {
    val idle, done = Value
  }

  private val read_state = RegInit(ReadState.idle)

  io.axi.ar.ready := (read_state === ReadState.idle)
  io.axi.r.valid := (read_state === ReadState.done)
  io.axi.r.bits.data := 0.U
  io.axi.r.bits.resp := AXI4LiteResp.OKAY

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

  // UART 输出使能信号
  private val uartEnable = WireDefault(false.B)
  
  // DPI: 跳过 difftest 参考模型
  DifftestSkipRef(uartEnable)
  
  // UART 字符输出 (替代原来的 $write)
  when(uartEnable) {
    when(write_strb_reg(0)) { printf("%c", write_data_reg(7, 0)) }
    when(write_strb_reg(1)) { printf("%c", write_data_reg(15, 8)) }
    when(write_strb_reg(2)) { printf("%c", write_data_reg(23, 16)) }
    when(write_strb_reg(3)) { printf("%c", write_data_reg(31, 24)) }
  }

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
        counter := LFSR(4)
        write_state := WriteState.writing
        aw_received := false.B
        w_received  := false.B
      }
    }
    is(WriteState.writing) {
      when(counter === 0.U) {
        uartEnable := true.B
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
