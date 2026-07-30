/* SigmaStar trade secret */
/* Copyright (c) [2019~2020] SigmaStar Technology.
All rights reserved.

Unless otherwise stipulated in writing, any and all information contained
herein regardless in any format shall remain the sole proprietary of
SigmaStar and be kept in strict confidence
(SigmaStar Confidential Information) by the recipient.
Any unauthorized act including without limitation unauthorized disclosure,
copying, use, reproduction, sale, distribution, modification, disassembling,
reverse engineering and compiling of the contents of SigmaStar Confidential
Information is unlawful and strictly prohibited. SigmaStar hereby reserves the
rights to any and all damages, losses, costs and expenses resulting therefrom.
*/

#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#define FR_POINT_LEN 5
#define MODEL_MAX_LENGTH (256)
#define IPU_MAX_LENGTH (256)
typedef struct FrPoint_
{
    MI_FLOAT x;
    MI_FLOAT y;
}FrPoint_t;
typedef struct DetectBox_
{
    MI_FLOAT x1;
    MI_FLOAT y1;
    MI_FLOAT x2;
    MI_FLOAT y2;
    MI_FLOAT score;
    FrPoint_t landmark[FR_POINT_LEN];
    MI_S32 face_id;
    MI_S32 befiltered;
}DetectBox_t;
typedef struct ParamDet_
{
    MI_S32 datatype;
}ParamDet_t;
typedef struct AlgoFrInputInfo_
{
    void* pt_tensor_data;
    MI_PHY phy_tensor_addr;//notice that this is miu bus addr,not cpu bus addr.
    MI_U32 bufsize;
    MI_S64 pts;
}AlgoFrInputInfo_t;
typedef struct InitFrParam_
{
    MI_U8 ipu_firware_bin[IPU_MAX_LENGTH];
    MI_U8 det_model_path[MODEL_MAX_LENGTH];
    MI_U8 feature_model_path[MODEL_MAX_LENGTH];
    MI_FLOAT det_thredhold;
    MI_S32   box_min_size;
    MI_FLOAT filter_angle_ratio;
    MI_FLOAT eye_distance;
}InitFrParam_t;
MI_S32 ALGO_FR_Init(InitFrParam_t initParam);
MI_S32 ALGO_FR_CreateHandle(MI_S64* detectorId);
MI_S32 ALGO_FR_Detect(MI_S64 detectId, AlgoFrInputInfo_t *stBufInfo, MI_S32 width, MI_S32 height,ParamDet_t* params, DetectBox_t** detectOut, MI_S32* faceCount);
MI_S32 ALGO_FR_Align(MI_U8* imageData, MI_S32 width, MI_S32 height, MI_S32 type, DetectBox_t detectOut, MI_U8* outData);
MI_S32 ALGO_FR_FeatureExtract(MI_S64 detectId, MI_U8* imageData, MI_S16* featureOut);
MI_S32 ALGO_FR_FeatureCompare(MI_S16* feature1, MI_S16* feature2, MI_S32 length, MI_FLOAT* simility);
MI_S32 ALGO_FR_ReleaseHandle(MI_S64 detectorId);
MI_S32 ALGO_FR_Cleanup();
#ifdef __cplusplus
}
#endif
