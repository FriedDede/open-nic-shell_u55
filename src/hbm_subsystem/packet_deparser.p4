#include <core.p4>
#include <xsa.p4>

typedef bit<48>  MacAddr;
typedef bit<32>  IPv4Addr;

const bit<16> QINQ_TYPE = 0x88A8;
const bit<16> VLAN_TYPE = 0x8100;
const bit<16> IPV4_TYPE = 0x0800;

const bit<8>  TCP_PROT  = 0x06;
const bit<8>  UDP_PROT  = 0x11;

const bit<16> REPLICATION_PORT = 0x7777;

const bit<16> IP_HEADER_SIZE   = 20;
const bit<16> UDP_HEADER_SIZE  = 8; 
const bit<16> REP_HEADER_SIZE  = 2;
const bit<16> KEY_SIZE         = 8;
const bit<16> PAYLOAD_SIZE     = 1024 - 4 - 8;
const bit<16> MINIMUM_SIZE     = 60 - IP_HEADER_SIZE - UDP_HEADER_SIZE - REP_HEADER_SIZE;

// Replication opcodes
const bit<8> READ              = 0x00;
const bit<8> WRITE             = 0x01;
const bit<8> READ_RESULT       = 0x02;
const bit<8> READ_NOT_FOUND    = 0x03;
const bit<8> WRITE_ACK         = 0x04;
const bit<8> WRITE_ACK_LEADER  = 0x05;

const bit<8> HEARTBEAT         = 0x06;
const bit<8> HEARTBEAT_ACK     = 0x07;
const bit<8> VOTE_REQUEST      = 0x08;
const bit<8> VOTE              = 0x09;

const bit<32> DIRTY_TAG        = 0xF0CACC1A;

// ********************************************************************** //
// *************************** H E A D E R S  *************************** //
// ********************************************************************** //

header eth_mac_t {
  MacAddr dmac; // Destination MAC address
  MacAddr smac; // Source MAC address
  bit<16> type; // Tag Protocol Identifier
}

header vlan_t {
  bit<3>  pcp;  // Priority code point
  bit<1>  cfi;  // Drop eligible indicator
  bit<12> vid;  // VLAN identifier
  bit<16> tpid; // Tag protocol identifier
}

header ipv4_t {
  bit<4>   version;  // Version (4 for IPv4)
  bit<4>   hdr_len;  // Header length in 32b words
  bit<8>   tos;      // Type of Service
  bit<16>  length;   // Packet length in 32b words
  bit<16>  id;       // Identification
  bit<3>   flags;    // Flags
  bit<13>  offset;   // Fragment offset
  bit<8>   ttl;      // Time to live
  bit<8>   protocol; // Next protocol
  bit<16>  hdr_chk;  // Header checksum
  IPv4Addr src;      // Source address
  IPv4Addr dst;      // Destination address
}

header ipv4_opt_t {
  varbit<320> options; // IPv4 options - length = (ipv4.hdr_len - 5) * 32
}

header tcp_t {
  bit<16> src_port;   // Source port
  bit<16> dst_port;   // Destination port
  bit<32> seqNum;     // Sequence number
  bit<32> ackNum;     // Acknowledgment number
  bit<4>  dataOffset; // Data offset
  bit<6>  resv;       // Offset
  bit<6>  flags;      // Flags
  bit<16> window;     // Window
  bit<16> checksum;   // TCP checksum
  bit<16> urgPtr;     // Urgent pointer
}

header tcp_opt_t {
  varbit<320> options; // TCP options - length = (tcp.dataOffset - 5) * 32
}

header udp_t {
  bit<16> src_port;  // Source port
  bit<16> dst_port;  // Destination port
  bit<16> length;    // UDP length
  bit<16> checksum;  // UDP checksum
}

// Replication header
header rep_h {
  bit<8>  opcode;
  bit<8>  id;
}

header tag_h {
  bit<32> tag;
}

header key_h {
  bit<64> key;
}

// ********************************************************************** //
// ************************* S T R U C T U R E S  *********************** //
// ********************************************************************** //

