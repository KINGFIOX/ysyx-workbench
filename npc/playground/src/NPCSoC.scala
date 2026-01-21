package npc

import chisel3._
import chisel3.util._

import common.{HasCSRParameter, HasCoreParameter, HasRegFileParameter}
import component.CSRUDebugBundle
import general.{AXI4LiteXBar, AXI4LiteXBarParams, AXI4LiteParams}
import mem.{AXI4LiteUartSlave, AXI4LiteErrorSlave, AXI4LitePmemSlave}
import mem.AXI4LiteCLINTSlave

/** 用来给 Verilator 暴露提交信息, 便于在 C++ 侧采样做差分测试 */
class DebugBundle extends Bundle with HasCoreParameter with HasRegFileParameter with HasCSRParameter {
  val valid = Bool()
  val pc    = UInt(XLEN.W)
  val dnpc  = UInt(XLEN.W)
  val inst  = UInt(InstLen.W)
  val gpr   = Vec(NRReg, UInt(XLEN.W))
  val csr   = new CSRUDebugBundle
}

class NPCSoC(params: AXI4LiteParams) extends Module {
  val io = IO(new Bundle {
    val step = Input(Bool())
    val debug = new DebugBundle
  })

  private val core = Module(new NPCCore(params))
  io.debug := core.io.debug
  core.io.step := io.step

  private val xbarParams = AXI4LiteXBarParams(
    axi = params,
    numMasters = 2, // IFU (icache) 和 LSU (dcache) 作为 master
    // numSlaves = 4, // error slave + pmem slave
    addrMap = Seq(
      (BigInt(0), BigInt(0)),                      // slave 0: error (空范围，永不匹配，作为默认)
      (BigInt(0x8000_0000L), BigInt(0x1000_0000L)), // slave 1: pmem
      (BigInt(0x1000_0000L), BigInt(8)), // slave 2: uart
      (BigInt(0xa000_0048L), BigInt(8)) // slave 3: timer
    )
  )

  private val xbar = Module(new AXI4LiteXBar(xbarParams))

  // 连接 core 的 icache 和 dcache 到 xbar 的 master 端口
  xbar.io.masters(0) <> core.io.icache
  xbar.io.masters(1) <> core.io.dcache

  // 创建 slaves
  private val errorSlave = Module(new AXI4LiteErrorSlave(params))
  private val memSlave = Module(new AXI4LitePmemSlave(params))
  private val uartSlave = Module(new AXI4LiteUartSlave(params))
  private val timerSlave = Module(new AXI4LiteCLINTSlave(params))

  // 连接 xbar 的 slave 端口
  xbar.io.slaves(0) <> errorSlave.io.axi  // error slave (默认)
  xbar.io.slaves(1) <> memSlave.io.axi
  xbar.io.slaves(2) <> uartSlave.io.axi
  xbar.io.slaves(3) <> timerSlave.io.axi
}

object NPCSoC extends App with HasCoreParameter {
  val firtoolOptions = Array(
    "--lowering-options=" + List(
      // make yosys happy
      // see https://github.com/llvm/circt/blob/main/docs/VerilogGeneration.md
      "disallowLocalVariables",
      "disallowPackedArrays",
      "locationInfoStyle=wrapInAtSquareBracket"
    ).reduce(_ + "," + _)
  )
  _root_.circt.stage.ChiselStage.emitSystemVerilogFile(new NPCSoC(AXI4LiteParams(addrWidth = XLEN, dataWidth = XLEN)), args, firtoolOptions)
}
