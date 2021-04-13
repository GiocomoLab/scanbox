#=================================================================
# Configuration Registers/LUTs for DLP LightCommander
#---------------------------------------------------------
#   Created on:  Mon Apr 30 15:32:31 2018 
#   Created by:  Texas Instruments DLP Seq Compiler DLL
#   Version#:    1.5.0
#
#   Output Attributes:
#   Comment                  = ScanboxDLP.lcp ScanboxDLP
#   DMD                      = XGA
#   Mode                     = SL
#   Display Pattern Frm Rate = 60 Hz
#   Exposure Time            = 16660 usec
#   Exposure Time/Frm period = 0.99960
#   Num BPP:                 = 8
#   Num Patterns in Seq      = 1
#   Real-time input source   = false
#   Active LEDs              = RLED  GLED  BLED  
#=================================================================
$L2.5 ExecutePassthroughDLPAPI  _DisablePwmSeq
$L2.5 DLP_RegIO_BeginLUTdata   SEQ_LUT
$L2.5 WriteReg 0x1111 0x000000f8   # data byte 000000
$L2.5 WriteReg 0x1111 0x00000008   # data byte 000004
$L2.5 WriteReg 0x1111 0x00260005   # data byte 000008
$L2.5 WriteReg 0x1111 0x00080004   # data byte 00000c
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000010
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000014
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000018
$L2.5 WriteReg 0x1111 0x00080004   # data byte 00001c
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000020
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000024
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000028
$L2.5 WriteReg 0x1111 0x00080004   # data byte 00002c
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000030
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000034
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000038
$L2.5 WriteReg 0x1111 0x00080004   # data byte 00003c
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000040
$L2.5 WriteReg 0x1111 0x00080004   # data byte 000044
$L2.5 WriteReg 0x1111 0x00680004   # data byte 000048
$L2.5 WriteReg 0x1111 0xfd40000a   # data byte 00004c
$L2.5 WriteReg 0x1111 0xffff0000   # data byte 000050
$L2.5 WriteReg 0x1111 0xfd50040a   # data byte 000054
$L2.5 WriteReg 0x1111 0xffff0000   # data byte 000058
$L2.5 WriteReg 0x1111 0xfd40080a   # data byte 00005c
$L2.5 WriteReg 0x1111 0xffff0000   # data byte 000060
$L2.5 WriteReg 0x1111 0xa8300c0a   # data byte 000064
$L2.5 WriteReg 0x1111 0xffff0000   # data byte 000068
$L2.5 WriteReg 0x1111 0x1e0a0004   # data byte 00006c
$L2.5 WriteReg 0x1111 0xb910100a   # data byte 000070
$L2.5 WriteReg 0x1111 0xffff0002   # data byte 000074
$L2.5 WriteReg 0x1111 0x0e880004   # data byte 000078
$L2.5 WriteReg 0x1111 0x3520140a   # data byte 00007c
$L2.5 WriteReg 0x1111 0xffff0003   # data byte 000080
$L2.5 WriteReg 0x1111 0x643c0004   # data byte 000084
$L2.5 WriteReg 0x1111 0x8780180a   # data byte 000088
$L2.5 WriteReg 0x1111 0xffff0000   # data byte 00008c
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000090
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000094
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000098
$L2.5 WriteReg 0x1111 0x24d00004   # data byte 00009c
$L2.5 WriteReg 0x1111 0x82e01c0a   # data byte 0000a0
$L2.5 WriteReg 0x1111 0xffff0002   # data byte 0000a4
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000a8
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000ac
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000b0
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000b4
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000b8
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000bc
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000c0
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000c4
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000c8
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000cc
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000d0
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000d4
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000d8
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000dc
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000e0
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000e4
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000e8
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 0000ec
$L2.5 WriteReg 0x1111 0x00300004   # data byte 0000f0
$L2.5 WriteReg 0x1111 0x00000001   # data byte 0000f4
$L2.5 WriteReg 0x1111 0x00180e05   # data byte 0000f8
$L2.5 WriteReg 0x1111 0x00f9fe04   # data byte 0000fc
$L2.5 WriteReg 0x1111 0x0def9e04   # data byte 000100
$L2.5 WriteReg 0x1111 0x00769004   # data byte 000104
$L2.5 WriteReg 0x1111 0x002f9008   # data byte 000108
$L2.5 WriteReg 0x1111 0x06529e04   # data byte 00010c
$L2.5 WriteReg 0x1111 0x09529004   # data byte 000110
$L2.5 WriteReg 0x1111 0x03219008   # data byte 000114
$L2.5 WriteReg 0x1111 0x0cb29e04   # data byte 000118
$L2.5 WriteReg 0x1111 0x19889e08   # data byte 00011c
$L2.5 WriteReg 0x1111 0x32d79e08   # data byte 000120
$L2.5 WriteReg 0x1111 0x65719e08   # data byte 000124
$L2.5 WriteReg 0x1111 0xcaa89e08   # data byte 000128
$L2.5 WriteReg 0x1111 0xc1219e08   # data byte 00012c
$L2.5 WriteReg 0x1111 0xc1229e04   # data byte 000130
$L2.5 WriteReg 0x1111 0x12d18e04   # data byte 000134
$L2.5 WriteReg 0x1111 0xc5bd8e08   # data byte 000138
$L2.5 WriteReg 0x1111 0xc5be8e04   # data byte 00013c
$L2.5 WriteReg 0x1111 0xc5be8e04   # data byte 000140
$L2.5 WriteReg 0x1111 0xc5be8e04   # data byte 000144
$L2.5 WriteReg 0x1111 0x00180e04   # data byte 000148
$L2.5 WriteReg 0x1111 0x00000e01   # data byte 00014c
$L2.5 DLP_RegIO_EndLUTdata  SEQ_LUT 
$L2.5 WriteReg  0x2B8  0x3f0f
$L2.5 WriteReg  0xC0  0x44
$L2.5 WriteReg  0x4C4  0x196e6a


$L2.5 WriteReg  0xCC4  0

$L2.5 WriteReg  0xCD0  0x3c0

$L2.5 WriteReg  0xCC8  0x1

$L2.5 WriteReg  0xCCC  0x8

$L2.5 WriteReg  0xCD8  0x105

$L2.5 WriteReg  0x500  0x0

$L2.5 WriteReg  0xCD4  0x63f5

$L2.5 ExecutePassthroughDLPAPI  _EnablePwmSeq
