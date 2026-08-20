#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "mi_sys.h"
#include "mi_isp_ae.h"

#include "st_common.h"
#include "st_common_vif.h"
#include "st_common_isp.h"
#include "st_common_scl.h"
#include "st_common_venc.h"
#include "st_common_rtsp_video.h"

#define SNR_PAD_MAX_ID  2

typedef struct ST_VifInputParam_s
{
    MI_U8 u8SensorIndex;
    MI_U8 u8CmdIndex;
    char IqBinPath[128];
} ST_VifInputParam_t;

typedef struct ST_SensorSize_s
{
    MI_U16 u16Width;
    MI_U16 u16Height;
} ST_SensorSize_t;

static ST_VifInputParam_t   g_stVifInputParam;
static ST_SensorSize_t      g_stSensorSize[2];


void ST_Common_Pause_Vif(void)
{
    ST_Common_Pause();
}

static MI_S32 STUB_BaseModuleInit(MI_U8 u8SensorNum)
{
    MI_SNR_PlaneInfo_t stPlaneInfo;
    MI_SYS_ChnPort_t   stSrcChnPort;
    MI_SYS_ChnPort_t   stDstChnPort;
    MI_U32             u32SrcFrmRate;
    MI_U32             u32DstFrmRate;
    MI_SYS_BindType_e  eBindType;
    MI_U32             u32BindParam;
    MI_U32             u32SnrPadId[SNR_PAD_MAX_ID] = {0, 2};
    MI_U8              u8SensorRes = g_stVifInputParam.u8SensorIndex;
    MI_U32             u32VifGroupId[SNR_PAD_MAX_ID] = {0, 1};
    MI_U32             u32VifDevId[SNR_PAD_MAX_ID] = {0, 4};
    MI_U32             u32VifPortId = 0;

    MI_U32             u32IspDevId = 0;
    MI_U32             u32IspChnId[SNR_PAD_MAX_ID] = {0, 1};
    MI_U32             u32IspPortId = 0;

    MI_U32             u32SclDevId = 0;
    MI_U32             u32SclChnId[SNR_PAD_MAX_ID] = {0, 1};
    MI_U32             u32SclPortId = 0;

    MI_U32             u32VencDevId = 0;
    MI_U32             u32VencChnId[SNR_PAD_MAX_ID] = {0, 1};

    /*
     * Step.1 : init system
     */
    STCHECKRESULT(ST_Common_Sys_Init());

    if (u8SensorNum > SNR_PAD_MAX_ID) {
        printf("u8SensorNum:%d larger than SNR_PAD_MAX_ID:%d\n", u8SensorNum, SNR_PAD_MAX_ID);
        u8SensorNum = SNR_PAD_MAX_ID;
    }

    MI_VIF_OutputPortAttr_t stVifPortAttr;
    for (int i = 0; i < u8SensorNum; i++) {
        MI_VIF_GroupAttr_t stVifGroupAttr;
        MI_VIF_DevAttr_t stVifDevAttr;
        /*
         * Step.2 : init sensor/vif
         */
        STCHECKRESULT(ST_Common_SensorInit(u32SnrPadId[i], FALSE, u8SensorRes, 0xff));

        memset(&stPlaneInfo, 0, sizeof(MI_SNR_PlaneInfo_t));
        STCHECKRESULT(MI_SNR_GetPlaneInfo(u32SnrPadId[i], 0, &stPlaneInfo));
        g_stSensorSize[i].u16Width = stPlaneInfo.stCapRect.u16Width;
        g_stSensorSize[i].u16Height = stPlaneInfo.stCapRect.u16Height;

        ST_Common_GetVifDefaultGrouptAttr(&stVifGroupAttr);
        STCHECKRESULT(ST_Common_VifCreateDevGroup(u32VifGroupId[i], &stVifGroupAttr));

        ST_Common_GetVifDefaultDevAttr(&stVifDevAttr);
        stVifDevAttr.eInputPixel = RGB_BAYER_PIXEL(E_MI_SYS_DATA_PRECISION_12BPP, E_MI_SYS_PIXEL_BAYERID_RG);
        stVifDevAttr.eDataPrecision = E_MI_SYS_DATA_PRECISION_12BPP;
        STCHECKRESULT(ST_Common_VifEnableDev(u32VifDevId[i], &stVifDevAttr));

        ST_Common_GetVifDefaultPortAttr(&stVifPortAttr);
    }

    /*
     * Step.3 : init ISP
     */
    MI_ISP_DevAttr_t stIspDevAttr;
    MI_ISP_ChannelAttr_t stIspChnAttr;
    MI_ISP_ChnParam_t stIspChnParam;
    MI_SYS_WindowRect_t stIspInputCrop;
    MI_ISP_OutPortParam_t stIspOutPortParam;

    ST_Common_GetIspDefaultDevAttr(&stIspDevAttr);
    STCHECKRESULT(ST_Common_IspCreateDevice(u32IspDevId, &stIspDevAttr));
    for (int i = 0; i < u8SensorNum; i++) {
        ST_Common_GetIspDefaultChnAttr(&stIspChnAttr, &stIspInputCrop, &stIspChnParam);

        if (i == 0) {
            stIspChnAttr.u32SensorBindId = E_MI_ISP_SENSOR0;
        }
        else {
            stIspChnAttr.u32SensorBindId = E_MI_ISP_SENSOR2;
        }

        STCHECKRESULT(ST_Common_IspStartChn(u32IspDevId, u32IspChnId[i], &stIspChnAttr, &stIspInputCrop, &stIspChnParam));
        ST_Common_GetIspDefaultPortAttr(&stIspOutPortParam);
        STCHECKRESULT(ST_Common_IspEnablePort(u32IspDevId, u32IspChnId[i], u32IspPortId, &stIspOutPortParam));

        /*
         * Step.4 : Bind vif->isp
         */
        memset(&stSrcChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        memset(&stDstChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        stSrcChnPort.eModId = E_MI_MODULE_ID_VIF;
        stSrcChnPort.u32DevId = u32VifDevId[i];
        stSrcChnPort.u32ChnId = 0;
        stSrcChnPort.u32PortId = u32VifPortId;
        stDstChnPort.eModId = E_MI_MODULE_ID_ISP;
        stDstChnPort.u32DevId = u32IspDevId;
        stDstChnPort.u32ChnId = u32IspChnId[i];
        stDstChnPort.u32PortId = u32IspPortId;
        u32SrcFrmRate = 30;
        u32DstFrmRate = 30;
        if (u8SensorNum == 1) {
            eBindType = E_MI_SYS_BIND_TYPE_REALTIME;
        }
        if (u8SensorNum == 2) {
            eBindType = E_MI_SYS_BIND_TYPE_FRAME_BASE;
        }
        u32BindParam = 0;

        STCHECKRESULT(MI_SYS_BindChnPort2(0, &stSrcChnPort, &stDstChnPort, u32SrcFrmRate, u32DstFrmRate, eBindType, u32BindParam));

        stDstChnPort.u32PortId = u32IspPortId + 1;
        STCHECKRESULT(ST_Common_IspEnablePort(u32IspDevId, u32IspChnId[i], stDstChnPort.u32PortId, &stIspOutPortParam));
        STCHECKRESULT(MI_SYS_SetChnOutputPortDepth(0, &stDstChnPort, 1, 4));
    }

    /*
     * Step.5 : init SCL
     */
    MI_SCL_DevAttr_t stSclDevAttr;
    MI_SCL_ChannelAttr_t stSclChnAttr;
    MI_SCL_ChnParam_t stSclChnParam;
    MI_SYS_WindowRect_t stSclInputCrop;
    MI_SCL_OutPortParam_t stSclOutPortParam;

    ST_Common_GetSclDefaultDevAttr(&stSclDevAttr);
    STCHECKRESULT(ST_Common_SclCreateDevice(u32SclDevId, &stSclDevAttr));
    for (int i = 0; i < u8SensorNum; i++) {
        ST_Common_GetSclDefaultChnAttr(&stSclChnAttr, &stSclInputCrop, &stSclChnParam);
        STCHECKRESULT(ST_Common_SclStartChn(u32SclDevId, u32SclChnId[i], &stSclChnAttr, &stSclInputCrop, &stSclChnParam));

        /*
         * Step.6 : Bind isp->scl
         */
        memset(&stSrcChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        memset(&stDstChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        stSrcChnPort.eModId = E_MI_MODULE_ID_ISP;
        stSrcChnPort.u32DevId = u32IspDevId;
        stSrcChnPort.u32ChnId = u32IspChnId[i];
        stSrcChnPort.u32PortId = u32IspPortId;
        stDstChnPort.eModId = E_MI_MODULE_ID_SCL;
        stDstChnPort.u32DevId = u32SclDevId;
        stDstChnPort.u32ChnId = u32SclChnId[i];
        stDstChnPort.u32PortId = u32SclPortId;
        u32SrcFrmRate = 30;
        u32DstFrmRate = 30;
        eBindType = E_MI_SYS_BIND_TYPE_REALTIME;
        u32BindParam = 0;
        STCHECKRESULT(MI_SYS_BindChnPort2(0, &stSrcChnPort, &stDstChnPort, u32SrcFrmRate, u32DstFrmRate, eBindType, u32BindParam));
        // In order to work out the image as soon as the entire pipeline is created,
        // otherwise the first image of vif will be wasted and the next image have to wait a timeout of 100ms
        // when vif is enabled without bind the next module.
        STCHECKRESULT(ST_Common_VifEnablePort(u32VifDevId[i], u32VifPortId, &stVifPortAttr));
    }

    /*
     * Step.7 : init venc
     */
    MI_VENC_InitParam_t stVencInitParam;
    MI_VENC_ChnAttr_t stVencChnAttr;

    ST_Common_GetVencDefaultDevAttr(&stVencInitParam);
    STCHECKRESULT(ST_Common_VencCreateDev(u32VencDevId, &stVencInitParam));
    ST_Common_GetSclDefaultPortAttr(&stSclOutPortParam);
    for (int i = 0; i < u8SensorNum; i++) {
        MI_VENC_ModType_e eType = E_MI_VENC_MODTYPE_H265E;
        memset(&stPlaneInfo, 0, sizeof(MI_SNR_PlaneInfo_t));
        STCHECKRESULT(MI_SNR_GetPlaneInfo(u32SnrPadId[i], 0, &stPlaneInfo));

        ST_Common_GetVencDefaultChnAttr(eType, &stVencChnAttr);
        stVencChnAttr.stVeAttr.stAttrH265e.u32PicWidth = g_stSensorSize[i].u16Width;
        stVencChnAttr.stVeAttr.stAttrH265e.u32PicHeight = g_stSensorSize[i].u16Height;
        STCHECKRESULT(ST_Common_VencStartChn(u32VencDevId, u32VencChnId[i], &stVencChnAttr));

        /*
         * Step.8 : bind scl->venc
         */
        memset(&stSrcChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        memset(&stDstChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        stSrcChnPort.eModId = E_MI_MODULE_ID_SCL;
        stSrcChnPort.u32DevId = u32SclDevId;
        stSrcChnPort.u32ChnId = u32SclChnId[i];
        stSrcChnPort.u32PortId = u32SclPortId;
        stDstChnPort.eModId = E_MI_MODULE_ID_VENC;
        stDstChnPort.u32DevId = u32VencDevId;
        stDstChnPort.u32ChnId = u32VencChnId[i];
        stDstChnPort.u32PortId = 0;
        u32SrcFrmRate = 30;
        u32DstFrmRate = 30;
        eBindType = E_MI_SYS_BIND_TYPE_FRAME_BASE;
        u32BindParam = 0;
        STCHECKRESULT(MI_SYS_BindChnPort2(0, &stSrcChnPort, &stDstChnPort, u32SrcFrmRate, u32DstFrmRate, eBindType, u32BindParam));

        stSclOutPortParam.stSCLOutputSize.u16Width = g_stSensorSize[i].u16Width;
        stSclOutPortParam.stSCLOutputSize.u16Height = g_stSensorSize[i].u16Height;
        STCHECKRESULT(ST_Common_SclEnablePort(u32SclDevId, u32SclChnId[i], u32SclPortId, &stSclOutPortParam));
        STCHECKRESULT(MI_SYS_SetChnOutputPortDepth(0, &stSrcChnPort, 0, 4));
    }

    return MI_SUCCESS;
}

static MI_S32 STUB_BaseModuleDeInit(MI_U8 u8SensorNum)
{
    MI_SYS_ChnPort_t stSrcChnPort;
    MI_SYS_ChnPort_t stDstChnPort;
    MI_U32 u32SnrPadId[2] = {0, 2};
    MI_U32 u32VifGroupId[2] = {0, 1};
    MI_U32 u32VifDevId[2] = {0, 4};
    MI_U32 u32VifPortId = 0;
    MI_U32 u32IspDevId = 0;
    MI_U32 u32IspChnId[2] = {0, 1};
    MI_U32 u32IspPortId = 0;
    MI_U32 u32SclDevId = 0;
    MI_U32 u32SclChnId[2] = {0, 1};
    MI_U32 u32SclPortId = 0;
    MI_U32 u32VencDevId = 0;
    MI_U32 u32VencChnId[2] = {0, 1};

    /*
     * Step.1 : unbind scl->venc
     */
    for (int i = 0; i < u8SensorNum; i++) {
        memset(&stSrcChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        memset(&stDstChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        stSrcChnPort.eModId = E_MI_MODULE_ID_SCL;
        stSrcChnPort.u32DevId = u32SclDevId;
        stSrcChnPort.u32ChnId = u32SclChnId[i];
        stSrcChnPort.u32PortId = u32SclPortId;
        stDstChnPort.eModId = E_MI_MODULE_ID_VENC;
        stDstChnPort.u32DevId = u32VencDevId;
        stDstChnPort.u32ChnId = u32VencChnId[i];
        stDstChnPort.u32PortId = 0;
        STCHECKRESULT(MI_SYS_UnBindChnPort(0, &stSrcChnPort, &stDstChnPort));

        /*
         * Step.2 : deinit venc
         */
        STCHECKRESULT(ST_Common_VencStopChn(u32VencDevId, u32VencChnId[i]));
    }
    STCHECKRESULT(ST_Common_VencDestroyDev(u32VencDevId));

    /*
     * Step.3 : unbind isp->scl
     */
    for (int i = 0; i < u8SensorNum; i++) {
        memset(&stSrcChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        memset(&stDstChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        stSrcChnPort.eModId = E_MI_MODULE_ID_ISP;
        stSrcChnPort.u32DevId = u32IspDevId;
        stSrcChnPort.u32ChnId = u32IspChnId[i];
        stSrcChnPort.u32PortId = u32IspPortId;
        stDstChnPort.eModId = E_MI_MODULE_ID_SCL;
        stDstChnPort.u32DevId = u32SclDevId;
        stDstChnPort.u32ChnId = u32SclChnId[i];
        stDstChnPort.u32PortId = u32SclPortId;
        STCHECKRESULT(MI_SYS_UnBindChnPort(0, &stSrcChnPort, &stDstChnPort));

        /*
         * Step.4 : deinit scl
         */
        STCHECKRESULT(ST_Common_SclDisablePort(u32SclDevId, u32SclChnId[i], u32SclPortId));
        STCHECKRESULT(ST_Common_SclStopChn(u32SclDevId, u32SclChnId[i]));
        STCHECKRESULT(ST_Common_IspDisablePort(u32IspDevId, u32IspChnId[i], u32IspPortId + 1));
    }
    STCHECKRESULT(ST_Common_SclDestroyDevice(u32SclDevId));

    /*
     * Step.5 : unbind vif->isp
     */
    for (int i = 0; i < u8SensorNum; i++) {
        memset(&stSrcChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        memset(&stDstChnPort, 0, sizeof(MI_SYS_ChnPort_t));
        stSrcChnPort.eModId = E_MI_MODULE_ID_VIF;
        stSrcChnPort.u32DevId = u32VifDevId[i];
        stSrcChnPort.u32ChnId = 0;
        stSrcChnPort.u32PortId = u32VifPortId;
        stDstChnPort.eModId = E_MI_MODULE_ID_ISP;
        stDstChnPort.u32DevId = u32IspDevId;
        stDstChnPort.u32ChnId = u32IspChnId[i];
        stDstChnPort.u32PortId = u32IspPortId;
        STCHECKRESULT(MI_SYS_UnBindChnPort(0, &stSrcChnPort, &stDstChnPort));

        /*
         * Step.6 : deinit isp
         */
        STCHECKRESULT(ST_Common_IspDisablePort(u32IspDevId, u32IspChnId[i], u32IspPortId));
        STCHECKRESULT(ST_Common_IspStopChn(u32IspDevId, u32IspChnId[i]));
    }
    STCHECKRESULT(ST_Common_IspDestroyDevice(u32IspDevId));

    /*
     * Step.7 : deinit vif/sensor
     */
    for (int i = 0; i < u8SensorNum; i++) {
        STCHECKRESULT(ST_Common_VifDisablePort(u32VifDevId[i], u32VifPortId));
        STCHECKRESULT(ST_Common_VifDisableDev(u32VifDevId[i]));
        STCHECKRESULT(ST_Common_VifDestroyDevGroup(u32VifGroupId[i]));
        STCHECKRESULT(ST_Common_SensorDeInit(u32SnrPadId[i]));
    }

    /*
     * Step.8 : sys exit
     */
    STCHECKRESULT(ST_Common_Sys_Exit());

    return MI_SUCCESS;
}

static MI_S32 ST_SingleSensorPipeline_Preview(void)
{
    MI_U8 u8SensorNum = 1;
    MI_U32 u32VencDevId = 0;
    MI_U32 u32VencChnId = 0;
    MI_U32 u32IspDevId = 0;
    MI_U32 u32IspChnId = 0;
    MI_U32 u32SensorPad = 0;
    char IqApiBinFilePath[128];
    MI_SNR_PlaneInfo_t stPlaneInfo;
    ST_VideoStreamInfo_t stStreamInfo;

    STCHECKRESULT(STUB_BaseModuleInit(u8SensorNum));

    if (strlen(g_stVifInputParam.IqBinPath) == 0) {
        MI_SNR_GetPlaneInfo(u32SensorPad, 0, &stPlaneInfo);
        sprintf(IqApiBinFilePath, "/config/iqfile/sc4336P_api.bin");
    }
    else {
        strcpy(IqApiBinFilePath, g_stVifInputParam.IqBinPath);
    }
    ST_Common_IspSetIqBin(u32IspDevId, u32IspChnId, IqApiBinFilePath);

    memset(&stStreamInfo, 0, sizeof(ST_VideoStreamInfo_t));
    stStreamInfo.eType = E_MI_VENC_MODTYPE_H265E;
    stStreamInfo.VencDev = u32VencDevId;
    stStreamInfo.VencChn = u32VencChnId;
    stStreamInfo.u32Width = g_stSensorSize[0].u16Width;
    stStreamInfo.u32Height = g_stSensorSize[0].u16Height;
    stStreamInfo.u32FrameRate = 30;
    stStreamInfo.rtspIndex = 0;

    // start rtsp
    ST_Common_RtspServerStartVideo(&stStreamInfo);
    ST_Common_Pause_Vif();

    // stop rtsp
    ST_Common_RtspServerStopVideo(&stStreamInfo);

    STCHECKRESULT(STUB_BaseModuleDeInit(u8SensorNum));

    return MI_SUCCESS;
}

static MI_S32 ST_DualSensorPipeline_Preview(void)
{
    MI_U8 u8SensorNum = 2;
    MI_U32 u32VencDevId = 0;
    MI_U32 u32VencChnId[2] = {0, 1};
    ST_VideoStreamInfo_t stStreamInfo[2];
    STCHECKRESULT(STUB_BaseModuleInit(u8SensorNum));

    // start rtsp
    for (int i = 0; i < u8SensorNum; i++) {
        memset(&stStreamInfo[i], 0, sizeof(ST_VideoStreamInfo_t));
        stStreamInfo[i].eType = E_MI_VENC_MODTYPE_H265E;
        stStreamInfo[i].VencDev = u32VencDevId;
        stStreamInfo[i].VencChn = u32VencChnId[i];
        stStreamInfo[i].u32Width = g_stSensorSize[i].u16Width;
        stStreamInfo[i].u32Height = g_stSensorSize[i].u16Height;
        stStreamInfo[i].u32FrameRate = 30;
        stStreamInfo[i].rtspIndex = i;
        // start rtsp
        STCHECKRESULT(ST_Common_RtspServerStartVideo(&stStreamInfo[i]));
    }
    ST_Common_Pause_Vif();

    // stop rtsp
    for (int i = 0; i < u8SensorNum; i++) {
        STCHECKRESULT(ST_Common_RtspServerStopVideo(&stStreamInfo[i]));
    }
    STCHECKRESULT(STUB_BaseModuleDeInit(u8SensorNum));

    return MI_SUCCESS;
}

void ST_Vif_Usage(void)
{
    printf("Usage:./fridge_ai 0   single sensor realtime vif->isp->scl->venc->rtsp\n");
    printf("Usage:./fridge_ai 1   dual sensor realtime vif->isp->scl->venc->rtsp\n");
    printf("Usage:./fridge_ai x index x iqbin xxx.bin   set sensor Resinded and iqbin\n");
}

MI_S32 ST_Vif_GetCmdlineParam(int argc, char *argv[])
{
    g_stVifInputParam.u8SensorIndex = 0xff;
    g_stVifInputParam.u8CmdIndex = atoi(argv[1]);
    memset(g_stVifInputParam.IqBinPath, 0, 128);

    for (int i = 0; i < argc; i++) {
        if (0 == strcmp(argv[i], "index")) {
            g_stVifInputParam.u8SensorIndex = atoi(argv[i + 1]);
        }
        else if (0 == strcmp(argv[i], "iqbin")) {
            strcpy(g_stVifInputParam.IqBinPath, argv[i + 1]);
        }
    }

    return MI_SUCCESS;
}

MI_S32 main(int argc, char *argv[])
{
    if (argc < 2) {
        ST_Vif_Usage();
        return -1;
    }
    ST_Vif_GetCmdlineParam(argc, argv);
    switch (g_stVifInputParam.u8CmdIndex) {
        case 0:
            STCHECKRESULT(ST_SingleSensorPipeline_Preview());
            break;
        case 1:
            STCHECKRESULT(ST_DualSensorPipeline_Preview());
            break;
        default:
            printf("the index is invalid\n");
            ST_Vif_Usage();
            return -1;
    }

    memset(&g_stVifInputParam, 0, sizeof(ST_VifInputParam_t));
    memset(&g_stSensorSize, 0, sizeof(ST_SensorSize_t) * 2);

    return 0;
}
