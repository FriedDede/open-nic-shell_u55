// typedef struct packed {
//   logic          [31:0] ip;      // IPv4 address of the sender
//   logic          [47:0] mac;     // Mac address of the sender
//   logic           [7:0] id;      // Operation identifier used to distinguish consecutive writes
//   logic           [7:0] opcode;  // Operation code
//   logic          [63:0] key;
// } st_metadata;

module metadata_buffer #(
  parameter DEPTH      = 64,
  parameter PTR_WIDTH  = $clog2(DEPTH)
)(
  input  logic         aclk,
  input  logic         aresetn,

  // Slave side (no ready)
  input  logic         s_valid,
  input  st_metadata   s_data,

  // Master side (with ready)
  output logic         m_valid,
  output st_metadata   m_data,
  input  logic         m_ready
);

  // Memory Buffers
  st_metadata mem [DEPTH-1:0];

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
    if (s_valid) begin
      mem[write_ptr] <= s_data;
      write_ptr      <= write_ptr + 1;
      if (count < (DEPTH-1))
        count <= count + 1;
    end

    // Read
    if (m_valid && m_ready) begin
      read_ptr <= read_ptr + 1;
      count    <= count - 1;
    end
  end
end

  st_metadata m_rand;
  always_comb begin
  m_rand.ip = '0;
  m_rand.id ='0;
  m_rand.opcode ='0;
  m_rand.key  = '0;
  m_rand.mac = '0;
  end

  assign m_valid = (count != 0);
  assign m_data  = m_ready? mem[read_ptr] :m_rand;
  

endmodule