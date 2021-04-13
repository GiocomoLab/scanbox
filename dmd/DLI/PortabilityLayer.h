#if !defined (PORTABILITYLAYER_H)
#define PORTABILITYLAYER_H

/***************************************************************************** 
** 
** TEXAS INSTRUMENTS PROPRIETARY INFORMATION 
** 
** (c) Copyright, Texas Instruments Incorporated, 2010. 
** All Rights Reserved. 
** 
** Property of Texas Instruments Incorporated. Restricted Rights - 
** Use, duplication, or disclosure is subject to restrictions set 
** forth in TI's program license agreement and associated documentation. 
*******************************************************************************/

#ifdef __cplusplus
extern "C" { 
#endif

typedef char			Char;
typedef double			Double;
typedef signed char		Int8;
typedef signed short	Int16;
typedef signed int		Int32;
typedef unsigned char	UInt8;
typedef unsigned short	UInt16;
typedef unsigned int	UInt32;
typedef const char*		String;
typedef UInt8			Byte;
typedef void			Void;
typedef int				Boolean;
typedef Byte**			IntPtr;
typedef char*			StringBuilder;

// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the PORTABILITYLAYER_EXPORTS
// symbol defined on the command line. this symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// PORTABILITYLAYER_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.
#ifdef PORTABILITYLAYER_EXPORTS
#define PORTABILITYLAYER_API
#define LC(name)    LC_##name
#else
#define PORTABILITYLAYER_API __declspec(dllimport)
#define LC(name)    name
#endif

#define DMD_t_SHARP_VERNUM 1
#if !defined(DMD_t_VERNUM) || DMD_t_VERNUM!=DMD_t_CUR_VERNUM
#define DMD_t_VERNUM DMD_t_SHARP_VERNUM
typedef enum {
	DMD_XGA,
} DMD_t;
#endif

typedef enum {
	STAT_OK,
	STAT_ERROR,
} Status;

#define LED_t_SHARP_VERNUM 1
#if !defined(LED_t_VERNUM) || LED_t_VERNUM!=LED_t_CUR_VERNUM
#define LED_t_VERNUM LED_t_SHARP_VERNUM
typedef enum {
	LED_R,
	LED_G,
	LED_B,
	LED_IR,
	NUM_LEDS,
} LED_t;
#endif

#define SEQDATA_t_SHARP_VERNUM 1
#if !defined(SEQDATA_t_VERNUM) || SEQDATA_t_VERNUM!=SEQDATA_t_CUR_VERNUM
#define SEQDATA_t_VERNUM SEQDATA_t_SHARP_VERNUM
typedef enum {
	SDM_SL,
	SDM_SL_RT,
	SDM_VIDEO,
	SDM_MIXED,
	SDM_OBJ,
} SEQDATA_t;
#endif

typedef Void (__cdecl *OutputCallback)(String message);

typedef Void (__cdecl *CommPacketCallback)(IntPtr intPtr, UInt16 nBufBytes);

typedef Byte (__cdecl *ProgressCallback)(Double complete);

#define DATA_t_SHARP_VERNUM 1
#if !defined(DATA_t_VERNUM) || DATA_t_VERNUM!=DATA_t_CUR_VERNUM
#define DATA_t_VERNUM DATA_t_SHARP_VERNUM
typedef enum {
	DVI,
	EXP,
	TPG,
	SL_AUTO,
	SL_EXT3P3,
	SL_EXT1P8,
	SL_SW,
} DATA_t;
#endif

#define TPG_t_SHARP_VERNUM 1
#if !defined(TPG_t_VERNUM) || TPG_t_VERNUM!=TPG_t_CUR_VERNUM
#define TPG_t_VERNUM TPG_t_SHARP_VERNUM
typedef enum {
	SOLID,
	HORIZ_RAMP,
	VERT_RAMP,
	HORIZ_LINES,
	DIAG_LINES,
	VERT_LINES,
	HORIZ_STRIPES,
	VERT_STRIPES,
	GRID,
	CHECKERBOARD,
	NUM_PATTERNS,
} TPG_t;
#endif

#define TPG_Col_t_SHARP_VERNUM 1
#if !defined(TPG_Col_t_VERNUM) || TPG_Col_t_VERNUM!=TPG_Col_t_CUR_VERNUM
#define TPG_Col_t_VERNUM TPG_Col_t_SHARP_VERNUM
typedef enum {
	TPG_BLACK,
	TPG_RED,
	TPG_GREEN,
	TPG_BLUE,
	TPG_YELLOW,
	TPG_CYAN,
	TPG_MAGENTA,
	TPG_WHITE,
} TPG_Col_t;
#endif

PORTABILITYLAYER_API Status LC(DLP_Misc_ProgramEDID)(DMD_t DMD, Byte offset, Byte numBytes, String fileName);
PORTABILITYLAYER_API Status LC(DLP_Status_GetOverallLEDlampLitState)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetOverallLEDdriverTempTimeoutState)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetSeqDataFrameRate)(Double* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetSeqDataExposure)(Double* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetSeqDataNumPatterns)(UInt16* numPatterns_out);
PORTABILITYLAYER_API Status LC(DLP_Status_CommunicationStatus)();
PORTABILITYLAYER_API Status LC(DLP_RegIO_ReadLUT)(String LUTname);
PORTABILITYLAYER_API Status LC(DLP_Status_GetLEDdriverTempTimeoutState)(LED_t LED, Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetSeqDataMode)(SEQDATA_t* mode_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetLEDdriverLitState)(LED_t LED, Byte* state_out);
PORTABILITYLAYER_API Byte LC(DLP_FlashCompile_GetCompileMode)();
PORTABILITYLAYER_API Status LC(DLP_Sync_SetEnable)(Byte syncNumber, Byte enableBit);
PORTABILITYLAYER_API Status LC(DLP_Sync_Configure)(Byte syncNumber, Byte polarity, UInt32 delay, UInt32 width);
PORTABILITYLAYER_API Status LC(DLP_RegIO_InitFromParallelFlashOffset)(UInt32 offset, Byte reset);
PORTABILITYLAYER_API Status LC(DLP_LED_GetLEDintensity)(LED_t LED, Double* intensityPerCent);
PORTABILITYLAYER_API Status LC(DLP_Misc_GetTotalNumberOfUSBDevicesConnected)(Byte* ndev_out);
PORTABILITYLAYER_API Status LC(DLP_Misc_SetUSBDeviceNumber)(Byte devNum0b);
PORTABILITYLAYER_API Status LC(DLP_Misc_GetUSBDeviceNumber)(Byte* devnum0b_out);
PORTABILITYLAYER_API Status LC(DLP_FlashProgram_ReadParallelFlashToFile)(String ofilename, UInt32 flash_byte_offset, UInt32 nBytesToRead);
PORTABILITYLAYER_API Status ReadReg(String name, UInt32* content);
PORTABILITYLAYER_API Status WriteReg(String name, UInt32 content);
PORTABILITYLAYER_API Status RunBatchFile(String name, Boolean stopOnError);
PORTABILITYLAYER_API Status RunBatchCommand(String command);
PORTABILITYLAYER_API Status WriteExternalImage(String name, UInt16 imageIndex);
PORTABILITYLAYER_API Status LC(DLP_RegIO_BeginLUTdata)(String name);
PORTABILITYLAYER_API Status LC(DLP_RegIO_EndLUTdata)(String name);
PORTABILITYLAYER_API Status LC(DLP_Display_DisplayPatternManualStep)();
PORTABILITYLAYER_API Status LC(DLP_Display_DisplayPatternManualForceFirstPattern)();
PORTABILITYLAYER_API Status LC(DLP_RegIO_WriteImageOrderLut)(Byte bitsPerPixel, UInt16 imageOrder[], UInt16 nArrElements);
PORTABILITYLAYER_API Status LC(DLP_Display_DisplayPatternAutoStepForSinglePass)();
PORTABILITYLAYER_API Status LC(DLP_Img_UploadBitplanePatternUsbFromExtMem)(String filePath, UInt16 bitPlaneIndex);
PORTABILITYLAYER_API Status LC(DLP_Display_DisplayPatternAutoStepRepeatForMultiplePasses)();
PORTABILITYLAYER_API Status LC(DLP_Img_DownloadBitplanePatternToExtMem)(Byte pBuf[], UInt32 tot_bytes, UInt16 bpnum0b);
PORTABILITYLAYER_API Status LC(DLP_Img_DownloadBitplanePatternFromFlashToExtMem)(UInt32 flashOffset, UInt32 totalBytes, UInt16 bitPlane);
PORTABILITYLAYER_API Status InitPortabilityLayer(Byte logLevel, Byte detail, OutputCallback callback);
PORTABILITYLAYER_API Status ChangeLogLevel(Byte logLevel);
PORTABILITYLAYER_API Status LC(DLP_Misc_EnableCommunication)();
PORTABILITYLAYER_API Status LC(DLP_Misc_DisableCommunication)(String ofileName);
PORTABILITYLAYER_API Status LC(DLP_Misc_DisableCommunication_FlushOutputFileToDisk)();
PORTABILITYLAYER_API Status ExecutePassthroughDLPAPI(IntPtr args);
PORTABILITYLAYER_API Status LC(DLP_LED_LEDdriverEnable)(Byte enable);
PORTABILITYLAYER_API Status LC(DLP_LED_GetLEDdriverTimeout)(Byte* timedOut);
PORTABILITYLAYER_API Status LC(DLP_LED_SetLEDintensity)(LED_t led, Double intensityPercent);
PORTABILITYLAYER_API Status LC(DLP_LED_SetLEDEnable)(LED_t led, Byte enableBit);
PORTABILITYLAYER_API Status LC(DLP_FlashCompile_SetCommPacketCallback)(CommPacketCallback commPacketCallback);
PORTABILITYLAYER_API Status LC(DLP_FlashCompile_FlushCommPacketBuffer)();
PORTABILITYLAYER_API Status LC(DLP_FlashCompile_SetCompileMode)(Boolean enableBit);
PORTABILITYLAYER_API IntPtr GetAllBitPlanes(String name, UInt32 bpp, UInt32* bitPlaneSize);
PORTABILITYLAYER_API Status destroyBitPlanes(IntPtr bitPlanes, UInt32 bpp);
PORTABILITYLAYER_API Status LC(DLP_FlashProgram_ProgramParallelFlash)(UInt32 skipBytesInFlash, Byte pBuf[], UInt32 bytesInBuf, ProgressCallback cb, Byte verifyFlag, UInt16* crc);
PORTABILITYLAYER_API Status LC(DLP_FlashProgram_ProgramSerialFlash)(UInt32 skipBytesInFlash, Byte pBuf[], UInt32 bytesInBuf, ProgressCallback cb, Byte verifyFlag, UInt16* crc);
PORTABILITYLAYER_API Status LC(DLP_Display_DisplayStop)();
PORTABILITYLAYER_API Status LC(DLP_Display_ParkDMD)();
PORTABILITYLAYER_API Status LC(DLP_Display_UnparkDMD)();
PORTABILITYLAYER_API Status LC(DLP_Display_SetDegammaEnable)(Byte enableBit);
PORTABILITYLAYER_API Status LC(DLP_Display_HorizontalFlip)(Byte enableBit);
PORTABILITYLAYER_API Status LC(DLP_Display_VerticalFlip)(Byte enableBit);
PORTABILITYLAYER_API Status LC(DLP_Source_SetDataSource)(DATA_t source);
PORTABILITYLAYER_API Status LC(DLP_TPG_SetTestPattern)(DMD_t DMD, TPG_t testPattern, TPG_Col_t color, UInt16 patternFreq);
PORTABILITYLAYER_API Status LC(DLP_Trigger_SetExternalTriggerEdge)(Byte edge);
PORTABILITYLAYER_API Status WriteSYNC(Byte syncNumber, Byte enableBit, UInt32 delayUsec, UInt32 pulseWidth, Byte polarity);
PORTABILITYLAYER_API Status LC(DLP_Misc_GetVersionString)(StringBuilder ver, Int32 cbSize);
PORTABILITYLAYER_API Status LC(DLP_Status_GetFlashSeqCompilerVersionString)(StringBuilder ver, Int32 cbSize);
PORTABILITYLAYER_API Status LC(DLP_Status_GetMCUversionString)(StringBuilder ver, Int32 cbSize);
PORTABILITYLAYER_API Status LC(DLP_Status_GetDlpControllerVersionString)(StringBuilder ver, Int32 cbSize);
PORTABILITYLAYER_API Status LC(DLP_Status_GetDMDparkState)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetDMDhardwareParkState)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetDMDsoftwareParkState)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetSeqRunState)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetEEPROMfault)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetDADfault)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetLEDdriverFault)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetUARTfault)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetFlashProgrammingMode)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetDADcommStatus)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetDMDcommStatus)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetLEDcommStatus)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetSeqDataBPP)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetBISTdone)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetBISTfail)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_Status_GetInitFromParallelFlashFail)(Byte* state_out);
PORTABILITYLAYER_API Status LC(DLP_FlashProgram_EraseParallelFlash)(UInt32 nSkipBytesInFlash, UInt32 nBytesToErase);
#ifdef __cplusplus
 } 
#endif

#endif
