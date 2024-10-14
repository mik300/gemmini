// See README.md for license details.
package gemmini

import chisel3._
import chisel3.util._
import chisel3.util.HasBlackBoxResource


class PEControl[T <: Data : Arithmetic](accType: T) extends Bundle {
  val dataflow = UInt(1.W) // TODO make this an Enum
  val propagate = UInt(1.W) // Which register should be propagated (and which should be accumulated)?
  val shift = UInt(log2Up(accType.getWidth).W) // TODO this isn't correct for Floats

}

/*
class mul_9x9_signed_bw[T <: Data](inputType: T, outputType: T) (implicit ev: Arithmetic[T]) extends RawModule {
    import ev._
    val io = IO(new Bundle {
      val a = Input(inputType)
      val b = Input(inputType)
      val res_mask = Input(UInt(14.W))
      val appr_mask = Input(UInt(8.W))
      val res = Output(outputType)
    })

    io.res := DontCare
    when(io.appr_mask <= 64.U && io.res_mask <= 4096.U) {
      io.res := io.a*io.b
    }.elsewhen(io.appr_mask <= 64.U && io.res_mask > 4096.U) { 
      io.res := io.a+io.b
    }
  }
*/

class mul_signed_bw extends BlackBox with HasBlackBoxResource {
    val io = IO(new Bundle {
      val a = Input(SInt(9.W))
      val b = Input(SInt(9.W))
      val res_mask = Input(UInt(14.W)) // mask to select result precision
      val appr_mask = Input(UInt(8.W)) // mask to select result approximation
      val res = Output(SInt(18.W))
    })
      addResource("/mul_signed_bw.sv")
}

class mul_9x9_signed_bw[T <: Data](inputType: T, dType: T) extends RawModule {

    val io = IO(new Bundle {
      val a = Input(SInt(8.W))
      val b = Input(SInt(8.W))
      val res_mask = Input(UInt(14.W))
      val appr_mask = Input(UInt(8.W))
      val res = Output(dType)
    })
    val a_inter = Cat(Fill(1, io.a(7)), io.a).asSInt // a_inter is a sign extended a (9 bits)
    val b_inter = Cat(Fill(1, io.b(7)), io.b).asSInt

    val mul_signed_bw_nodule = Module(new mul_signed_bw) 
    mul_signed_bw_nodule.io.a := a_inter
    mul_signed_bw_nodule.io.b := b_inter
    mul_signed_bw_nodule.io.res_mask := io.res_mask
    mul_signed_bw_nodule.io.appr_mask := io.appr_mask

    val res_inter = Cat(Fill(2, mul_signed_bw_nodule.io.res(17)), mul_signed_bw_nodule.io.res).asSInt
    io.res := res_inter
}

class MacUnit[T <: Data](inputType: T, cType: T, dType: T) (implicit ev: Arithmetic[T]) extends Module {
  import ev._
  val io = IO(new Bundle {
    val in_a  = Input(inputType)
    val in_b  = Input(inputType)
    val approximate = Input(UInt(8.W))
    val precision = Input(UInt(14.W))
    val in_c  = Input(cType)
    val out_d = Output(dType)
  })

  //io.out_d := io.in_a*io.in_b
  /*
  io.out_d := DontCare
  when(io.approximate <= 128.U && io.precision <= 8192.U) { 
    io.out_d := io.in_c.mac(io.in_a, io.in_b)
  }.elsewhen(io.approximate <= 128.U && io.precision > 8192.U) {
    io.out_d := io.in_c + io.in_a + io.in_b
  }.elsewhen(io.approximate <= 256.U && io.precision <= 8192.U) {
    io.out_d := io.in_c + io.in_a - io.in_b
  }.elsewhen(io.approximate < 256.U && io.precision > 8192.U) {
    io.out_d := io.in_a + io.in_b
  }
  */

  //io.out_d := io.in_c.mac(io.in_a, io.in_b)
  //io.out_d := io.in_c + io.in_a + io.in_b
  
  val approx_mul_output = Wire(dType)
  val approx_mul = Module(new mul_9x9_signed_bw(inputType, dType)) 
  approx_mul.io.a := io.in_a
  approx_mul.io.b := io.in_b
  approx_mul.io.res_mask := io.precision
  approx_mul.io.appr_mask := io.approximate
  approx_mul_output := approx_mul.io.res
  io.out_d := approx_mul_output + io.in_c
  
}

// TODO update documentation
/**
  * A PE implementing a MAC operation. Configured as fully combinational when integrated into a Mesh.
  * @param width Data width of operands
  */
