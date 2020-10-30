radix -hexadecimal
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /top/clk
add wave -noupdate /top/reset_n
add wave -noupdate /top/in_valid
add wave -noupdate /top/in_startofpacket
add wave -noupdate /top/in_endofpacket
add wave -noupdate /top/in_empty
add wave -noupdate /top/in_error
add wave -noupdate /top/in_data
add wave -noupdate /top/in_data_next
add wave -noupdate /top/in_ready
add wave -noupdate /top/out_valid
add wave -noupdate /top/out_data
add wave -noupdate /top/out_bytemask
add wave -noupdate /top/seq_started
add wave -noupdate /top/seq_ended
add wave -noupdate /top/in_ready_d1
add wave -noupdate /top/inject
add wave -noupdate /top/in_startofpacket_seen
add wave -noupdate /top/pkt_cyc_cnt
add wave -noupdate /top/pkt_cnt
add wave -noupdate /top/RUN_BRINGUP_PKT
add wave -noupdate /top/NUM_PKT
add wave -noupdate /top/NUM_MSG_PER_PKT
add wave -noupdate /top/IN_VALID_PROB
add wave -noupdate /top/rand_in_stim_fn
add wave -noupdate /top/rand_in_stim_fd
add wave -noupdate -expand -group DUT /top/dut/clk
add wave -noupdate -expand -group DUT /top/dut/reset_n
add wave -noupdate -expand -group DUT /top/dut/in_valid
add wave -noupdate -expand -group DUT /top/dut/in_startofpacket
add wave -noupdate -expand -group DUT /top/dut/in_endofpacket
add wave -noupdate -expand -group DUT /top/dut/in_empty
add wave -noupdate -expand -group DUT /top/dut/in_error
add wave -noupdate -expand -group DUT /top/dut/in_data
add wave -noupdate -expand -group DUT /top/dut/in_ready
add wave -noupdate -expand -group DUT /top/dut/out_valid
add wave -noupdate -expand -group DUT /top/dut/out_data
add wave -noupdate -expand -group DUT /top/dut/out_bytemask
add wave -noupdate -expand -group DUT /top/dut/get_new_msg_len_from_sop
add wave -noupdate -expand -group DUT /top/dut/get_new_msg_len_from_straddle_next
add wave -noupdate -expand -group DUT /top/dut/get_new_msg_len_from_straddle
add wave -noupdate -expand -group DUT /top/dut/get_new_msg_len_from_shift
add wave -noupdate -expand -group DUT /top/dut/msg_len_from_sop
add wave -noupdate -expand -group DUT /top/dut/msg_len_from_straddle
add wave -noupdate -expand -group DUT /top/dut/msg_len_from_shift
add wave -noupdate -expand -group DUT /top/dut/msg_len_rem_bytes
add wave -noupdate -expand -group DUT /top/dut/msg_len_rem_bytes_next
add wave -noupdate -expand -group DUT /top/dut/data_buffer
add wave -noupdate -expand -group DUT /top/dut/mask_buffer
add wave -noupdate -expand -group DUT /top/dut/straddle_hi
add wave -noupdate -expand -group DUT /top/dut/straddle_lo
add wave -noupdate -expand -group DUT /top/dut/head_ptr
add wave -noupdate -expand -group DUT /top/dut/tail_ptr
add wave -noupdate -expand -group DUT /top/dut/nothing_to_store
add wave -noupdate -expand -group DUT /top/dut/nothing_to_store_next
add wave -noupdate -expand -group DUT /top/dut/head_in_downshift_bytes_next
add wave -noupdate -expand -group DUT /top/dut/head_in_downshift_bytes
add wave -noupdate -expand -group DUT /top/dut/head_in_downshift_bytes_prev
add wave -noupdate -expand -group DUT /top/dut/head_out_upshift_bytes
add wave -noupdate -expand -group DUT /top/dut/tail_in_upshift_bytes
add wave -noupdate -expand -group DUT /top/dut/tail_in_upshift_bytes_next
add wave -noupdate -expand -group DUT /top/dut/tail_out_upshift_bytes
add wave -noupdate -expand -group DUT /top/dut/head_out_bitmask
add wave -noupdate -expand -group DUT /top/dut/tail_out_bitmask
add wave -noupdate -expand -group DUT /top/dut/is_head
add wave -noupdate -expand -group DUT /top/dut/is_head_nowrap
add wave -noupdate -expand -group DUT /top/dut/is_tail
add wave -noupdate -expand -group DUT /top/dut/head_out_bytemask
add wave -noupdate -expand -group DUT /top/dut/tail_out_bytemask
add wave -noupdate -expand -group DUT /top/dut/msg_len_from_shift_wide
add wave -noupdate -expand -group DUT /top/dut/head_in_data
add wave -noupdate -expand -group DUT /top/dut/head_in_data_out
add wave -noupdate -expand -group DUT /top/dut/tail_in_data
add wave -noupdate -expand -group DUT /top/dut/head_out_data
add wave -noupdate -expand -group DUT /top/dut/tail_out_data
add wave -noupdate -expand -group DUT /top/dut/last_cyc_in_msg
add wave -noupdate -expand -group DUT /top/dut/last_cyc_in_msg_next
add wave -noupdate -expand -group DUT /top/dut/last_cyc_in_msg_vld
add wave -noupdate -expand -group DUT /top/dut/use_head
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 335
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {24 ns}