// Header structure
struct headers {
  eth_mac_t  eth;
  vlan_t     new_vlan;
  vlan_t     vlan;
  ipv4_t     ipv4;
  ipv4_opt_t ipv4opt;
  tcp_t      tcp;
  tcp_opt_t  tcpopt;
  udp_t      udp;
  rep_h      rep;
  tag_h      tag;
  key_h      key;
}

struct metadata_t {
  bit<32> ip_src;
  bit<48> mac_src;
  bit<8>  opcode;
  bit<8>  index;
  bit<64> key;

  // Fixed values
  bit<32> ip_own;
  bit<48> mac_own;
}

// User-defined errors
error {
  InvalidIPpacket,
  InvalidTCPpacket
}

// ********************************************************************** //
// *************************** P A R S E R  ***************************** //
// ********************************************************************** //

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata_t meta,
                inout standard_metadata_t smeta) {

  state start {
    transition parse_tag;
  }

  state parse_tag {
    packet.extract(hdr.tag);
    transition select(hdr.tag.tag) {
      DIRTY_TAG : parse_key;
      default   : accept;
    }
  }

  state parse_key {
    packet.extract(hdr.key);
    transition accept;
  }
}

// ********************************************************************** //
// **************************  P R O C E S S I N G   ******************** //
// ********************************************************************** //

control MyProcessing(inout headers hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t smeta) {
  // InternetChecksum() ck;
  // bit<16> csum;

  bit<16> payload_length;

  apply {
    hdr.eth.setValid();
    hdr.ipv4.setValid();
    hdr.udp.setValid();
    hdr.rep.setValid();
    hdr.key.setValid();

    payload_length = MINIMUM_SIZE;
    if (meta.opcode == WRITE || meta.opcode == READ_RESULT) {
      payload_length = PAYLOAD_SIZE;
    }

    hdr.eth.dmac     = meta.mac_src;
    hdr.eth.smac     = meta.mac_own;
    hdr.eth.type     = IPV4_TYPE;

    hdr.ipv4.version = 4;
    hdr.ipv4.hdr_len = 5;
    hdr.ipv4.tos     = 0;
    hdr.ipv4.length  = IP_HEADER_SIZE + UDP_HEADER_SIZE + REP_HEADER_SIZE + payload_length;
    hdr.ipv4.id      = 0;
    hdr.ipv4.flags   = 0;
    hdr.ipv4.offset  = 0;
    hdr.ipv4.ttl     = 64;
    hdr.ipv4.protocol= UDP_PROT;
    hdr.ipv4.hdr_chk = 0;
    hdr.ipv4.src     = meta.ip_own;
    hdr.ipv4.dst     = meta.ip_src;

    hdr.udp.src_port = REPLICATION_PORT;
    hdr.udp.dst_port = REPLICATION_PORT;
    hdr.udp.length   = UDP_HEADER_SIZE + REP_HEADER_SIZE + payload_length;
    hdr.udp.checksum = 0;

    hdr.rep.opcode   = meta.opcode;
    hdr.rep.id       = meta.index;
    hdr.key.key      = meta.key;

    // ck.clear();
    // ck.add({hdr.ipv4.version, hdr.ipv4.hdr_len, hdr.ipv4.tos, hdr.ipv4.length, hdr.ipv4.id, hdr.ipv4.flags, hdr.ipv4.offset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.src, hdr.ipv4.dst});
    // ck.get(csum);
    // hdr.ipv4.hdr_chk = csum;
  }
}


// ********************************************************************** //
// ***************************  D E P A R S E R  ************************ //
// ********************************************************************** //

control MyDeparser(packet_out packet,
                   in headers hdr,
                   inout metadata_t meta,
                   inout standard_metadata_t smeta) {
  apply {
    packet.emit(hdr.eth);
    packet.emit(hdr.ipv4);
    packet.emit(hdr.udp);
    packet.emit(hdr.rep);
    packet.emit(hdr.key);
  }
}

// ********************************************************************** //
// *******************************  M A I N  **************************** //
// ********************************************************************** //

XilinxPipeline(
  MyParser(),
  MyProcessing(),
  MyDeparser()
) main;