class PE[T <: Data](inputType: T, outputType: T, accType: T, df: Dataflow.Value, max_simultaneous_matmuls: Int)
                   (implicit ev: Arithmetic[T]) extends Module { // Debugging variables
  import ev._

  val io = IO(new Bundle {
    val in_a = Input(inputType)
    val in_b = Input(outputType)
    val in_d = Input(outputType)
    val approximate_in = Input(UInt (8.W))
    val precision_in = Input(UInt (14.W))
    
    val out_a = Output(inputType)
    val out_b = Output(outputType)
    val out_c = Output(outputType)
    val approximate_out = Output(UInt (8.W))
    val precision_out = Output(UInt (14.W))

    val in_control = Input(new PEControl(accType))
    val out_control = Output(new PEControl(accType))

    val in_id = Input(UInt(log2Up(max_simultaneous_matmuls).W))
    val out_id = Output(UInt(log2Up(max_simultaneous_matmuls).W))

    val in_last = Input(Bool())
    val out_last = Output(Bool())

    val in_valid = Input(Bool())
    val out_valid = Output(Bool())

    val bad_dataflow = Output(Bool())
  })

  val cType = if (df == Dataflow.WS) inputType else accType

  // When creating PEs that support multiple dataflows, the
  // elaboration/synthesis tools often fail to consolidate and de-duplicate
  // MAC units. To force mac circuitry to be re-used, we create a "mac_unit"
  // module here which just performs a single MAC operation
  val mac_unit = Module(new MacUnit(inputType, if (df == Dataflow.WS) outputType else accType, outputType))

  val a  = io.in_a
  val b  = io.in_b
  val d  = io.in_d
  val c1 = Reg(cType)
  val c2 = Reg(cType)
  val dataflow = io.in_control.dataflow
  val prop  = io.in_control.propagate
  val shift = io.in_control.shift
  val id = io.in_id
  val last = io.in_last
  val valid = io.in_valid

  mac_unit.io.approximate := io.approximate_in
  io.approximate_out := io.approximate_in
  mac_unit.io.precision := io.precision_in
  io.precision_out := io.precision_in
  io.out_a := a
  io.out_control.dataflow := dataflow
  io.out_control.propagate := prop
  io.out_control.shift := shift
  io.out_id := id
  io.out_last := last
  io.out_valid := valid

  mac_unit.io.in_a := a

  val last_s = RegEnable(prop, valid)
  val flip = last_s =/= prop
  val shift_offset = Mux(flip, shift, 0.U)

  // Which dataflow are we using?
  val OUTPUT_STATIONARY = Dataflow.OS.id.U(1.W)
  val WEIGHT_STATIONARY = Dataflow.WS.id.U(1.W)

  // Is c1 being computed on, or propagated forward (in the output-stationary dataflow)?
  val COMPUTE = 0.U(1.W)
  val PROPAGATE = 1.U(1.W)

  io.bad_dataflow := false.B
  when ((df == Dataflow.OS).B || ((df == Dataflow.BOTH).B && dataflow === OUTPUT_STATIONARY)) {
    when(prop === PROPAGATE) {
      io.out_c := (c1 >> shift_offset).clippedToWidthOf(outputType)
      io.out_b := b
      mac_unit.io.in_b := b.asTypeOf(inputType)
      mac_unit.io.in_c := c2
      c2 := mac_unit.io.out_d
      c1 := d.withWidthOf(cType)
    }.otherwise {
      io.out_c := (c2 >> shift_offset).clippedToWidthOf(outputType)
      io.out_b := b
      mac_unit.io.in_b := b.asTypeOf(inputType)
      mac_unit.io.in_c := c1
      c1 := mac_unit.io.out_d
      c2 := d.withWidthOf(cType)
    }
  }.elsewhen ((df == Dataflow.WS).B || ((df == Dataflow.BOTH).B && dataflow === WEIGHT_STATIONARY)) {
    when(prop === PROPAGATE) {
      io.out_c := c1
      mac_unit.io.in_b := c2.asTypeOf(inputType)
      mac_unit.io.in_c := b
      io.out_b := mac_unit.io.out_d
      c1 := d
    }.otherwise {
      io.out_c := c2
      mac_unit.io.in_b := c1.asTypeOf(inputType)
      mac_unit.io.in_c := b
      io.out_b := mac_unit.io.out_d
      c2 := d
    }
  }.otherwise {
    io.bad_dataflow := true.B
    //assert(false.B, "unknown dataflow")
    io.out_c := DontCare
    io.out_b := DontCare
    mac_unit.io.in_b := b.asTypeOf(inputType)
    mac_unit.io.in_c := c2
  }

  when (!valid) {
    c1 := c1
    c2 := c2
    mac_unit.io.in_b := DontCare
    mac_unit.io.in_c := DontCare
  }
}
