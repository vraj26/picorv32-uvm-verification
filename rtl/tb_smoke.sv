`timescale 1ns/1ps
module tb;
  logic clk = 0, resetn = 0;
  always #5 clk = ~clk;

  // PicoRV32 native memory interface
  logic        mem_valid, mem_instr, trap;
  logic        mem_ready = 0;
  logic [31:0] mem_addr, mem_wdata, mem_rdata;
  logic [3:0]  mem_wstrb;

  // RVFI: one pulse per retired instruction
  logic        rvfi_valid;
  logic [31:0] rvfi_insn, rvfi_pc_rdata, rvfi_rd_wdata;
  logic [4:0]  rvfi_rd_addr;

  picorv32 dut (
    .clk(clk), .resetn(resetn), .trap(trap),
    .mem_valid(mem_valid), .mem_instr(mem_instr), .mem_ready(mem_ready),
    .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
    .mem_rdata(mem_rdata),
    .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
    .irq(32'b0),
    .rvfi_valid(rvfi_valid), .rvfi_insn(rvfi_insn),
    .rvfi_pc_rdata(rvfi_pc_rdata),
    .rvfi_rd_addr(rvfi_rd_addr), .rvfi_rd_wdata(rvfi_rd_wdata)
  );

  // 4 KB memory, word-addressed
  logic [31:0] mem [0:1023];
  initial begin
    foreach (mem[i]) mem[i] = 32'h00000013; // NOP
    mem[0] = 32'h00500093; // addi x1, x0, 5
    mem[1] = 32'h00308113; // addi x2, x1, 3
    mem[2] = 32'h002081B3; // add  x3, x1, x2
    mem[3] = 32'h10302023; // sw   x3, 0x100(x0)
    mem[4] = 32'h10002203; // lw   x4, 0x100(x0)
    mem[5] = 32'h0000006F; // jal  x0, 0   (end loop)
  end

  // Memory responder: 1-cycle latency, byte-lane writes
  always @(posedge clk) begin
    mem_ready <= 1'b0;
    if (resetn && mem_valid && !mem_ready) begin
      mem_ready <= 1'b1;
      mem_rdata <= mem[mem_addr[11:2]];
      if (mem_wstrb[0]) mem[mem_addr[11:2]][ 7: 0] <= mem_wdata[ 7: 0];
      if (mem_wstrb[1]) mem[mem_addr[11:2]][15: 8] <= mem_wdata[15: 8];
      if (mem_wstrb[2]) mem[mem_addr[11:2]][23:16] <= mem_wdata[23:16];
      if (mem_wstrb[3]) mem[mem_addr[11:2]][31:24] <= mem_wdata[31:24];
    end
  end

  // Print every retired instruction
  always @(posedge clk) begin
    if (rvfi_valid)
      $display("[%0t] PC=%08h INSN=%08h  x%0d <= %08h",
               $time, rvfi_pc_rdata, rvfi_insn, rvfi_rd_addr, rvfi_rd_wdata);
    if (rvfi_valid && rvfi_insn == 32'h0000006F) begin
      $display("Reached end loop."); $finish;
    end
    if (trap) begin $display("TRAP!"); $finish; end
  end

  initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb);
    repeat (5) @(posedge clk);
    resetn <= 1'b1;
    repeat (500) @(posedge clk);
    $display("TIMEOUT"); $finish;
  end
endmodule
