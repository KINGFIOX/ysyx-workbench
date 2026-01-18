package dpi

import chisel3._
import chisel3.util.Cat
import chisel3.util.circt.dpi._

/** 内存读取 DPI 函数
  *
  * 对应 C 函数签名需要改为:
  * ```c
  * extern "C" void pmem_read_dpi(int en, int addr, int len, int* data);
  * ```
  *
  * 注意: CIRCT DPI ABI 要求返回值通过 output pointer 参数传递
  */
object PmemRead extends DPINonVoidFunctionImport[UInt] {
  override val functionName = "pmem_read_dpi"
  override val ret = UInt(32.W)
  override val clocked = true
  override val inputNames = Some(Seq("en", "addr", "len"))
  override val outputName = Some("data")

  /** 调用内存读取 DPI
    * @param en 使能信号
    * @param addr 地址
    * @param len 长度(字节数)
    * @return 读取的数据
    */
  def apply(en: Bool, addr: UInt, len: UInt): UInt =
    super.call(Cat(0.U(31.W), en.asUInt), addr, len)
}

/** 内存写入 DPI 函数
  *
  * 对应 C 函数签名:
  * ```c
  * extern "C" void pmem_write_dpi(int en, int addr, int strb, int data);
  * ```
  */
object PmemWrite extends DPIClockedVoidFunctionImport {
  override val functionName = "pmem_write_dpi"
  override val inputNames = Some(Seq("en", "addr", "strb", "data"))

  /** 调用内存写入 DPI
    * @param en 使能信号
    * @param addr 地址
    * @param strb 写掩码
    * @param data 写入数据
    */
  def apply(en: Bool, addr: UInt, strb: UInt, data: UInt): Unit =
    super.call(Cat(0.U(31.W), en.asUInt), addr, Cat(0.U(28.W), strb), data)
}
