#=================================================================
# Configuration Registers/LUTs for DLP LightCommander
#---------------------------------------------------------
#   Created on:  Thu Apr 26 16:21:42 2018 
#   Created by:  Texas Instruments DLP Seq Compiler DLL
#   Version#:    1.5.0
#
#   Output Attributes:
#   Comment                  = Test3.lcp Test3
#   DMD                      = XGA
#   Mode                     = SL
#   Display Pattern Frm Rate = 120 Hz
#   Exposure Time            = 8327 usec
#   Exposure Time/Frm period = 0.99924
#   Num BPP:                 = 1
#   Num Patterns in Seq      = 1
#   Real-time input source   = false
#   Active LEDs              = GLED  
#=================================================================
$L2.5 ExecutePassthroughDLPAPI  _DisablePwmSeq
$L2.5 DLP_RegIO_BeginLUTdata   SEQ_LUT
$L2.5 WriteReg 0x1111 0x00000088   # data byte 000000
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
$L2.5 WriteReg 0x1111 0xa030000a   # data byte 00004c
$L2.5 WriteReg 0x1111 0xffff0003   # data byte 000050
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000054
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000058
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 00005c
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000060
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000064
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000068
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 00006c
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000070
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000074
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 000078
$L2.5 WriteReg 0x1111 0x752e0004   # data byte 00007c
$L2.5 WriteReg 0x1111 0x00300004   # data byte 000080
$L2.5 WriteReg 0x1111 0x00000001   # data byte 000084
$L2.5 WriteReg 0x1111 0x00180405   # data byte 000088
$L2.5 WriteReg 0x1111 0x00f9f404   # data byte 00008c
$L2.5 WriteReg 0x1111 0x0df79404   # data byte 000090
$L2.5 WriteReg 0x1111 0x006e9004   # data byte 000094
$L2.5 WriteReg 0x1111 0x002f9008   # data byte 000098
$L2.5 WriteReg 0x1111 0xc3aa9404   # data byte 00009c
$L2.5 WriteReg 0x1111 0xc3aa9404   # data byte 0000a0
$L2.5 WriteReg 0x1111 0xc9718404   # data byte 0000a4
$L2.5 WriteReg 0x1111 0xc9728404   # data byte 0000a8
$L2.5 WriteReg 0x1111 0x00180404   # data byte 0000ac
$L2.5 WriteReg 0x1111 0x00000401   # data byte 0000b0
$L2.5 DLP_RegIO_EndLUTdata  SEQ_LUT 
$L2.5 WriteReg  0x2B8  0x3f0f
$L2.5 WriteReg  0xC0  0x44
$L2.5 WriteReg  0x4C4  0xcb735


$L2.5 WriteReg  0xCC4  0

$L2.5 WriteReg  0xCD0  0x780

$L2.5 WriteReg  0xCC8  0x1

$L2.5 WriteReg  0xCCC  0x1

$L2.5 WriteReg  0xCD8  0x105

$L2.5 WriteReg  0x500  0x0

$L2.5 WriteReg  0xCD4  0x63ec

$L2.5 ExecutePassthroughDLPAPI  _EnablePwmSeq
