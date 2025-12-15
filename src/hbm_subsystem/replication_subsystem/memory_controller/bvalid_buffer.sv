// typedef struct packed {
//   logic          [31:0] ip;      // IPv4 address of the sender
//   logic          [47:0] mac;     // Mac address of the sender
//   logic           [7:0] id;      // Operation identifier used to distinguish consecutive writes
//   logic           [7:0] opcode;  // Operation code
//   logic          [63:0] key;
// } st_metadata;

module bvalid_buffer #(
  parameter DEPTH      = 64,
  parameter PTR_WIDTH  = $clog2(DEPTH)
)(
  input  logic         aclk,
  input  logic         aresetn,

  // Slave side (no ready)
  input  logic         s_bresp,
  input  logic         s_bvalid,

  // Master side (with ready)
  output logic         m_bvalid,
  output logic         m_bresp,
  input  logic         m_bready

);

  // Memory Buffers
  logic mem [DEPTH-1:0];

  // Write & Read pointers
  logic [PTR_WIDTH-1:0] write_ptr;
  logic [PTR_WIDTH-1:0] read_ptr;

  // Counter
  logic [PTR_WIDTH-1:0] count;

always_ff @(posedge aclk or negedge aresetn) begin
  if (!aresetn) begin
    write_ptr <= '0;
    read_ptr  <= '0;
    count     <= '0;
  end 
  else begin
    // Write
    if (s_bvalid) begin
      mem[write_ptr] <= s_bresp;
      write_ptr      <= write_ptr + 1;
      if (count < (DEPTH-1))
        count <= count + 1;
    end

    // Read
    if (m_bvalid && m_bready) begin
      read_ptr <= read_ptr + 1;
      count    <= count - 1;
    end
  end
end

  logic m_resp;
  always_comb begin
  m_resp = 1'b0;
  end

  assign m_bvalid = (count != 0);
  assign m_bresp  = m_bready? mem[read_ptr] :m_resp;
  

endmodule