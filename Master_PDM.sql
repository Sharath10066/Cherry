PROCEDURE POST_SQL_ITEM (
      P_JOB_INSTANCE_ID   IN     FDL_SNOP_SCDHUB.PROCESS_JOB_HEADER.JOB_INSTANCE_ID%TYPE DEFAULT NULL,
      P_SYS_SOURCE        IN     VARCHAR2,
      P_SYNC_UP_ID        IN     FDL_SNOP_SCDHUB.AIF_LAST_SYNC_UP.SYNC_UP_ID%TYPE,
      P_ERROR_CODE           OUT INTEGER,
      P_ERROR_MSG            OUT VARCHAR2)
   IS
      /*************************************************************************************************
             PURPOSE   : These procedures will be called in post sql of  informatica jobs WF_IN_ORDER_HOLD_EVENT

             Date             Author            Description
             ----------      ---------------   ------------------------------------
               17/03/201      Sambasivarao .M      This procedure merge the data from IN_TIEM_LOCATION  into MST_ITEM_LOCATION_BOM
              05/10/2010      Krishnamurthy J  Modified to Insert/Update data based on the SYS Source (Change Number - 0001)
              07/04/2011      Krishnamurthy J  Added Audit Columns in Merge Statements (Change Number - 0002)
              01/07/2011      kotturu_sunil_kumar Added TRIM to COMMODITY_CODE column in ITEM for GLOVIA sources to remove unwanted space (Change number --0003)
             03/10/2011      T.Vidhya Santhoshima  Added Changes for E2E R1 - Added new columns TECHNICAL_PROCESS_DESC, TECHNICAL_VENDOR(Change Number - 0006)
             04/16/2012      T.Vidhya Santhoshima Added Changes for AMCF Project - Added new columns LIFE_CYCLE_STATE, LIFE_CYCLE_REV_DATE, REASON_FOR_OBSOLETE (Change Number --0007)
             05/24/2012      T.Vidhya Santhoshima  Added Changes for Production Fix - Added error table to track the error records , also prevent complete rollback of the transaction (Change Number - 0007)
             08/06/2012     T.Vidhya Santhoshima   Added update for sys_last_modified_date when ever we are setting sys_ent_state as 'deleted'
             01/02/2013     Utham reddy           Added code to hanlde country code issue on mst_item table-PKE000000031442
             15/02/2013     Kurra VijayaLakshmi    Added code to hanlde model name,lob effected,create date,vendor processor type on mst_item table
             17/02/2013      SUDHEER   KALLURI  ADDED  CHANGES AS A PART OF   131 -A  SPRINT 2
             15/03/2013     sudheer kalluri               added code to  minimize  buffer size  in run time
             05-APR-2013    Keerthisekhar        Added logic to populate new column (ITEM_CONFIG_ID) of SCDH_MASTER.MST_ITEM, for Inventory modelling project
             01-APR-2014    Debashish Sahu Added logic to populate new column (GTC, PC, FGC) of SCDH_MASTER.MST_ITEM, for IUS Project
             21-MAR-2018   Palla Suvarna Latha added column IS_EMC as part of FactoryFlex Project
             10/24/2018   Rekha Added update statement for IS_EMC to retain value of Glovia_CCC sys_source. Search string--<RK001>
             28/08/2019    Rekha    PRB0069275 - Added decode for transaction seq in in_item to pick the seq from 0 when it reaches max.
			 19/11/2020    Turpuseema Sreenivas   ZMOD and DESIGN_TYPE columns are added for the story# 9640764
       *******************************************************************************************************************************/
      L_ERROR_LOCATION          VARCHAR2 (100);
      EXP_MERGE                 EXCEPTION;
      L_IN_ROWS                 INTEGER := 0;
      L_ROW_MERGED              INTEGER := 0;
      L_ERROR_CODE              VARCHAR2 (20) := '0';
      L_ERROR_MSG               VARCHAR2 (1000);
      L_JOB_NAME                VARCHAR2 (200);
      L_LOCATION_ID             VARCHAR2 (1000);
      L_ROW_UPDATED             INTEGER := 0;
      LV_CAN_UPDATE_ENT_STATE   VARCHAR2 (1);
      LV_ENT_STATE              VARCHAR2 (50);
      L_SYS_DATE                TIMESTAMP;
      L_START_TIME              TIMESTAMP;
      L_END_TIME                TIMESTAMP;
      L_SYNC_UP_TIME            TIMESTAMP;
      L_FREQUENCY               NUMBER;
      LV_EXCEPTION              EXCEPTION;
      lv_indx                   NUMBER;
      PRAGMA EXCEPTION_INIT (lv_exception, -24381);
      LV_LIMIT                  NUMBER;


   /*CURSOR C_ITEM_GLOVIA_CCC
      IS SELECT DISTINCT ITEM_ID, IS_EMC FROM
      SCDH_INBOUND.IN_ITEM
      WHERE SYS_SOURCE = 'GLOVIA_CCC'; */

      --Added for CN - 0007
      CURSOR C_ITEM_CUR
      IS
         SELECT DISTINCT
                I.ITEM_ID,
                I.REVISION,
                TRIM (I.COMMODITY_CODE) COMMODITY_CODE,                 --0003
                I.HAZARD,
                I.HPL,
                I.DELETED,
                I.DESCRIPTION,
                TO_TIMESTAMP_TZ (I.EOL_DATE, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                   EOL_DATE,
                I.HEIGHT,
                I.HEIGHT_UM,
                I.LENGTH,
                I.LENGTH_UM,
                I.MAT_SPEC,
                I.MIL_SPEC,
                TO_TIMESTAMP_TZ (I.SETUP_DATE,
                                 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                   SETUP_DATE,
                I.TYPE_,
                I.WEIGHT,
                I.WEIGHT_UM,
                I.WIDTH,
                I.WIDTH_UM,
                I.TEXT_LASTSEQ,
                I.USER_ALPHA1,
                I.USER_ALPHA3,
                TO_TIMESTAMP_TZ (I.USER_DATE,
                                 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                   USER_DATE,
                I.RECORD_ID,
                I.UNID,
                TO_TIMESTAMP_TZ (I.SOURCE_ITEM_MOD_DATE,
                                 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                   SOURCE_ITEM_MOD_DATE,
                I.PART_STATUS,
                I.PRODUCT_CODE,
                I.FLD_SRVC_SPARE_FLAG,
                I.FORECAST_FLAG,
                I.SHIP_TRACKING_CODE,
                I.ALTERNATE_PART_FLAG,
                I.LOCAL_BILL_FLAG,
                I.PRINT_ON_TRAVELER_FLAG,
                I.BOX_CODE,
                I.RELIEF_EXCEPTION_FLAG,
                I.MONITOR_CODE,
                I.ECN,
                TO_TIMESTAMP_TZ (I.SOURCE_C_ITEM_MOD_DATE,
                                 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                   SOURCE_C_ITEM_MOD_DATE,
                I.SOURCE_C_ITEM_MOD_USER,
                I.SYSTEM_FLAG,
                I.UNSPCS,
                I.ITEM_TYPE,
                I.UOM,
                I.ACC_UOM,
                I.CATEGORY,
                I.CURRENCY_ID,
                TO_TIMESTAMP_TZ (I.EFF_END_DATE,
                                 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                   EFF_END_DATE,
                TO_TIMESTAMP_TZ (EFF_START_DATE,
                                 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                   EFF_START_DATE,
                I.IS_VIRTUAL,
                I.ITEM_LEVEL,
                I.LIFE_CYC_STG,
                I.LIST_PRICE,
                I.LOT_SERIAL_MANAGED,
                I.MFGR_ID,
                I.MFR_ITEM_DESC,
                I.MFR_ITEM_ID,
                I.MIN_QTY,
                I.NAME,
                I.ORG_ID,
                I.QUANTITY_MULTIPLE,
                I.STATUS,
                I.SUB_CATEGORY,
                I.UNIT_COST,
                --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                I.COMMODITY_ID,
                I.SYS_SOURCE,
                I.GTC,                        /* Add as part of IUS Program */
                I.PC,
                I.FGC,
                I.SYS_CREATED_BY,
                SYSTIMESTAMP SYS_CREATION_DATE,
                I.SYS_ENT_STATE,
                I.SYS_LAST_MODIFIED_BY,
                SYSTIMESTAMP SYS_LAST_MODIFIED_DATE,
                I.IS_EMC,                                  /*added column as a part of FactoryFlex Project*/
                I.EMC_PART_REF,                               /*Story# 6249610 */
				I.DESIGN_TYPE, -- Added for the story# 9640764
				I.ZMOD --  Added for the story# 9640764
           FROM SCDH_INBOUND.IN_ITEM I
          WHERE     I.SYS_SOURCE = P_SYS_SOURCE
                AND NOT EXISTS
                           (SELECT 1
                              FROM SCDH_MASTER.MST_ITEM M
                             WHERE     M.ITEM_ID = I.ITEM_ID
                                   AND M.REVISION = I.REVISION);

      TYPE L_ITEM_AAT IS TABLE OF C_ITEM_CUR%ROWTYPE
         INDEX BY PLS_INTEGER;

      CURSOR cur_x_bom (
         L_START_TIME   IN TIMESTAMP,
         L_END_TIME     IN TIMESTAMP)
      IS
         (SELECT DISTINCT X1.ITEM ITEM_ID,
                          X1.PART_TYPE PART_TYPE,
                          X1.PART_CLASS PART_CLASS,
                          X1.ITEM_DESCRIPTION DESCRIPTION,
                          X1.TECHNICAL_PROCESS_DESC,                    --0006
                          X1.TECHNICAL_VENDOR,                          --0006
                          X1.ISO_CTRY_CODE, --added as part of upp-mpp project
                          X1.LIFE_CYCLE_STATE,                          --0007
                          X1.LIFE_CYCLE_REV_DATE,                       --0007
                          X1.REASON_FOR_OBSOLETE,                       --0007
                          X1.TECHNICAL_MODEL_NAME,
                          X1.VENDOR_PROCESSOR_TYPE,
                          X1.LOB_AFFECTED,
                          X1.PROCESSOR_PART_CREATE_DATE,
                          X1.ITEM_CONFIG_ID ---Added on 05-APR-2013, by Keerthisekhar for Inventory modelling project
            FROM FDL_SNOP_SCDHUB.X_BOM_ECO_MESSAGES X1
           WHERE SEQ_NUM =
                    (SELECT MAX (X2.SEQ_NUM)
                       FROM FDL_SNOP_SCDHUB.X_BOM_ECO_MESSAGES X2
                      WHERE     X2.ITEM = X1.ITEM
                            AND X2.SYS_CREATION_DATE BETWEEN L_START_TIME
                                                         AND L_END_TIME));

      TYPE type_x_bom IS TABLE OF cur_x_bom%ROWTYPE;

      col_x_bom                 type_x_bom;


      L_ITEM_TAB                L_ITEM_AAT;
      L_INDX                    NUMBER;
      L_ROW_INSERTED            NUMBER := 0;

      L_BULK_ERRORS_EX          EXCEPTION;
      PRAGMA EXCEPTION_INIT (L_BULK_ERRORS_EX, -24381);

      TYPE L_ERR_ITEM_AAT IS TABLE OF SCDH_AUDIT.ERR_ITEM%ROWTYPE
         INDEX BY PLS_INTEGER;

      L_ERR_ITEM_EXCEPTION      L_ERR_ITEM_AAT;

      CURSOR cur_mst_item
      IS
         (SELECT DISTINCT
                 I.ITEM_ID,
                 I.REVISION,
                 TRIM (I.COMMODITY_CODE) COMMODITY_CODE,                --0003
                 I.HAZARD,
                 I.HPL,
                 I.DELETED,
                 I.DESCRIPTION,
                 TO_TIMESTAMP_TZ (I.EOL_DATE,
                                  'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                    EOL_DATE,
                 I.HEIGHT,
                 I.HEIGHT_UM,
                 I.LENGTH,
                 I.LENGTH_UM,
                 I.MAT_SPEC,
                 I.MIL_SPEC,
                 TO_TIMESTAMP_TZ (I.SETUP_DATE,
                                  'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                    SETUP_DATE,
                 I.TYPE_,
                 I.WEIGHT,
                 I.WEIGHT_UM,
                 I.WIDTH,
                 I.WIDTH_UM,
                 I.TEXT_LASTSEQ,
                 I.USER_ALPHA1,
                 I.USER_ALPHA3,
                 TO_TIMESTAMP_TZ (I.USER_DATE,
                                  'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                    USER_DATE,
                 I.RECORD_ID,
                 I.UNID,
                 TO_TIMESTAMP_TZ (I.SOURCE_ITEM_MOD_DATE,
                                  'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                    SOURCE_ITEM_MOD_DATE,
                 I.PART_STATUS,
                 I.PRODUCT_CODE,
                 I.FLD_SRVC_SPARE_FLAG,
                 I.FORECAST_FLAG,
                 I.SHIP_TRACKING_CODE,
                 I.ALTERNATE_PART_FLAG,
                 I.LOCAL_BILL_FLAG,
                 I.PRINT_ON_TRAVELER_FLAG,
                 I.BOX_CODE,
                 I.RELIEF_EXCEPTION_FLAG,
                 I.MONITOR_CODE,
                 I.ECN,
                 TO_TIMESTAMP_TZ (I.SOURCE_C_ITEM_MOD_DATE,
                                  'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                    SOURCE_C_ITEM_MOD_DATE,
                 I.SOURCE_C_ITEM_MOD_USER,
                 I.SYSTEM_FLAG,
                 I.UNSPCS,
                 I.ITEM_TYPE,
                 I.UOM,
                 I.ACC_UOM,
                 I.CATEGORY,
                 I.CURRENCY_ID,
                 TO_TIMESTAMP_TZ (I.EFF_END_DATE,
                                  'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                    EFF_END_DATE,
                 TO_TIMESTAMP_TZ (EFF_START_DATE,
                                  'YYYY-MM-DD HH24:MI:SS TZH:TZM')
                    EFF_START_DATE,
                 I.IS_VIRTUAL,
                 I.ITEM_LEVEL,
                 I.LIFE_CYC_STG,
                 I.LIST_PRICE,
                 I.LOT_SERIAL_MANAGED,
                 I.MFGR_ID,
                 I.MFR_ITEM_DESC,
                 I.MFR_ITEM_ID,
                 I.MIN_QTY,
                 I.NAME,
                 I.ORG_ID,
                 I.QUANTITY_MULTIPLE,
                 I.STATUS,
                 I.SUB_CATEGORY,
                 I.UNIT_COST,
                 --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                 I.COMMODITY_ID,
                 I.SYS_SOURCE,
                 I.GTC,                       /* Add as part of IUS Program */
                 I.PC,
                 I.FGC,
                 I.SYS_CREATED_BY,
                 I.SYS_LAST_MODIFIED_BY,
                 I.PART_TYPE,
                 I.PART_CLASS,
                 I.SYS_ENT_STATE,
                 I.IS_EMC,                                  /*added column as a part of FactoryFlex Project*/
                 I.EMC_PART_REF,
				 I.DESIGN_TYPE, -- Added for the story# 9640764
				I.ZMOD --  Added for the story# 9640764
            FROM SCDH_INBOUND.IN_ITEM I
           WHERE I.SYS_SOURCE = p_sys_source);


      TYPE type_mst_item_cost IS TABLE OF cur_mst_item%ROWTYPE;

      col_mst_item_cost         type_mst_item_cost;
    --Begin <RK001>
      CURSOR C_ITEM_GLOVIA_CCC
      IS SELECT DISTINCT ITEM_ID, IS_EMC,SYS_SOURCE FROM
      SCDH_INBOUND.IN_ITEM
      WHERE SYS_SOURCE = P_SYS_SOURCE;

      TYPE type_item_CCC is TABLE OF C_ITEM_GLOVIA_CCC%ROWTYPE;
       L_ITEM_CCC                  type_item_CCC;
   --End <RK001>
      --Added for CN - 0007
      a                         NUMBER := 0;
   BEGIN
      P_ERROR_CODE := 1;
      L_ERROR_LOCATION := '1.1.0';
      L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;
      LV_LIMIT := GET_TXN_MAX_ROW_LIMIT ('SCDH_MASTER', 'MST_ITEM');

      BEGIN
         SELECT ROUND (SYSTIMESTAMP, 'HH') INTO L_SYS_DATE FROM DUAL;
      EXCEPTION
         WHEN OTHERS
         THEN
            L_ERROR_LOCATION := '1.1.0.0';
            L_ERROR_MSG :=
               SQLERRM || L_SYS_DATE || 'Error Loc: ' || L_ERROR_LOCATION;
            RAISE EXP_MERGE;
      END;

      BEGIN
         SELECT JOB_FREQUENCY_PER_DAY
           INTO L_FREQUENCY
           FROM FDL_SNOP_SCDHUB.PROCESS_JOB
          WHERE JOB_NAME = P_SYNC_UP_ID;
      EXCEPTION
         WHEN OTHERS
         THEN
            L_ERROR_LOCATION := '1.1.0.2';
            L_ERROR_MSG :=
               SQLERRM || L_FREQUENCY || 'Error Loc: ' || L_ERROR_LOCATION;
            RAISE EXP_MERGE;
      END;


      BEGIN
         SELECT PROPVALUE, PROPTYPE
           INTO LV_CAN_UPDATE_ENT_STATE, LV_ENT_STATE
           FROM FDL_SNOP_SCDHUB.MST_SYS_PROPS
          WHERE ID = 'can_update_ent_state' AND SYS_ENT_STATE = 'ACTIVE';
      EXCEPTION
         WHEN OTHERS
         THEN
            L_ERROR_LOCATION := '1.1.0.3';
            L_ERROR_MSG :=
                  SQLERRM
               || LV_CAN_UPDATE_ENT_STATE
               || LV_ENT_STATE
               || 'Error Loc: '
               || L_ERROR_LOCATION;
            RAISE EXP_MERGE;
      END;

      SELECT COUNT (*)
        INTO L_IN_ROWS
        FROM SCDH_INBOUND.IN_ITEM
       WHERE SYS_SOURCE = P_SYS_SOURCE;


      -- Start of Addition -- 0001
      IF P_SYS_SOURCE = p_sys_source
      THEN
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_INSERT_JOB_DETAIL (
            'MERGE',
               'Merge from SCDH_INBOUND.IN_ITEM to SCDH_MASTER.MST_ITEM for '
            || P_SYS_SOURCE,
            L_IN_ROWS,
            0,
            0,
            0,
            'Y',
            0,
            NULL,
            USERENV ('SESSIONID'),
            P_JOB_INSTANCE_ID,
            P_SYNC_UP_ID,
            0,
            'MERGE',
            'MERGE',
            L_ERROR_CODE,
            L_ERROR_MSG);

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG;
            RAISE EXP_MERGE;
         END IF;

         L_ERROR_LOCATION := '1.1.2';
         L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;


         L_ERROR_LOCATION := '1.1.2.0';

         LOOP  --added by utham to handle country code issue --PKE000000031442
            BEGIN
               SELECT NVL (START_TIME, L_SYS_DATE - (1 / L_FREQUENCY)),
                      NVL (END_TIME, L_SYS_DATE),
                      SYNC_UP_DATE
                 INTO L_START_TIME, L_END_TIME, L_SYNC_UP_TIME
                 FROM FDL_SNOP_SCDHUB.AIF_LAST_SYNC_UP
                WHERE SYNC_UP_ID = P_SYNC_UP_ID;
            EXCEPTION
               WHEN OTHERS
               THEN
                  L_ERROR_LOCATION := '1.1.0.1';
                  L_ERROR_MSG :=
                        SQLERRM
                     || L_START_TIME
                     || L_END_TIME
                     || 'Error Loc: '
                     || L_ERROR_LOCATION;
                  RAISE EXP_MERGE;
            END;

            EXIT WHEN (L_END_TIME + (1 / L_FREQUENCY)) >
                         (L_SYNC_UP_TIME - (1 / L_FREQUENCY));

            ------ new change - --------------------------------
            OPEN cur_x_bom (L_START_TIME, L_END_TIME);

            LOOP
               FETCH cur_x_bom
                  BULK COLLECT INTO col_x_bom
                  LIMIT lv_limit;

               EXIT WHEN col_x_bom.COUNT = 0;

               BEGIN
                  FORALL i IN col_x_bom.FIRST .. col_x_bom.LAST
                    SAVE EXCEPTIONS
                     MERGE INTO SCDH_MASTER.MST_ITEM M
                          USING (SELECT col_x_bom (i).ITEM_id ITEM_ID,
                                        col_x_bom (i).PART_TYPE PART_TYPE,
                                        col_x_bom (i).PART_CLASS PART_CLASS,
                                        col_x_bom (i).DESCRIPTION DESCRIPTION,
                                        col_x_bom (i).TECHNICAL_PROCESS_DESC
                                           TECHNICAL_PROCESS_DESC,      --0006
                                        col_x_bom (i).TECHNICAL_VENDOR
                                           TECHNICAL_VENDOR,            --0006
                                        col_x_bom (i).ISO_CTRY_CODE
                                           ISO_CTRY_CODE, --added as part of upp-mpp project
                                        col_x_bom (i).LIFE_CYCLE_STATE
                                           LIFE_CYCLE_STATE,            --0007
                                        col_x_bom (i).LIFE_CYCLE_REV_DATE
                                           LIFE_CYCLE_REV_DATE,         --0007
                                        col_x_bom (i).REASON_FOR_OBSOLETE
                                           REASON_FOR_OBSOLETE,         --0007
                                        col_x_bom (i).TECHNICAL_MODEL_NAME
                                           TECHNICAL_MODEL_NAME,
                                        col_x_bom (i).VENDOR_PROCESSOR_TYPE
                                           VENDOR_PROCESSOR_TYPE,
                                        col_x_bom (i).LOB_AFFECTED
                                           LOB_AFFECTED,
                                        col_x_bom (i).PROCESSOR_PART_CREATE_DATE
                                           PROCESSOR_PART_CREATE_DATE,
                                        col_x_bom (i).ITEM_CONFIG_ID
                                           ITEM_CONFIG_ID ---Added on 05-APR-2013, by Keerthisekhar for Inventory modelling project
                                   FROM DUAL) X
                             ON (M.ITEM_ID = X.ITEM_ID AND M.REVISION = ' ')
                     WHEN MATCHED
                     THEN
                        UPDATE SET
                           M.PART_TYPE = X.PART_TYPE,
                           M.PART_CLASS = X.PART_CLASS,
                           M.DESCRIPTION = X.DESCRIPTION,
                           M.SYS_LAST_MODIFIED_DATE = SYSTIMESTAMP,
                           M.TECHNICAL_PROCESS_DESC = X.TECHNICAL_PROCESS_DESC, --0006
                           M.TECHNICAL_VENDOR = X.TECHNICAL_VENDOR,     --0006
                           M.FGA_ISO_CTRY_CODE = X.ISO_CTRY_CODE, --added as part of upp-mpp project
                           M.LIFE_CYCLE_STATE = X.LIFE_CYCLE_STATE,     --0007
                           M.LIFE_CYCLE_REV_DATE = X.LIFE_CYCLE_REV_DATE, --0007
                           M.REASON_FOR_OBSOLETE = X.REASON_FOR_OBSOLETE, --0007
                           M.TECHNICAL_MODEL_NAME = X.TECHNICAL_MODEL_NAME,
                           M.VENDOR_PROCESSOR_TYPE = X.VENDOR_PROCESSOR_TYPE,
                           M.LOB_AFFECTED = X.LOB_AFFECTED,
                           M.PROCESSOR_PART_CREATE_DATE =
                              X.PROCESSOR_PART_CREATE_DATE,
                           M.ITEM_CONFIG_ID = X.ITEM_CONFIG_ID ---Added on 05-APR-2013, by Keerthisekhar for Inventory modelling project
                     WHEN NOT MATCHED
                     THEN
                        INSERT     (M.ITEM_ID,
                                    M.PART_TYPE,
                                    M.PART_CLASS,
                                    M.DESCRIPTION,
                                    M.REVISION,
                                    M.NAME,
                                    M.ITEM_TYPE,                       -- 0002
                                    M.SYS_CREATED_BY,                  -- 0002
                                    M.SYS_CREATION_DATE,               -- 0002
                                    M.SYS_ENT_STATE,                   -- 0002
                                    M.SYS_LAST_MODIFIED_BY,            -- 0002
                                    M.SYS_LAST_MODIFIED_DATE,
                                    M.TECHNICAL_PROCESS_DESC,           --0006
                                    M.TECHNICAL_VENDOR,                 --0006
                                    M.FGA_ISO_CTRY_CODE, --added as part of upp-mpp project
                                    M.LIFE_CYCLE_STATE,                 --0007
                                    M.LIFE_CYCLE_REV_DATE,              --0007
                                    M.REASON_FOR_OBSOLETE,              --0007
                                    M.TECHNICAL_MODEL_NAME,
                                    M.VENDOR_PROCESSOR_TYPE,
                                    M.LOB_AFFECTED,
                                    M.PROCESSOR_PART_CREATE_DATE,
                                    M.ITEM_CONFIG_ID ---Added on 05-APR-2013, by Keerthisekhar for Inventory modelling project
                                                    )
                            VALUES (X.ITEM_ID,
                                    X.PART_TYPE,
                                    X.PART_CLASS,
                                    X.DESCRIPTION,
                                    ' ',
                                    X.DESCRIPTION,
                                    'PART',                            -- 0002
                                    USER,                              -- 0002
                                    SYSTIMESTAMP,                      -- 0002
                                    'ACTIVE',                          -- 0002
                                    USER,                              -- 0002
                                    SYSTIMESTAMP,
                                    X.TECHNICAL_PROCESS_DESC,           --0006
                                    X.TECHNICAL_VENDOR,                 --0006
                                    X.ISO_CTRY_CODE, --added as part of upp-mpp project
                                    X.LIFE_CYCLE_STATE,                 --0007
                                    X.LIFE_CYCLE_REV_DATE,              --0007
                                    X.REASON_FOR_OBSOLETE,              --0007
                                    X.TECHNICAL_MODEL_NAME,
                                    X.VENDOR_PROCESSOR_TYPE,
                                    X.LOB_AFFECTED,
                                    X.PROCESSOR_PART_CREATE_DATE,
                                    X.ITEM_CONFIG_ID ---Added on 05-APR-2013, by Keerthisekhar for Inventory modelling project
                                                    );

                  COMMIT;
                  col_x_bom.delete;
               EXCEPTION
                  WHEN lv_exception
                  THEN
                     FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                     LOOP
                        lv_indx := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;

                        INSERT
                          INTO SCDH_AUDIT.ERR_ITEM M (
                                  M.ITEM_ID,
                                  M.PART_TYPE,
                                  M.PART_CLASS,
                                  M.DESCRIPTION,
                                  M.REVISION,
                                  M.NAME,
                                  M.ITEM_TYPE,                         -- 0002
                                  M.SYS_CREATED_BY,                    -- 0002
                                  M.SYS_CREATION_DATE,                 -- 0002
                                  M.SYS_ENT_STATE,                     -- 0002
                                  M.SYS_LAST_MODIFIED_BY,              -- 0002
                                  M.SYS_LAST_MODIFIED_DATE,
                                  M.TECHNICAL_PROCESS_DESC,             --0006
                                  M.TECHNICAL_VENDOR,                   --0006
                                  M.FGA_ISO_CTRY_CODE, --added as part of upp-mpp project
                                  M.LIFE_CYCLE_STATE,                   --0007
                                  M.LIFE_CYCLE_REV_DATE,                --0007
                                  M.REASON_FOR_OBSOLETE,                --0007
                                  M.TECHNICAL_MODEL_NAME,
                                  M.VENDOR_PROCESSOR_TYPE,
                                  M.LOB_AFFECTED,
                                  M.PROCESSOR_PART_CREATE_DATE,
                                  M.ITEM_CONFIG_ID  ---Added on 05-APR-2013, by Keerthisekhar for Inventory modelling project
                                             )
                        VALUES (
                                  col_x_bom (lv_indx).ITEM_ID,
                                  col_x_bom (lv_indx).PART_TYPE,
                                  col_x_bom (lv_indx).PART_CLASS,
                                  col_x_bom (lv_indx).DESCRIPTION,
                                  ' ',
                                  col_x_bom (lv_indx).DESCRIPTION,
                                  'PART',                              -- 0002
                                  USER,                                -- 0002
                                  SYSTIMESTAMP,                        -- 0002
                                  'ACTIVE',                            -- 0002
                                  USER,                                -- 0002
                                  SYSTIMESTAMP,
                                  col_x_bom (lv_indx).TECHNICAL_PROCESS_DESC, --0006
                                  col_x_bom (lv_indx).TECHNICAL_VENDOR, --0006
                                  col_x_bom (lv_indx).ISO_CTRY_CODE, --added as part of upp-mpp project
                                  col_x_bom (lv_indx).LIFE_CYCLE_STATE, --0007
                                  col_x_bom (lv_indx).LIFE_CYCLE_REV_DATE, --0007
                                  col_x_bom (lv_indx).REASON_FOR_OBSOLETE, --0007
                                  col_x_bom (lv_indx).TECHNICAL_MODEL_NAME,
                                  col_x_bom (lv_indx).VENDOR_PROCESSOR_TYPE,
                                  col_x_bom (lv_indx).LOB_AFFECTED,
                                  col_x_bom (lv_indx).PROCESSOR_PART_CREATE_DATE,
                                  col_x_bom (lv_indx).ITEM_CONFIG_ID ---Added on 05-APR-2013, by Keerthisekhar for Inventory modelling project
                                                                    );
                     END LOOP;
               END;

               COMMIT;
               col_x_bom.DELETE;
            END LOOP;

            CLOSE cur_x_bom;

            -- End of Addition -- 0001
            --added by utham PKE000000031442
            UPDATE FDL_SNOP_SCDHUB.AIF_LAST_SYNC_UP
               SET START_TIME = NVL (END_TIME, L_END_TIME),
                   END_TIME = NVL (END_TIME, L_END_TIME) + (1 / L_FREQUENCY)
             WHERE SYNC_UP_ID = P_SYNC_UP_ID;
         END LOOP;

         L_ERROR_LOCATION := '1.1.2.1';



         -- Start of Addition -- 0001
         OPEN cur_mst_item;

         LOOP
            FETCH cur_mst_item
               BULK COLLECT INTO col_mst_item_cost
               LIMIT lv_limit;

            EXIT WHEN col_mst_item_cost.COUNT = 0;


            BEGIN
               FORALL i IN COL_MST_ITEM_COST.FIRST .. COL_MST_ITEM_COST.LAST
                 SAVE EXCEPTIONS
                  MERGE INTO SCDH_MASTER.MST_ITEM M
                       USING (SELECT col_mst_item_cost (i).ITEM_ID ITEM_ID,
                                     col_mst_item_cost (i).REVISION REVISION,
                                     col_mst_item_cost (i).COMMODITY_CODE
                                        COMMODITY_CODE,                 --0003
                                     col_mst_item_cost (i).HAZARD HAZARD,
                                     col_mst_item_cost (i).HPL HPL,
                                     col_mst_item_cost (i).DELETED DELETED,
                                     col_mst_item_cost (i).DESCRIPTION
                                        DESCRIPTION,
                                     col_mst_item_cost (i).EOL_DATE EOL_DATE,
                                     col_mst_item_cost (i).HEIGHT HEIGHT,
                                     col_mst_item_cost (i).HEIGHT_UM
                                        HEIGHT_UM,
                                     col_mst_item_cost (i).LENGTH LENGTH,
                                     col_mst_item_cost (i).LENGTH_UM
                                        LENGTH_UM,
                                     col_mst_item_cost (i).MAT_SPEC MAT_SPEC,
                                     col_mst_item_cost (i).MIL_SPEC MIL_SPEC,
                                     col_mst_item_cost (i).SETUP_DATE
                                        SETUP_DATE,
                                     col_mst_item_cost (i).TYPE_ TYPE_,
                                     col_mst_item_cost (i).WEIGHT WEIGHT,
                                     col_mst_item_cost (i).WEIGHT_UM
                                        WEIGHT_UM,
                                     col_mst_item_cost (i).WIDTH WIDTH,
                                     col_mst_item_cost (i).WIDTH_UM WIDTH_UM,
                                     col_mst_item_cost (i).TEXT_LASTSEQ
                                        TEXT_LASTSEQ,
                                     col_mst_item_cost (i).USER_ALPHA1
                                        USER_ALPHA1,
                                     col_mst_item_cost (i).USER_ALPHA3
                                        USER_ALPHA3,
                                     col_mst_item_cost (i).USER_DATE
                                        USER_DATE,
                                     col_mst_item_cost (i).RECORD_ID
                                        RECORD_ID,
                                     col_mst_item_cost (i).UNID UNID,
                                     col_mst_item_cost (i).SOURCE_ITEM_MOD_DATE
                                        SOURCE_ITEM_MOD_DATE,
                                     col_mst_item_cost (i).PART_STATUS
                                        PART_STATUS,
                                     col_mst_item_cost (i).PRODUCT_CODE
                                        PRODUCT_CODE,
                                     col_mst_item_cost (i).FLD_SRVC_SPARE_FLAG
                                        FLD_SRVC_SPARE_FLAG,
                                     col_mst_item_cost (i).FORECAST_FLAG
                                        FORECAST_FLAG,
                                     col_mst_item_cost (i).SHIP_TRACKING_CODE
                                        SHIP_TRACKING_CODE,
                                     col_mst_item_cost (i).ALTERNATE_PART_FLAG
                                        ALTERNATE_PART_FLAG,
                                     col_mst_item_cost (i).LOCAL_BILL_FLAG
                                        LOCAL_BILL_FLAG,
                                     col_mst_item_cost (i).PRINT_ON_TRAVELER_FLAG
                                        PRINT_ON_TRAVELER_FLAG,
                                     col_mst_item_cost (i).BOX_CODE BOX_CODE,
                                     col_mst_item_cost (i).RELIEF_EXCEPTION_FLAG
                                        RELIEF_EXCEPTION_FLAG,
                                     col_mst_item_cost (i).MONITOR_CODE
                                        MONITOR_CODE,
                                     col_mst_item_cost (i).ECN ECN,
                                     col_mst_item_cost (i).SOURCE_C_ITEM_MOD_DATE
                                        SOURCE_C_ITEM_MOD_DATE,
                                     col_mst_item_cost (i).SOURCE_C_ITEM_MOD_USER
                                        SOURCE_C_ITEM_MOD_USER,
                                     col_mst_item_cost (i).SYSTEM_FLAG
                                        SYSTEM_FLAG,
                                     col_mst_item_cost (i).UNSPCS UNSPCS,
                                     col_mst_item_cost (i).ITEM_TYPE
                                        ITEM_TYPE,
                                     col_mst_item_cost (i).UOM UOM,
                                     col_mst_item_cost (i).ACC_UOM ACC_UOM,
                                     col_mst_item_cost (i).CATEGORY CATEGORY,
                                     col_mst_item_cost (i).CURRENCY_ID
                                        CURRENCY_ID,
                                     col_mst_item_cost (i).EFF_END_DATE
                                        EFF_END_DATE,
                                     col_mst_item_cost (i).EFF_START_DATE
                                        EFF_START_DATE,
                                     col_mst_item_cost (i).IS_VIRTUAL
                                        IS_VIRTUAL,
                                     col_mst_item_cost (i).ITEM_LEVEL
                                        ITEM_LEVEL,
                                     col_mst_item_cost (i).LIFE_CYC_STG
                                        LIFE_CYC_STG,
                                     col_mst_item_cost (i).LIST_PRICE
                                        LIST_PRICE,
                                     col_mst_item_cost (i).LOT_SERIAL_MANAGED
                                        LOT_SERIAL_MANAGED,
                                     col_mst_item_cost (i).MFGR_ID MFGR_ID,
                                     col_mst_item_cost (i).MFR_ITEM_DESC
                                        MFR_ITEM_DESC,
                                     col_mst_item_cost (i).MFR_ITEM_ID
                                        MFR_ITEM_ID,
                                     col_mst_item_cost (i).MIN_QTY MIN_QTY,
                                     col_mst_item_cost (i).NAME NAME,
                                     col_mst_item_cost (i).ORG_ID ORG_ID,
                                     col_mst_item_cost (i).QUANTITY_MULTIPLE
                                        QUANTITY_MULTIPLE,
                                     col_mst_item_cost (i).STATUS STATUS,
                                     col_mst_item_cost (i).SUB_CATEGORY
                                        SUB_CATEGORY,
                                     col_mst_item_cost (i).UNIT_COST
                                        UNIT_COST,
                                     --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                                     col_mst_item_cost (i).COMMODITY_ID
                                        COMMODITY_ID,
                                     col_mst_item_cost (i).SYS_SOURCE
                                        SYS_SOURCE,
                                     col_mst_item_cost (i).GTC GTC, /* Add as part of IUS Program */
                                     col_mst_item_cost (i).PC PC,
                                     col_mst_item_cost (i).FGC FGC,
                                     col_mst_item_cost (i).SYS_CREATED_BY
                                        SYS_CREATED_BY,
                                     col_mst_item_cost (i).SYS_LAST_MODIFIED_BY
                                        SYS_LAST_MODIFIED_BY,
                                     col_mst_item_cost (i).PART_TYPE
                                        PART_TYPE,
                                     col_mst_item_cost (i).PART_CLASS
                                        PART_CLASS,
                                     col_mst_item_cost (i).SYS_ENT_STATE
                                        SYS_ENT_STATE,
                                     col_mst_item_cost (i).IS_EMC  IS_EMC,                  /*added column as a part of FactoryFlex Project*/
                                     col_mst_item_cost (i).EMC_PART_REF EMC_PART_REF,
									 col_mst_item_cost (i).DESIGN_TYPE DESIGN_TYPE, -- Added for the story# 9640764
				                     col_mst_item_cost (i).ZMOD ZMOD --  Added for the story# 9640764
                                FROM DUAL) I
                          ON (    M.ITEM_ID = I.ITEM_ID
                              AND M.REVISION = I.REVISION)
                  WHEN MATCHED
                  THEN
                     UPDATE SET
                        M.COMMODITY_CODE = I.COMMODITY_CODE,
                        M.HAZARD = I.HAZARD,
                        M.HPL = I.HPL,
                        M.DELETED = I.DELETED,
                        M.EOL_DATE = I.EOL_DATE,
                        M.HEIGHT = I.HEIGHT,
                        M.HEIGHT_UM = I.HEIGHT_UM,
                        M.LENGTH = I.LENGTH,
                        M.LENGTH_UM = I.LENGTH_UM,
                        M.MAT_SPEC = I.MAT_SPEC,
                        M.MIL_SPEC = I.MIL_SPEC,
                        M.SETUP_DATE = I.SETUP_DATE,
                        M.TYPE_ = I.TYPE_,
                        M.WEIGHT = I.WEIGHT,
                        M.WEIGHT_UM = I.WEIGHT_UM,
                        M.WIDTH = I.WIDTH,
                        M.WIDTH_UM = I.WIDTH_UM,
                        M.TEXT_LASTSEQ = I.TEXT_LASTSEQ,
                        M.USER_ALPHA1 = I.USER_ALPHA1,
                        M.USER_ALPHA3 = I.USER_ALPHA3,
                        M.USER_DATE = I.USER_DATE,
                        M.RECORD_ID = I.RECORD_ID,
                        M.UNID = I.UNID,
                        M.SOURCE_ITEM_MOD_DATE = I.SOURCE_ITEM_MOD_DATE,
                        M.PART_STATUS = I.PART_STATUS,
                        M.PRODUCT_CODE = I.PRODUCT_CODE,
                        M.FLD_SRVC_SPARE_FLAG = I.FLD_SRVC_SPARE_FLAG,
                        M.FORECAST_FLAG = I.FORECAST_FLAG,
                        M.SHIP_TRACKING_CODE = I.SHIP_TRACKING_CODE,
                        M.ALTERNATE_PART_FLAG = I.ALTERNATE_PART_FLAG,
                        M.LOCAL_BILL_FLAG = I.LOCAL_BILL_FLAG,
                        M.PRINT_ON_TRAVELER_FLAG = I.PRINT_ON_TRAVELER_FLAG,
                        M.BOX_CODE = I.BOX_CODE,
                        M.RELIEF_EXCEPTION_FLAG = I.RELIEF_EXCEPTION_FLAG,
                        M.MONITOR_CODE = I.MONITOR_CODE,
                        M.ECN = I.ECN,
                        M.SOURCE_C_ITEM_MOD_DATE = I.SOURCE_C_ITEM_MOD_DATE,
                        M.SOURCE_C_ITEM_MOD_USER = I.SOURCE_C_ITEM_MOD_USER,
                        M.SYSTEM_FLAG = I.SYSTEM_FLAG,
                        M.UNSPCS = I.UNSPCS,
                        M.ITEM_TYPE = I.ITEM_TYPE,
                        M.UOM = I.UOM,
                        M.ACC_UOM = I.ACC_UOM,
                        M.CATEGORY = I.CATEGORY,
                        M.CURRENCY_ID = I.CURRENCY_ID,
                        M.EFF_END_DATE = I.EFF_END_DATE,
                        M.EFF_START_DATE = I.EFF_START_DATE,
                        M.IS_VIRTUAL = I.IS_VIRTUAL,
                        M.ITEM_LEVEL = I.ITEM_LEVEL,
                        M.LIFE_CYC_STG = I.LIFE_CYC_STG,
                        M.LIST_PRICE = I.LIST_PRICE,
                        M.LOT_SERIAL_MANAGED = I.LOT_SERIAL_MANAGED,
                        M.MFGR_ID = I.MFGR_ID,
                        M.MFR_ITEM_DESC = I.MFR_ITEM_DESC,
                        M.MFR_ITEM_ID = I.MFR_ITEM_ID,
                        M.MIN_QTY = I.MIN_QTY,
                        M.NAME = I.NAME,
                        M.ORG_ID = I.ORG_ID,
                        M.QUANTITY_MULTIPLE = I.QUANTITY_MULTIPLE,
                        M.STATUS = I.STATUS,
                        M.SUB_CATEGORY = I.SUB_CATEGORY,
                        M.UNIT_COST = I.UNIT_COST,
                        --m.ITEM_CLASS=i.ITEM_CLASS,  -- Commented for L10 mod GMP
                        M.SYS_SOURCE = I.SYS_SOURCE,
                        M.GTC = I.GTC,        /* Add as part of IUS Program */
                        M.PC = I.PC,
                        M.FGC = I.FGC,
                        -- m.SYS_CREATED_BY=i.SYS_CREATED_BY, -- 0002
                        M.SYS_ENT_STATE = I.SYS_ENT_STATE,
                        M.SYS_LAST_MODIFIED_BY = I.SYS_LAST_MODIFIED_BY,
                        M.SYS_LAST_MODIFIED_DATE = SYSTIMESTAMP,
                        M.IS_EMC = I.IS_EMC, /*added column as a part of FactoryFlex Project*/
                        M.EMC_PART_REF = I.EMC_PART_REF,
						M.DESIGN_TYPE = I.DESIGN_TYPE, -- Added for the story# 9640764
				        M.ZMOD = I.ZMOD --  Added for the story# 9640764
                  WHEN NOT MATCHED
                  THEN
                     INSERT     (M.ITEM_ID,
                                 M.REVISION,
                                 M.COMMODITY_CODE,
                                 M.HAZARD,
                                 M.HPL,
                                 M.DELETED,
                                 M.DESCRIPTION,
                                 M.EOL_DATE,
                                 M.HEIGHT,
                                 M.HEIGHT_UM,
                                 M.LENGTH,
                                 M.LENGTH_UM,
                                 M.MAT_SPEC,
                                 M.MIL_SPEC,
                                 M.SETUP_DATE,
                                 M.TYPE_,
                                 M.WEIGHT,
                                 M.WEIGHT_UM,
                                 M.WIDTH,
                                 M.WIDTH_UM,
                                 M.TEXT_LASTSEQ,
                                 M.USER_ALPHA1,
                                 M.USER_ALPHA3,
                                 M.USER_DATE,
                                 M.RECORD_ID,
                                 M.UNID,
                                 M.SOURCE_ITEM_MOD_DATE,
                                 M.PART_STATUS,
                                 M.PRODUCT_CODE,
                                 M.FLD_SRVC_SPARE_FLAG,
                                 M.FORECAST_FLAG,
                                 M.SHIP_TRACKING_CODE,
                                 M.ALTERNATE_PART_FLAG,
                                 M.LOCAL_BILL_FLAG,
                                 M.PRINT_ON_TRAVELER_FLAG,
                                 M.BOX_CODE,
                                 M.RELIEF_EXCEPTION_FLAG,
                                 M.MONITOR_CODE,
                                 M.ECN,
                                 M.SOURCE_C_ITEM_MOD_DATE,
                                 M.SOURCE_C_ITEM_MOD_USER,
                                 M.SYSTEM_FLAG,
                                 M.UNSPCS,
                                 M.ITEM_TYPE,
                                 M.UOM,
                                 M.ACC_UOM,
                                 M.CATEGORY,
                                 M.CURRENCY_ID,
                                 M.EFF_END_DATE,
                                 M.EFF_START_DATE,
                                 M.IS_VIRTUAL,
                                 M.ITEM_LEVEL,
                                 M.LIFE_CYC_STG,
                                 M.LIST_PRICE,
                                 M.LOT_SERIAL_MANAGED,
                                 M.MFGR_ID,
                                 M.MFR_ITEM_DESC,
                                 M.MFR_ITEM_ID,
                                 M.MIN_QTY,
                                 M.NAME,
                                 M.ORG_ID,
                                 M.QUANTITY_MULTIPLE,
                                 M.STATUS,
                                 M.SUB_CATEGORY,
                                 M.UNIT_COST,
                                 --m.ITEM_CLASS,  -- Commented for L10 mod GMP
                                 M.COMMODITY_ID,
                                 M.SYS_SOURCE,
                                 M.GTC,       /* Add as part of IUS Program */
                                 M.PC,
                                 M.FGC,
                                 M.SYS_CREATED_BY,
                                 M.SYS_CREATION_DATE,
                                 M.SYS_ENT_STATE,
                                 M.SYS_LAST_MODIFIED_BY,
                                 M.SYS_LAST_MODIFIED_DATE,
                                 M.PART_TYPE,
                                 M.PART_CLASS,
                                 M.IS_EMC,
                                 M.EMC_PART_REF,
								 M.DESIGN_TYPE, -- Added for the story# 9640764
				                 M.ZMOD  --  Added for the story# 9640764
								 )
                         VALUES (I.ITEM_ID,
                                 I.REVISION,
                                 I.COMMODITY_CODE,
                                 I.HAZARD,
                                 I.HPL,
                                 I.DELETED,
                                 I.DESCRIPTION,
                                 I.EOL_DATE,
                                 I.HEIGHT,
                                 I.HEIGHT_UM,
                                 I.LENGTH,
                                 I.LENGTH_UM,
                                 I.MAT_SPEC,
                                 I.MIL_SPEC,
                                 I.SETUP_DATE,
                                 I.TYPE_,
                                 I.WEIGHT,
                                 I.WEIGHT_UM,
                                 I.WIDTH,
                                 I.WIDTH_UM,
                                 I.TEXT_LASTSEQ,
                                 I.USER_ALPHA1,
                                 I.USER_ALPHA3,
                                 I.USER_DATE,
                                 I.RECORD_ID,
                                 I.UNID,
                                 I.SOURCE_ITEM_MOD_DATE,
                                 I.PART_STATUS,
                                 I.PRODUCT_CODE,
                                 I.FLD_SRVC_SPARE_FLAG,
                                 I.FORECAST_FLAG,
                                 I.SHIP_TRACKING_CODE,
                                 I.ALTERNATE_PART_FLAG,
                                 I.LOCAL_BILL_FLAG,
                                 I.PRINT_ON_TRAVELER_FLAG,
                                 I.BOX_CODE,
                                 I.RELIEF_EXCEPTION_FLAG,
                                 I.MONITOR_CODE,
                                 I.ECN,
                                 I.SOURCE_C_ITEM_MOD_DATE,
                                 I.SOURCE_C_ITEM_MOD_USER,
                                 I.SYSTEM_FLAG,
                                 I.UNSPCS,
                                 I.ITEM_TYPE,
                                 I.UOM,
                                 I.ACC_UOM,
                                 I.CATEGORY,
                                 I.CURRENCY_ID,
                                 I.EFF_END_DATE,
                                 I.EFF_START_DATE,
                                 I.IS_VIRTUAL,
                                 I.ITEM_LEVEL,
                                 I.LIFE_CYC_STG,
                                 I.LIST_PRICE,
                                 I.LOT_SERIAL_MANAGED,
                                 I.MFGR_ID,
                                 I.MFR_ITEM_DESC,
                                 I.MFR_ITEM_ID,
                                 I.MIN_QTY,
                                 I.NAME,
                                 I.ORG_ID,
                                 I.QUANTITY_MULTIPLE,
                                 I.STATUS,
                                 I.SUB_CATEGORY,
                                 I.UNIT_COST,
                                 --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                                 I.COMMODITY_ID,
                                 I.SYS_SOURCE,
                                 I.GTC,       /* Add as part of IUS Program */
                                 I.PC,
                                 I.FGC,
                                 I.SYS_CREATED_BY,
                                 SYSTIMESTAMP,
                                 I.SYS_ENT_STATE,
                                 I.SYS_LAST_MODIFIED_BY,
                                 SYSTIMESTAMP,
                                 I.PART_TYPE,
                                 I.PART_CLASS,
                                 I.IS_EMC, /*added column as a part of FactoryFlex Project*/
                                 I.EMC_PART_REF,
								 I.DESIGN_TYPE, -- Added for the story# 9640764
				                 I.ZMOD --  Added for the story# 9640764
								 );

               L_ROW_MERGED := L_ROW_MERGED + SQL%ROWCOUNT;
            EXCEPTION
               WHEN lv_exception
               THEN
                  FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                  LOOP
                     lv_indx := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;

                     INSERT
                       INTO SCDH_AUDIT.ERR_ITEM M (M.ITEM_ID,
                                                   M.REVISION,
                                                   M.COMMODITY_CODE,
                                                   M.HAZARD,
                                                   M.HPL,
                                                   M.DELETED,
                                                   M.DESCRIPTION,
                                                   M.EOL_DATE,
                                                   M.HEIGHT,
                                                   M.HEIGHT_UM,
                                                   M.LENGTH,
                                                   M.LENGTH_UM,
                                                   M.MAT_SPEC,
                                                   M.MIL_SPEC,
                                                   M.SETUP_DATE,
                                                   M.TYPE_,
                                                   M.WEIGHT,
                                                   M.WEIGHT_UM,
                                                   M.WIDTH,
                                                   M.WIDTH_UM,
                                                   M.TEXT_LASTSEQ,
                                                   M.USER_ALPHA1,
                                                   M.USER_ALPHA3,
                                                   M.USER_DATE,
                                                   M.RECORD_ID,
                                                   M.UNID,
                                                   M.SOURCE_ITEM_MOD_DATE,
                                                   M.PART_STATUS,
                                                   M.PRODUCT_CODE,
                                                   M.FLD_SRVC_SPARE_FLAG,
                                                   M.FORECAST_FLAG,
                                                   M.SHIP_TRACKING_CODE,
                                                   M.ALTERNATE_PART_FLAG,
                                                   M.LOCAL_BILL_FLAG,
                                                   M.PRINT_ON_TRAVELER_FLAG,
                                                   M.BOX_CODE,
                                                   M.RELIEF_EXCEPTION_FLAG,
                                                   M.MONITOR_CODE,
                                                   M.ECN,
                                                   M.SOURCE_C_ITEM_MOD_DATE,
                                                   M.SOURCE_C_ITEM_MOD_USER,
                                                   M.SYSTEM_FLAG,
                                                   M.UNSPCS,
                                                   M.ITEM_TYPE,
                                                   M.UOM,
                                                   M.ACC_UOM,
                                                   M.CATEGORY,
                                                   M.CURRENCY_ID,
                                                   M.EFF_END_DATE,
                                                   M.EFF_START_DATE,
                                                   M.IS_VIRTUAL,
                                                   M.ITEM_LEVEL,
                                                   M.LIFE_CYC_STG,
                                                   M.LIST_PRICE,
                                                   M.LOT_SERIAL_MANAGED,
                                                   M.MFGR_ID,
                                                   M.MFR_ITEM_DESC,
                                                   M.MFR_ITEM_ID,
                                                   M.MIN_QTY,
                                                   M.NAME,
                                                   M.ORG_ID,
                                                   M.QUANTITY_MULTIPLE,
                                                   M.STATUS,
                                                   M.SUB_CATEGORY,
                                                   M.UNIT_COST,
                                                   --m.ITEM_CLASS,  -- Commented for L10 mod GMP
                                                   M.COMMODITY_ID,
                                                   M.SYS_SOURCE,
                                                   M.GTC, /* Add as part of IUS Program */
                                                   M.PC,
                                                   M.FGC,
                                                   --  M.SYS_CREATED_BY,
                                                   M.SYS_CREATION_DATE,
                                                   M.SYS_ENT_STATE,
                                                   -- M.SYS_LAST_MODIFIED_BY,
                                                   M.SYS_LAST_MODIFIED_DATE,
                                                   M.PART_TYPE,
                                                   M.PART_CLASS,
                                                   M.IS_EMC, /*added column as a part of FactoryFlex Project*/
                                                   M.EMC_PART_REF,
												   M.DESIGN_TYPE, -- Added for the story# 9640764
				                                   M.ZMOD --  Added for the story# 9640764
												   )
                     VALUES (
                               col_mst_item_cost (lv_indx).ITEM_ID,
                               col_mst_item_cost (lv_indx).REVISION,
                               col_mst_item_cost (lv_indx).COMMODITY_CODE,
                               col_mst_item_cost (lv_indx).HAZARD,
                               col_mst_item_cost (lv_indx).HPL,
                               col_mst_item_cost (lv_indx).DELETED,
                               col_mst_item_cost (lv_indx).DESCRIPTION,
                               col_mst_item_cost (lv_indx).EOL_DATE,
                               col_mst_item_cost (lv_indx).HEIGHT,
                               col_mst_item_cost (lv_indx).HEIGHT_UM,
                               col_mst_item_cost (lv_indx).LENGTH,
                               col_mst_item_cost (lv_indx).LENGTH_UM,
                               col_mst_item_cost (lv_indx).MAT_SPEC,
                               col_mst_item_cost (lv_indx).MIL_SPEC,
                               col_mst_item_cost (lv_indx).SETUP_DATE,
                               col_mst_item_cost (lv_indx).TYPE_,
                               col_mst_item_cost (lv_indx).WEIGHT,
                               col_mst_item_cost (lv_indx).WEIGHT_UM,
                               col_mst_item_cost (lv_indx).WIDTH,
                               col_mst_item_cost (lv_indx).WIDTH_UM,
                               col_mst_item_cost (lv_indx).TEXT_LASTSEQ,
                               col_mst_item_cost (lv_indx).USER_ALPHA1,
                               col_mst_item_cost (lv_indx).USER_ALPHA3,
                               col_mst_item_cost (lv_indx).USER_DATE,
                               col_mst_item_cost (lv_indx).RECORD_ID,
                               col_mst_item_cost (lv_indx).UNID,
                               col_mst_item_cost (lv_indx).SOURCE_ITEM_MOD_DATE,
                               col_mst_item_cost (lv_indx).PART_STATUS,
                               col_mst_item_cost (lv_indx).PRODUCT_CODE,
                               col_mst_item_cost (lv_indx).FLD_SRVC_SPARE_FLAG,
                               col_mst_item_cost (lv_indx).FORECAST_FLAG,
                               col_mst_item_cost (lv_indx).SHIP_TRACKING_CODE,
                               col_mst_item_cost (lv_indx).ALTERNATE_PART_FLAG,
                               col_mst_item_cost (lv_indx).LOCAL_BILL_FLAG,
                               col_mst_item_cost (lv_indx).PRINT_ON_TRAVELER_FLAG,
                               col_mst_item_cost (lv_indx).BOX_CODE,
                               col_mst_item_cost (lv_indx).RELIEF_EXCEPTION_FLAG,
                               col_mst_item_cost (lv_indx).MONITOR_CODE,
                               col_mst_item_cost (lv_indx).ECN,
                               col_mst_item_cost (lv_indx).SOURCE_C_ITEM_MOD_DATE,
                               col_mst_item_cost (lv_indx).SOURCE_C_ITEM_MOD_USER,
                               col_mst_item_cost (lv_indx).SYSTEM_FLAG,
                               col_mst_item_cost (lv_indx).UNSPCS,
                               col_mst_item_cost (lv_indx).ITEM_TYPE,
                               col_mst_item_cost (lv_indx).UOM,
                               col_mst_item_cost (lv_indx).ACC_UOM,
                               col_mst_item_cost (lv_indx).CATEGORY,
                               col_mst_item_cost (lv_indx).CURRENCY_ID,
                               col_mst_item_cost (lv_indx).EFF_END_DATE,
                               col_mst_item_cost (lv_indx).EFF_START_DATE,
                               col_mst_item_cost (lv_indx).IS_VIRTUAL,
                               col_mst_item_cost (lv_indx).ITEM_LEVEL,
                               col_mst_item_cost (lv_indx).LIFE_CYC_STG,
                               col_mst_item_cost (lv_indx).LIST_PRICE,
                               col_mst_item_cost (lv_indx).LOT_SERIAL_MANAGED,
                               col_mst_item_cost (lv_indx).MFGR_ID,
                               col_mst_item_cost (lv_indx).MFR_ITEM_DESC,
                               col_mst_item_cost (lv_indx).MFR_ITEM_ID,
                               col_mst_item_cost (lv_indx).MIN_QTY,
                               col_mst_item_cost (lv_indx).NAME,
                               col_mst_item_cost (lv_indx).ORG_ID,
                               col_mst_item_cost (lv_indx).QUANTITY_MULTIPLE,
                               col_mst_item_cost (lv_indx).STATUS,
                               col_mst_item_cost (lv_indx).SUB_CATEGORY,
                               col_mst_item_cost (lv_indx).UNIT_COST,
                               --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                               col_mst_item_cost (lv_indx).COMMODITY_ID,
                               col_mst_item_cost (lv_indx).SYS_SOURCE,
                               col_mst_item_cost (lv_indx).GTC, /* Add as part of IUS Program */
                               col_mst_item_cost (lv_indx).PC,
                               col_mst_item_cost (lv_indx).FGC,
                               --  col_mst_item_cost(lv_indx).SYS_CREATED_BY,
                               SYSTIMESTAMP,
                               col_mst_item_cost (lv_indx).SYS_ENT_STATE,
                               -- col_mst_item_cost(lv_indx).SYS_LAST_MODIFIED_BY,
                               SYSTIMESTAMP,
                               col_mst_item_cost (lv_indx).PART_TYPE,
                               col_mst_item_cost (lv_indx).PART_CLASS,
                               col_mst_item_cost (lv_indx).IS_EMC, /*added column as a part of FactoryFlex Project*/
                               col_mst_item_cost (lv_indx).EMC_PART_REF,
							   col_mst_item_cost (lv_indx).DESIGN_TYPE, -- Added for the story# 9640764
				               col_mst_item_cost (lv_indx).ZMOD --  Added for the story# 9640764
							   );
                  END LOOP;

                  COMMIT;
            END;

            col_mst_item_cost.delete;
         END LOOP;

         CLOSE cur_mst_item;



         L_ERROR_LOCATION := '1.1.2.2';
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_UPDATE_JOB_DETAIL (
            L_IN_ROWS,
            L_ROW_MERGED,
            L_ROW_MERGED,
            0,
            0,
            'MERGE SUCCEEDED',
            FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.GV_JOB_DETAIL_SEQNO,
            L_ERROR_CODE,
            L_ERROR_MSG);
         L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG;

            RAISE EXP_MERGE;
         END IF;
      ELSIF P_SYS_SOURCE = 'COST_ITEM'
      THEN
         L_ERROR_LOCATION := '1.1.2.3';

         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_INSERT_JOB_DETAIL (
            'MERGE',
               'Merge from SCDH_INBOUND.IN_ITEM to SCDH_MASTER.MST_ITEM for '
            || P_SYS_SOURCE,
            L_IN_ROWS,
            0,
            0,
            0,
            'Y',
            0,
            NULL,
            USERENV ('SESSIONID'),
            P_JOB_INSTANCE_ID,
            P_SYNC_UP_ID,
            0,
            'MERGE',
            'MERGE',
            L_ERROR_CODE,
            L_ERROR_MSG);

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG;
            RAISE EXP_MERGE;
         END IF;

         L_ERROR_LOCATION := '1.1.2.3.0';
         L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;


         OPEN cur_mst_item;

         LOOP
            FETCH cur_mst_item
               BULK COLLECT INTO col_mst_item_cost
               LIMIT lv_limit;

            EXIT WHEN col_mst_item_cost.COUNT = 0;


            BEGIN
               FORALL i IN col_mst_item_cost.FIRST .. col_mst_item_cost.LAST
                 SAVE EXCEPTIONS
                  MERGE INTO SCDH_MASTER.MST_ITEM M
                       USING (SELECT col_mst_item_cost (i).ITEM_ID ITEM_ID,
                                     col_mst_item_cost (i).REVISION REVISION,
                                     col_mst_item_cost (i).COMMODITY_CODE
                                        COMMODITY_CODE,                 --0003
                                     col_mst_item_cost (i).HAZARD HAZARD,
                                     col_mst_item_cost (i).HPL HPL,
                                     col_mst_item_cost (i).DELETED DELETED,
                                     col_mst_item_cost (i).DESCRIPTION
                                        DESCRIPTION,
                                     col_mst_item_cost (i).EOL_DATE EOL_DATE,
                                     col_mst_item_cost (i).HEIGHT HEIGHT,
                                     col_mst_item_cost (i).HEIGHT_UM
                                        HEIGHT_UM,
                                     col_mst_item_cost (i).LENGTH LENGTH,
                                     col_mst_item_cost (i).LENGTH_UM
                                        LENGTH_UM,
                                     col_mst_item_cost (i).MAT_SPEC MAT_SPEC,
                                     col_mst_item_cost (i).MIL_SPEC MIL_SPEC,
                                     col_mst_item_cost (i).SETUP_DATE
                                        SETUP_DATE,
                                     col_mst_item_cost (i).TYPE_ TYPE_,
                                     col_mst_item_cost (i).WEIGHT WEIGHT,
                                     col_mst_item_cost (i).WEIGHT_UM
                                        WEIGHT_UM,
                                     col_mst_item_cost (i).WIDTH WIDTH,
                                     col_mst_item_cost (i).WIDTH_UM WIDTH_UM,
                                     col_mst_item_cost (i).TEXT_LASTSEQ
                                        TEXT_LASTSEQ,
                                     col_mst_item_cost (i).USER_ALPHA1
                                        USER_ALPHA1,
                                     col_mst_item_cost (i).USER_ALPHA3
                                        USER_ALPHA3,
                                     col_mst_item_cost (i).USER_DATE
                                        USER_DATE,
                                     col_mst_item_cost (i).RECORD_ID
                                        RECORD_ID,
                                     col_mst_item_cost (i).UNID UNID,
                                     col_mst_item_cost (i).SOURCE_ITEM_MOD_DATE
                                        SOURCE_ITEM_MOD_DATE,
                                     col_mst_item_cost (i).PART_STATUS
                                        PART_STATUS,
                                     col_mst_item_cost (i).PRODUCT_CODE
                                        PRODUCT_CODE,
                                     col_mst_item_cost (i).FLD_SRVC_SPARE_FLAG
                                        FLD_SRVC_SPARE_FLAG,
                                     col_mst_item_cost (i).FORECAST_FLAG
                                        FORECAST_FLAG,
                                     col_mst_item_cost (i).SHIP_TRACKING_CODE
                                        SHIP_TRACKING_CODE,
                                     col_mst_item_cost (i).ALTERNATE_PART_FLAG
                                        ALTERNATE_PART_FLAG,
                                     col_mst_item_cost (i).LOCAL_BILL_FLAG
                                        LOCAL_BILL_FLAG,
                                     col_mst_item_cost (i).PRINT_ON_TRAVELER_FLAG
                                        PRINT_ON_TRAVELER_FLAG,
                                     col_mst_item_cost (i).BOX_CODE BOX_CODE,
                                     col_mst_item_cost (i).RELIEF_EXCEPTION_FLAG
                                        RELIEF_EXCEPTION_FLAG,
                                     col_mst_item_cost (i).MONITOR_CODE
                                        MONITOR_CODE,
                                     col_mst_item_cost (i).ECN ECN,
                                     col_mst_item_cost (i).SOURCE_C_ITEM_MOD_DATE
                                        SOURCE_C_ITEM_MOD_DATE,
                                     col_mst_item_cost (i).SOURCE_C_ITEM_MOD_USER
                                        SOURCE_C_ITEM_MOD_USER,
                                     col_mst_item_cost (i).SYSTEM_FLAG
                                        SYSTEM_FLAG,
                                     col_mst_item_cost (i).UNSPCS UNSPCS,
                                     col_mst_item_cost (i).ITEM_TYPE
                                        ITEM_TYPE,
                                     col_mst_item_cost (i).UOM UOM,
                                     col_mst_item_cost (i).ACC_UOM ACC_UOM,
                                     col_mst_item_cost (i).CATEGORY CATEGORY,
                                     col_mst_item_cost (i).CURRENCY_ID
                                        CURRENCY_ID,
                                     col_mst_item_cost (i).EFF_END_DATE
                                        EFF_END_DATE,
                                     col_mst_item_cost (i).EFF_START_DATE
                                        EFF_START_DATE,
                                     col_mst_item_cost (i).IS_VIRTUAL
                                        IS_VIRTUAL,
                                     col_mst_item_cost (i).ITEM_LEVEL
                                        ITEM_LEVEL,
                                     col_mst_item_cost (i).LIFE_CYC_STG
                                        LIFE_CYC_STG,
                                     col_mst_item_cost (i).LIST_PRICE
                                        LIST_PRICE,
                                     col_mst_item_cost (i).LOT_SERIAL_MANAGED
                                        LOT_SERIAL_MANAGED,
                                     col_mst_item_cost (i).MFGR_ID MFGR_ID,
                                     col_mst_item_cost (i).MFR_ITEM_DESC
                                        MFR_ITEM_DESC,
                                     col_mst_item_cost (i).MFR_ITEM_ID
                                        MFR_ITEM_ID,
                                     col_mst_item_cost (i).MIN_QTY MIN_QTY,
                                     col_mst_item_cost (i).NAME NAME,
                                     col_mst_item_cost (i).ORG_ID ORG_ID,
                                     col_mst_item_cost (i).QUANTITY_MULTIPLE
                                        QUANTITY_MULTIPLE,
                                     col_mst_item_cost (i).STATUS STATUS,
                                     col_mst_item_cost (i).SUB_CATEGORY
                                        SUB_CATEGORY,
                                     col_mst_item_cost (i).UNIT_COST
                                        UNIT_COST,
                                     --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                                     col_mst_item_cost (i).COMMODITY_ID
                                        COMMODITY_ID,
                                     col_mst_item_cost (i).SYS_SOURCE
                                        SYS_SOURCE,
                                     col_mst_item_cost (i).GTC GTC, /* Add as part of IUS Program */
                                     col_mst_item_cost (i).PC PC,
                                     col_mst_item_cost (i).FGC FGC,
                                     col_mst_item_cost (i).SYS_CREATED_BY
                                        SYS_CREATED_BY,
                                     col_mst_item_cost (i).SYS_LAST_MODIFIED_BY
                                        SYS_LAST_MODIFIED_BY,
                                     -- col_mst_item_cost(i).PART_TYPE PART_TYPE,
                                     --   col_mst_item_cost(i).PART_CLASS PART_CLASS,
                                     col_mst_item_cost (i).SYS_ENT_STATE
                                        SYS_ENT_STATE,
                                      col_mst_item_cost (i).IS_EMC   IS_EMC,   /*added column as a part of FactoryFlex Project*/
                                      col_mst_item_cost (i).EMC_PART_REF EMC_PART_REF,
									  col_mst_item_cost (i).DESIGN_TYPE DESIGN_TYPE, -- Added for the story# 9640764
				                      col_mst_item_cost (i).ZMOD ZMOD--  Added for the story# 9640764
                                FROM DUAL) I
                          ON (    M.ITEM_ID = I.ITEM_ID
                              AND M.REVISION = I.REVISION)
                  WHEN MATCHED
                  THEN
                     UPDATE SET
                        M.COMMODITY_CODE = I.COMMODITY_CODE,
                        M.HAZARD = I.HAZARD,
                        M.HPL = I.HPL,
                        M.DELETED = I.DELETED,
                        M.DESCRIPTION = I.DESCRIPTION,
                        M.EOL_DATE = I.EOL_DATE,
                        M.HEIGHT = I.HEIGHT,
                        M.HEIGHT_UM = I.HEIGHT_UM,
                        M.LENGTH = I.LENGTH,
                        M.LENGTH_UM = I.LENGTH_UM,
                        M.MAT_SPEC = I.MAT_SPEC,
                        M.MIL_SPEC = I.MIL_SPEC,
                        M.SETUP_DATE = I.SETUP_DATE,
                        M.TYPE_ = I.TYPE_,
                        M.WEIGHT = I.WEIGHT,
                        M.WEIGHT_UM = I.WEIGHT_UM,
                        M.WIDTH = I.WIDTH,
                        M.WIDTH_UM = I.WIDTH_UM,
                        M.TEXT_LASTSEQ = I.TEXT_LASTSEQ,
                        M.USER_ALPHA1 = I.USER_ALPHA1,
                        M.USER_ALPHA3 = I.USER_ALPHA3,
                        M.USER_DATE = I.USER_DATE,
                        M.RECORD_ID = I.RECORD_ID,
                        M.UNID = I.UNID,
                        M.SOURCE_ITEM_MOD_DATE = I.SOURCE_ITEM_MOD_DATE,
                        M.PART_STATUS = I.PART_STATUS,
                        M.PRODUCT_CODE = I.PRODUCT_CODE,
                        M.FLD_SRVC_SPARE_FLAG = I.FLD_SRVC_SPARE_FLAG,
                        M.FORECAST_FLAG = I.FORECAST_FLAG,
                        M.SHIP_TRACKING_CODE = I.SHIP_TRACKING_CODE,
                        M.ALTERNATE_PART_FLAG = I.ALTERNATE_PART_FLAG,
                        M.LOCAL_BILL_FLAG = I.LOCAL_BILL_FLAG,
                        M.PRINT_ON_TRAVELER_FLAG = I.PRINT_ON_TRAVELER_FLAG,
                        M.BOX_CODE = I.BOX_CODE,
                        M.RELIEF_EXCEPTION_FLAG = I.RELIEF_EXCEPTION_FLAG,
                        M.MONITOR_CODE = I.MONITOR_CODE,
                        M.ECN = I.ECN,
                        M.SOURCE_C_ITEM_MOD_DATE = I.SOURCE_C_ITEM_MOD_DATE,
                        M.SOURCE_C_ITEM_MOD_USER = I.SOURCE_C_ITEM_MOD_USER,
                        M.SYSTEM_FLAG = I.SYSTEM_FLAG,
                        M.UNSPCS = I.UNSPCS,
                        M.ITEM_TYPE = I.ITEM_TYPE,
                        M.UOM = I.UOM,
                        M.ACC_UOM = I.ACC_UOM,
                        M.CATEGORY = I.CATEGORY,
                        M.CURRENCY_ID = I.CURRENCY_ID,
                        M.EFF_END_DATE = I.EFF_END_DATE,
                        M.EFF_START_DATE = I.EFF_START_DATE,
                        M.IS_VIRTUAL = I.IS_VIRTUAL,
                        M.ITEM_LEVEL = I.ITEM_LEVEL,
                        M.LIFE_CYC_STG = I.LIFE_CYC_STG,
                        M.LIST_PRICE = I.LIST_PRICE,
                        M.LOT_SERIAL_MANAGED = I.LOT_SERIAL_MANAGED,
                        M.MFGR_ID = I.MFGR_ID,
                        M.MFR_ITEM_DESC = I.MFR_ITEM_DESC,
                        M.MFR_ITEM_ID = I.MFR_ITEM_ID,
                        M.MIN_QTY = I.MIN_QTY,
                        M.NAME = I.NAME,
                        M.ORG_ID = I.ORG_ID,
                        M.QUANTITY_MULTIPLE = I.QUANTITY_MULTIPLE,
                        M.STATUS = I.STATUS,
                        M.SUB_CATEGORY = I.SUB_CATEGORY,
                        M.UNIT_COST = I.UNIT_COST,
                        --m.ITEM_CLASS=i.ITEM_CLASS,  -- Commented for L10 mod GMP
                        M.COMMODITY_ID = I.COMMODITY_ID,
                        M.SYS_SOURCE = I.SYS_SOURCE,
                        M.GTC = I.GTC,        /* Add as part of IUS Program */
                        M.PC = I.PC,
                        M.FGC = I.FGC,
                        -- m.SYS_CREATED_BY=i.SYS_CREATED_BY,
                        M.SYS_ENT_STATE = I.SYS_ENT_STATE,
                        M.SYS_LAST_MODIFIED_BY = I.SYS_LAST_MODIFIED_BY,
                        M.SYS_LAST_MODIFIED_DATE = SYSTIMESTAMP   ,
                        M.IS_EMC = I.IS_EMC,         --,
                        M.EMC_PART_REF = I.EMC_PART_REF,
						M.DESIGN_TYPE = I.DESIGN_TYPE, -- Added for the story# 9640764
				        M.ZMOD = I.ZMOD -- Added for the story# 9640764
                  --  m.part_type = i.part_type, -- 0001 --Commented as a part of E2E
                  --  m.part_class = i.part_class -- 0001 --Commented as a part of E2E
                  /*added column as a part of FactoryFlex Project*/
                  WHEN NOT MATCHED
                  THEN
                     INSERT     (M.ITEM_ID,
                                 M.REVISION,
                                 M.COMMODITY_CODE,
                                 M.HAZARD,
                                 M.HPL,
                                 M.DELETED,
                                 M.DESCRIPTION,
                                 M.EOL_DATE,
                                 M.HEIGHT,
                                 M.HEIGHT_UM,
                                 M.LENGTH,
                                 M.LENGTH_UM,
                                 M.MAT_SPEC,
                                 M.MIL_SPEC,
                                 M.SETUP_DATE,
                                 M.TYPE_,
                                 M.WEIGHT,
                                 M.WEIGHT_UM,
                                 M.WIDTH,
                                 M.WIDTH_UM,
                                 M.TEXT_LASTSEQ,
                                 M.USER_ALPHA1,
                                 M.USER_ALPHA3,
                                 M.USER_DATE,
                                 M.RECORD_ID,
                                 M.UNID,
                                 M.SOURCE_ITEM_MOD_DATE,
                                 M.PART_STATUS,
                                 M.PRODUCT_CODE,
                                 M.FLD_SRVC_SPARE_FLAG,
                                 M.FORECAST_FLAG,
                                 M.SHIP_TRACKING_CODE,
                                 M.ALTERNATE_PART_FLAG,
                                 M.LOCAL_BILL_FLAG,
                                 M.PRINT_ON_TRAVELER_FLAG,
                                 M.BOX_CODE,
                                 M.RELIEF_EXCEPTION_FLAG,
                                 M.MONITOR_CODE,
                                 M.ECN,
                                 M.SOURCE_C_ITEM_MOD_DATE,
                                 M.SOURCE_C_ITEM_MOD_USER,
                                 M.SYSTEM_FLAG,
                                 M.UNSPCS,
                                 M.ITEM_TYPE,
                                 M.UOM,
                                 M.ACC_UOM,
                                 M.CATEGORY,
                                 M.CURRENCY_ID,
                                 M.EFF_END_DATE,
                                 M.EFF_START_DATE,
                                 M.IS_VIRTUAL,
                                 M.ITEM_LEVEL,
                                 M.LIFE_CYC_STG,
                                 M.LIST_PRICE,
                                 M.LOT_SERIAL_MANAGED,
                                 M.MFGR_ID,
                                 M.MFR_ITEM_DESC,
                                 M.MFR_ITEM_ID,
                                 M.MIN_QTY,
                                 M.NAME,
                                 M.ORG_ID,
                                 M.QUANTITY_MULTIPLE,
                                 M.STATUS,
                                 M.SUB_CATEGORY,
                                 M.UNIT_COST,
                                 --m.ITEM_CLASS,  -- Commented for L10 mod GMP
                                 M.COMMODITY_ID,
                                 M.SYS_SOURCE,
                                 M.GTC,       /* Add as part of IUS Program */
                                 M.PC,
                                 M.FGC,
                                 M.SYS_CREATED_BY,
                                 M.SYS_CREATION_DATE,
                                 M.SYS_ENT_STATE,
                                 M.SYS_LAST_MODIFIED_BY,
                                 M.SYS_LAST_MODIFIED_DATE,
                                 M.IS_EMC,      /*added column as a part of FactoryFlex Project*/             --,
                                                         --m.part_type, -- 0001  --Commented as a part of E2E
                                                         -- m.part_class  --Commented as a part of E2E
                                 M.EMC_PART_REF,
								 M.DESIGN_TYPE, -- Added for the story# 9640764
				                 M.ZMOD  -- Added for the story# 9640764
                                 )
                         VALUES (I.ITEM_ID,
                                 I.REVISION,
                                 I.COMMODITY_CODE,
                                 I.HAZARD,
                                 I.HPL,
                                 I.DELETED,
                                 I.DESCRIPTION,
                                 I.EOL_DATE,
                                 I.HEIGHT,
                                 I.HEIGHT_UM,
                                 I.LENGTH,
                                 I.LENGTH_UM,
                                 I.MAT_SPEC,
                                 I.MIL_SPEC,
                                 I.SETUP_DATE,
                                 I.TYPE_,
                                 I.WEIGHT,
                                 I.WEIGHT_UM,
                                 I.WIDTH,
                                 I.WIDTH_UM,
                                 I.TEXT_LASTSEQ,
                                 I.USER_ALPHA1,
                                 I.USER_ALPHA3,
                                 I.USER_DATE,
                                 I.RECORD_ID,
                                 I.UNID,
                                 I.SOURCE_ITEM_MOD_DATE,
                                 I.PART_STATUS,
                                 I.PRODUCT_CODE,
                                 I.FLD_SRVC_SPARE_FLAG,
                                 I.FORECAST_FLAG,
                                 I.SHIP_TRACKING_CODE,
                                 I.ALTERNATE_PART_FLAG,
                                 I.LOCAL_BILL_FLAG,
                                 I.PRINT_ON_TRAVELER_FLAG,
                                 I.BOX_CODE,
                                 I.RELIEF_EXCEPTION_FLAG,
                                 I.MONITOR_CODE,
                                 I.ECN,
                                 I.SOURCE_C_ITEM_MOD_DATE,
                                 I.SOURCE_C_ITEM_MOD_USER,
                                 I.SYSTEM_FLAG,
                                 I.UNSPCS,
                                 I.ITEM_TYPE,
                                 I.UOM,
                                 I.ACC_UOM,
                                 I.CATEGORY,
                                 I.CURRENCY_ID,
                                 I.EFF_END_DATE,
                                 I.EFF_START_DATE,
                                 I.IS_VIRTUAL,
                                 I.ITEM_LEVEL,
                                 I.LIFE_CYC_STG,
                                 I.LIST_PRICE,
                                 I.LOT_SERIAL_MANAGED,
                                 I.MFGR_ID,
                                 I.MFR_ITEM_DESC,
                                 I.MFR_ITEM_ID,
                                 I.MIN_QTY,
                                 I.NAME,
                                 I.ORG_ID,
                                 I.QUANTITY_MULTIPLE,
                                 I.STATUS,
                                 I.SUB_CATEGORY,
                                 I.UNIT_COST,
                                 --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                                 I.COMMODITY_ID,
                                 I.SYS_SOURCE,
                                 I.GTC,       /* Add as part of IUS Program */
                                 I.PC,
                                 I.FGC,
                                 I.SYS_CREATED_BY,
                                 SYSTIMESTAMP,
                                 I.SYS_ENT_STATE,
                                 I.SYS_LAST_MODIFIED_BY,
                                 SYSTIMESTAMP  ,
                                 I.IS_EMC,      /*added column as a part of FactoryFlex Project*/                       --,
                                             -- i.part_type, -- 0001 --Commented as a part of E2E
                                             --  i.part_class  --Commented as a part of E2E
                                 I.EMC_PART_REF,
								 I.DESIGN_TYPE, -- Added for the story# 9640764
				                 I.ZMOD -- Added for the story# 9640764
								 );                                    -- 0001

               L_ROW_MERGED := L_ROW_MERGED + SQL%ROWCOUNT;
            EXCEPTION
               WHEN lv_exception
               THEN
                  FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                  LOOP
                     lv_indx := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;

                     INSERT
                       INTO SCDH_AUDIT.ERR_ITEM m (M.ITEM_ID,
                                                   M.REVISION,
                                                   M.COMMODITY_CODE,
                                                   M.HAZARD,
                                                   M.HPL,
                                                   M.DELETED,
                                                   M.DESCRIPTION,
                                                   M.EOL_DATE,
                                                   M.HEIGHT,
                                                   M.HEIGHT_UM,
                                                   M.LENGTH,
                                                   M.LENGTH_UM,
                                                   M.MAT_SPEC,
                                                   M.MIL_SPEC,
                                                   M.SETUP_DATE,
                                                   M.TYPE_,
                                                   M.WEIGHT,
                                                   M.WEIGHT_UM,
                                                   M.WIDTH,
                                                   M.WIDTH_UM,
                                                   M.TEXT_LASTSEQ,
                                                   M.USER_ALPHA1,
                                                   M.USER_ALPHA3,
                                                   M.USER_DATE,
                                                   M.RECORD_ID,
                                                   M.UNID,
                                                   M.SOURCE_ITEM_MOD_DATE,
                                                   M.PART_STATUS,
                                                   M.PRODUCT_CODE,
                                                   M.FLD_SRVC_SPARE_FLAG,
                                                   M.FORECAST_FLAG,
                                                   M.SHIP_TRACKING_CODE,
                                                   M.ALTERNATE_PART_FLAG,
                                                   M.LOCAL_BILL_FLAG,
                                                   M.PRINT_ON_TRAVELER_FLAG,
                                                   M.BOX_CODE,
                                                   M.RELIEF_EXCEPTION_FLAG,
                                                   M.MONITOR_CODE,
                                                   M.ECN,
                                                   M.SOURCE_C_ITEM_MOD_DATE,
                                                   M.SOURCE_C_ITEM_MOD_USER,
                                                   M.SYSTEM_FLAG,
                                                   M.UNSPCS,
                                                   M.ITEM_TYPE,
                                                   M.UOM,
                                                   M.ACC_UOM,
                                                   M.CATEGORY,
                                                   M.CURRENCY_ID,
                                                   M.EFF_END_DATE,
                                                   M.EFF_START_DATE,
                                                   M.IS_VIRTUAL,
                                                   M.ITEM_LEVEL,
                                                   M.LIFE_CYC_STG,
                                                   M.LIST_PRICE,
                                                   M.LOT_SERIAL_MANAGED,
                                                   M.MFGR_ID,
                                                   M.MFR_ITEM_DESC,
                                                   M.MFR_ITEM_ID,
                                                   M.MIN_QTY,
                                                   M.NAME,
                                                   M.ORG_ID,
                                                   M.QUANTITY_MULTIPLE,
                                                   M.STATUS,
                                                   M.SUB_CATEGORY,
                                                   M.UNIT_COST,
                                                   --m.ITEM_CLASS,  -- Commented for L10 mod GMP
                                                   M.COMMODITY_ID,
                                                   M.SYS_SOURCE,
                                                   M.GTC, /* Add as part of IUS Program */
                                                   M.PC,
                                                   M.FGC,
                                                   --  M.SYS_CREATED_BY,
                                                   M.SYS_CREATION_DATE,
                                                   M.SYS_ENT_STATE,
                                                   --M.SYS_LAST_MODIFIED_BY,
                                                   M.SYS_LAST_MODIFIED_DATE,

                                                   M.IS_EMC,   /*added column as a part of FactoryFlex Project*/
                                                    --,
                                                                           --m.part_type, -- 0001  --Commented as a part of E2E
                                                                           -- m.part_class  --Commented as a part of E2E
                                                   M.EMC_PART_REF,
												   M.DESIGN_TYPE, -- Added for the story# 9640764
				                                   M.ZMOD -- Added for the story# 9640764
				                                   )
                     VALUES (
                               col_mst_item_cost (lv_indx).ITEM_ID,
                               col_mst_item_cost (lv_indx).REVISION,
                               col_mst_item_cost (lv_indx).COMMODITY_CODE,
                               col_mst_item_cost (lv_indx).HAZARD,
                               col_mst_item_cost (lv_indx).HPL,
                               col_mst_item_cost (lv_indx).DELETED,
                               col_mst_item_cost (lv_indx).DESCRIPTION,
                               col_mst_item_cost (lv_indx).EOL_DATE,
                               col_mst_item_cost (lv_indx).HEIGHT,
                               col_mst_item_cost (lv_indx).HEIGHT_UM,
                               col_mst_item_cost (lv_indx).LENGTH,
                               col_mst_item_cost (lv_indx).LENGTH_UM,
                               col_mst_item_cost (lv_indx).MAT_SPEC,
                               col_mst_item_cost (lv_indx).MIL_SPEC,
                               col_mst_item_cost (lv_indx).SETUP_DATE,
                               col_mst_item_cost (lv_indx).TYPE_,
                               col_mst_item_cost (lv_indx).WEIGHT,
                               col_mst_item_cost (lv_indx).WEIGHT_UM,
                               col_mst_item_cost (lv_indx).WIDTH,
                               col_mst_item_cost (lv_indx).WIDTH_UM,
                               col_mst_item_cost (lv_indx).TEXT_LASTSEQ,
                               col_mst_item_cost (lv_indx).USER_ALPHA1,
                               col_mst_item_cost (lv_indx).USER_ALPHA3,
                               col_mst_item_cost (lv_indx).USER_DATE,
                               col_mst_item_cost (lv_indx).RECORD_ID,
                               col_mst_item_cost (lv_indx).UNID,
                               col_mst_item_cost (lv_indx).SOURCE_ITEM_MOD_DATE,
                               col_mst_item_cost (lv_indx).PART_STATUS,
                               col_mst_item_cost (lv_indx).PRODUCT_CODE,
                               col_mst_item_cost (lv_indx).FLD_SRVC_SPARE_FLAG,
                               col_mst_item_cost (lv_indx).FORECAST_FLAG,
                               col_mst_item_cost (lv_indx).SHIP_TRACKING_CODE,
                               col_mst_item_cost (lv_indx).ALTERNATE_PART_FLAG,
                               col_mst_item_cost (lv_indx).LOCAL_BILL_FLAG,
                               col_mst_item_cost (lv_indx).PRINT_ON_TRAVELER_FLAG,
                               col_mst_item_cost (lv_indx).BOX_CODE,
                               col_mst_item_cost (lv_indx).RELIEF_EXCEPTION_FLAG,
                               col_mst_item_cost (lv_indx).MONITOR_CODE,
                               col_mst_item_cost (lv_indx).ECN,
                               col_mst_item_cost (lv_indx).SOURCE_C_ITEM_MOD_DATE,
                               col_mst_item_cost (lv_indx).SOURCE_C_ITEM_MOD_USER,
                               col_mst_item_cost (lv_indx).SYSTEM_FLAG,
                               col_mst_item_cost (lv_indx).UNSPCS,
                               col_mst_item_cost (lv_indx).ITEM_TYPE,
                               col_mst_item_cost (lv_indx).UOM,
                               col_mst_item_cost (lv_indx).ACC_UOM,
                               col_mst_item_cost (lv_indx).CATEGORY,
                               col_mst_item_cost (lv_indx).CURRENCY_ID,
                               col_mst_item_cost (lv_indx).EFF_END_DATE,
                               col_mst_item_cost (lv_indx).EFF_START_DATE,
                               col_mst_item_cost (lv_indx).IS_VIRTUAL,
                               col_mst_item_cost (lv_indx).ITEM_LEVEL,
                               col_mst_item_cost (lv_indx).LIFE_CYC_STG,
                               col_mst_item_cost (lv_indx).LIST_PRICE,
                               col_mst_item_cost (lv_indx).LOT_SERIAL_MANAGED,
                               col_mst_item_cost (lv_indx).MFGR_ID,
                               col_mst_item_cost (lv_indx).MFR_ITEM_DESC,
                               col_mst_item_cost (lv_indx).MFR_ITEM_ID,
                               col_mst_item_cost (lv_indx).MIN_QTY,
                               col_mst_item_cost (lv_indx).NAME,
                               col_mst_item_cost (lv_indx).ORG_ID,
                               col_mst_item_cost (lv_indx).QUANTITY_MULTIPLE,
                               col_mst_item_cost (lv_indx).STATUS,
                               col_mst_item_cost (lv_indx).SUB_CATEGORY,
                               col_mst_item_cost (lv_indx).UNIT_COST,
                               --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                               col_mst_item_cost (lv_indx).COMMODITY_ID,
                               col_mst_item_cost (lv_indx).SYS_SOURCE,
                               col_mst_item_cost (lv_indx).GTC, /* Add as part of IUS Program */
                               col_mst_item_cost (lv_indx).PC,
                               col_mst_item_cost (lv_indx).FGC,
                               --  col_mst_item_cost(lv_indx).SYS_CREATED_BY,
                               SYSTIMESTAMP,
                               col_mst_item_cost (lv_indx).SYS_ENT_STATE,
                               -- col_mst_item_cost(lv_indx).SYS_LAST_MODIFIED_BY,
                               SYSTIMESTAMP ,                               --,
                                           -- i.part_type, -- 0001 --Commented as a part of E2E
                                           --  i.part_class  --Commented as a part of E2E
                                 col_mst_item_cost (lv_indx).IS_EMC,    /*added column as a part of FactoryFlex Project*/
                               col_mst_item_cost (lv_indx).EMC_PART_REF,
                               col_mst_item_cost (lv_indx).DESIGN_TYPE, -- Added for the story# 9640764
				                col_mst_item_cost (lv_indx).ZMOD -- Added for the story# 9640764
								);
                  END LOOP;
            END;

            COMMIT;
            col_mst_item_cost.delete;
         END LOOP;

         CLOSE cur_mst_item;

         L_ERROR_LOCATION := '1.1.2.3.1';
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_UPDATE_JOB_DETAIL (
            L_IN_ROWS,
            L_ROW_MERGED,
            L_ROW_MERGED,
            0,
            0,
            'MERGE SUCCEEDED',
            FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.GV_JOB_DETAIL_SEQNO,
            L_ERROR_CODE,
            L_ERROR_MSG);
         L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG;

            RAISE EXP_MERGE;
         END IF;
      ELSE
         L_ERROR_LOCATION := '1.1.2.4';
         DBMS_OUTPUT.put_line (L_IN_ROWS);
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_INSERT_JOB_DETAIL (
            'MERGE',
               'Merge from SCDH_INBOUND.IN_ITEM to SCDH_MASTER.MST_ITEM for '
            || P_SYS_SOURCE,
            L_IN_ROWS,
            0,
            0,
            0,
            'Y',
            0,
            NULL,
            USERENV ('SESSIONID'),
            P_JOB_INSTANCE_ID,
            P_SYNC_UP_ID,
            0,
            'MERGE',
            'MERGE',
            L_ERROR_CODE,
            L_ERROR_MSG);

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG;
            RAISE EXP_MERGE;
         END IF;

         L_ERROR_LOCATION := '1.1.2.4.0';
         L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;

         L_ERROR_LOCATION := '1.1.2.4.1';
         OPEN C_ITEM_CUR;

         LOOP
            FETCH C_ITEM_CUR
               BULK COLLECT INTO L_ITEM_TAB
               LIMIT LV_LIMIT;

            EXIT WHEN L_ITEM_TAB.COUNT = 0;

            BEGIN
               L_ERROR_LOCATION := '1.1.2.4.2';

               FORALL I IN 1 .. L_ITEM_TAB.COUNT SAVE EXCEPTIONS
                  INSERT INTO SCDH_MASTER.MST_ITEM (ITEM_ID,
                                                    REVISION,
                                                    COMMODITY_CODE,
                                                    HAZARD,
                                                    HPL,
                                                    DELETED,
                                                    DESCRIPTION,
                                                    EOL_DATE,
                                                    HEIGHT,
                                                    HEIGHT_UM,
                                                    LENGTH,
                                                    LENGTH_UM,
                                                    MAT_SPEC,
                                                    MIL_SPEC,
                                                    SETUP_DATE,
                                                    TYPE_,
                                                    WEIGHT,
                                                    WEIGHT_UM,
                                                    WIDTH,
                                                    WIDTH_UM,
                                                    TEXT_LASTSEQ,
                                                    USER_ALPHA1,
                                                    USER_ALPHA3,
                                                    USER_DATE,
                                                    RECORD_ID,
                                                    UNID,
                                                    SOURCE_ITEM_MOD_DATE,
                                                    PART_STATUS,
                                                    PRODUCT_CODE,
                                                    FLD_SRVC_SPARE_FLAG,
                                                    FORECAST_FLAG,
                                                    SHIP_TRACKING_CODE,
                                                    ALTERNATE_PART_FLAG,
                                                    LOCAL_BILL_FLAG,
                                                    PRINT_ON_TRAVELER_FLAG,
                                                    BOX_CODE,
                                                    RELIEF_EXCEPTION_FLAG,
                                                    MONITOR_CODE,
                                                    ECN,
                                                    SOURCE_C_ITEM_MOD_DATE,
                                                    SOURCE_C_ITEM_MOD_USER,
                                                    SYSTEM_FLAG,
                                                    UNSPCS,
                                                    ITEM_TYPE,
                                                    UOM,
                                                    ACC_UOM,
                                                    CATEGORY,
                                                    CURRENCY_ID,
                                                    EFF_END_DATE,
                                                    EFF_START_DATE,
                                                    IS_VIRTUAL,
                                                    ITEM_LEVEL,
                                                    LIFE_CYC_STG,
                                                    LIST_PRICE,
                                                    LOT_SERIAL_MANAGED,
                                                    MFGR_ID,
                                                    MFR_ITEM_DESC,
                                                    MFR_ITEM_ID,
                                                    MIN_QTY,
                                                    NAME,
                                                    ORG_ID,
                                                    QUANTITY_MULTIPLE,
                                                    STATUS,
                                                    SUB_CATEGORY,
                                                    UNIT_COST,
                                                    --ITEM_CLASS,  -- Commented for L10 mod GMP
                                                    COMMODITY_ID,
                                                    SYS_SOURCE,
                                                    GTC, /* Add as part of IUS Program */
                                                    PC,
                                                    FGC,
                                                    SYS_CREATED_BY,
                                                    SYS_CREATION_DATE,
                                                    SYS_ENT_STATE,
                                                    SYS_LAST_MODIFIED_BY,
                                                    SYS_LAST_MODIFIED_DATE,
                                                    IS_EMC,                    /*added column as a part of FactoryFlex Project*/
                                                    EMC_PART_REF,  /*Story# 6249610 */
													DESIGN_TYPE, -- Added for the story# 9640764
				                                    ZMOD -- Added for the story# 9640764
								)
                       VALUES (L_ITEM_TAB (I).ITEM_ID,
                               L_ITEM_TAB (I).REVISION,
                               TRIM (L_ITEM_TAB (I).COMMODITY_CODE),    --0003
                               L_ITEM_TAB (I).HAZARD,
                               L_ITEM_TAB (I).HPL,
                               L_ITEM_TAB (I).DELETED,
                               L_ITEM_TAB (I).DESCRIPTION,
                               L_ITEM_TAB (I).EOL_DATE,
                               L_ITEM_TAB (I).HEIGHT,
                               L_ITEM_TAB (I).HEIGHT_UM,
                               L_ITEM_TAB (I).LENGTH,
                               L_ITEM_TAB (I).LENGTH_UM,
                               L_ITEM_TAB (I).MAT_SPEC,
                               L_ITEM_TAB (I).MIL_SPEC,
                               L_ITEM_TAB (I).SETUP_DATE,
                               L_ITEM_TAB (I).TYPE_,
                               L_ITEM_TAB (I).WEIGHT,
                               L_ITEM_TAB (I).WEIGHT_UM,
                               L_ITEM_TAB (I).WIDTH,
                               L_ITEM_TAB (I).WIDTH_UM,
                               L_ITEM_TAB (I).TEXT_LASTSEQ,
                               L_ITEM_TAB (I).USER_ALPHA1,
                               L_ITEM_TAB (I).USER_ALPHA3,
                               L_ITEM_TAB (I).USER_DATE,
                               L_ITEM_TAB (I).RECORD_ID,
                               L_ITEM_TAB (I).UNID,
                               L_ITEM_TAB (I).SOURCE_ITEM_MOD_DATE,
                               L_ITEM_TAB (I).PART_STATUS,
                               L_ITEM_TAB (I).PRODUCT_CODE,
                               L_ITEM_TAB (I).FLD_SRVC_SPARE_FLAG,
                               L_ITEM_TAB (I).FORECAST_FLAG,
                               L_ITEM_TAB (I).SHIP_TRACKING_CODE,
                               L_ITEM_TAB (I).ALTERNATE_PART_FLAG,
                               L_ITEM_TAB (I).LOCAL_BILL_FLAG,
                               L_ITEM_TAB (I).PRINT_ON_TRAVELER_FLAG,
                               L_ITEM_TAB (I).BOX_CODE,
                               L_ITEM_TAB (I).RELIEF_EXCEPTION_FLAG,
                               L_ITEM_TAB (I).MONITOR_CODE,
                               L_ITEM_TAB (I).ECN,
                               L_ITEM_TAB (I).SOURCE_C_ITEM_MOD_DATE,
                               L_ITEM_TAB (I).SOURCE_C_ITEM_MOD_USER,
                               L_ITEM_TAB (I).SYSTEM_FLAG,
                               L_ITEM_TAB (I).UNSPCS,
                               L_ITEM_TAB (I).ITEM_TYPE,
                               L_ITEM_TAB (I).UOM,
                               L_ITEM_TAB (I).ACC_UOM,
                               L_ITEM_TAB (I).CATEGORY,
                               L_ITEM_TAB (I).CURRENCY_ID,
                               L_ITEM_TAB (I).EFF_END_DATE,
                               L_ITEM_TAB (I).EFF_START_DATE,
                               L_ITEM_TAB (I).IS_VIRTUAL,
                               L_ITEM_TAB (I).ITEM_LEVEL,
                               L_ITEM_TAB (I).LIFE_CYC_STG,
                               L_ITEM_TAB (I).LIST_PRICE,
                               L_ITEM_TAB (I).LOT_SERIAL_MANAGED,
                               L_ITEM_TAB (I).MFGR_ID,
                               L_ITEM_TAB (I).MFR_ITEM_DESC,
                               L_ITEM_TAB (I).MFR_ITEM_ID,
                               L_ITEM_TAB (I).MIN_QTY,
                               L_ITEM_TAB (I).NAME,
                               L_ITEM_TAB (I).ORG_ID,
                               L_ITEM_TAB (I).QUANTITY_MULTIPLE,
                               L_ITEM_TAB (I).STATUS,
                               L_ITEM_TAB (I).SUB_CATEGORY,
                               L_ITEM_TAB (I).UNIT_COST,
                               --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                               L_ITEM_TAB (I).COMMODITY_ID,
                               L_ITEM_TAB (I).SYS_SOURCE,
                               L_ITEM_TAB (I).GTC, /* Add as part of IUS Program */
                               L_ITEM_TAB (I).PC,
                               L_ITEM_TAB (I).FGC,
                               L_ITEM_TAB (I).SYS_CREATED_BY,
                               L_ITEM_TAB (I).SYS_CREATION_DATE,
                               L_ITEM_TAB (I).SYS_ENT_STATE,
                               L_ITEM_TAB (I).SYS_LAST_MODIFIED_BY,
                               L_ITEM_TAB (I).SYS_LAST_MODIFIED_DATE,
                               L_ITEM_TAB (I).IS_EMC,  /*added column as a part of FactoryFlex Project*/
                               L_ITEM_TAB (I).EMC_PART_REF ,            /*Story# 6249610 */
							   L_ITEM_TAB (I).DESIGN_TYPE, -- Added for the story# 9640764
				               L_ITEM_TAB (I).ZMOD -- Added for the story# 9640764
                               );

               L_ROW_INSERTED := L_ROW_INSERTED + L_ITEM_TAB.COUNT;
               L_ERROR_LOCATION := '1.1.2.4.3';
            EXCEPTION
               WHEN L_BULK_ERRORS_EX
               THEN
                  L_ERROR_LOCATION := '1.1.2.4.4';

                  -- logging errors into the ERR_ITEM table
                  FOR I IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                  LOOP
                     IF L_ITEM_TAB.EXISTS (
                           SQL%BULK_EXCEPTIONS (I).ERROR_INDEX)
                     THEN
                        L_INDX := SQL%BULK_EXCEPTIONS (I).ERROR_INDEX;
                        L_ERROR_LOCATION := '1.1.2.4.5';
                        L_ERR_ITEM_EXCEPTION (I).ITEM_ID :=
                           L_ITEM_TAB (L_INDX).ITEM_ID;
                        L_ERR_ITEM_EXCEPTION (I).REVISION :=
                           L_ITEM_TAB (L_INDX).REVISION;
                        L_ERR_ITEM_EXCEPTION (I).COMMODITY_CODE :=
                           TRIM (L_ITEM_TAB (L_INDX).COMMODITY_CODE);   --0003
                        L_ERR_ITEM_EXCEPTION (I).HAZARD :=
                           L_ITEM_TAB (L_INDX).HAZARD;
                        L_ERR_ITEM_EXCEPTION (I).HPL :=
                           L_ITEM_TAB (L_INDX).HPL;
                        L_ERR_ITEM_EXCEPTION (I).DELETED :=
                           L_ITEM_TAB (L_INDX).DELETED;
                        L_ERR_ITEM_EXCEPTION (I).DESCRIPTION :=
                           L_ITEM_TAB (L_INDX).DESCRIPTION;
                        L_ERR_ITEM_EXCEPTION (I).EOL_DATE :=
                           L_ITEM_TAB (L_INDX).EOL_DATE;
                        L_ERR_ITEM_EXCEPTION (I).HEIGHT :=
                           L_ITEM_TAB (L_INDX).HEIGHT;
                        L_ERR_ITEM_EXCEPTION (I).HEIGHT_UM :=
                           L_ITEM_TAB (L_INDX).HEIGHT_UM;
                        L_ERR_ITEM_EXCEPTION (I).LENGTH :=
                           L_ITEM_TAB (L_INDX).LENGTH;
                        L_ERR_ITEM_EXCEPTION (I).LENGTH_UM :=
                           L_ITEM_TAB (L_INDX).LENGTH_UM;
                        L_ERR_ITEM_EXCEPTION (I).MAT_SPEC :=
                           L_ITEM_TAB (L_INDX).MAT_SPEC;
                        L_ERR_ITEM_EXCEPTION (I).MIL_SPEC :=
                           L_ITEM_TAB (L_INDX).MIL_SPEC;
                        L_ERR_ITEM_EXCEPTION (I).SETUP_DATE :=
                           L_ITEM_TAB (L_INDX).SETUP_DATE;
                        L_ERR_ITEM_EXCEPTION (I).TYPE_ :=
                           L_ITEM_TAB (L_INDX).TYPE_;
                        L_ERR_ITEM_EXCEPTION (I).WEIGHT :=
                           L_ITEM_TAB (L_INDX).WEIGHT;
                        L_ERR_ITEM_EXCEPTION (I).WEIGHT_UM :=
                           L_ITEM_TAB (L_INDX).WEIGHT_UM;
                        L_ERR_ITEM_EXCEPTION (I).WIDTH :=
                           L_ITEM_TAB (L_INDX).WIDTH;
                        L_ERR_ITEM_EXCEPTION (I).WIDTH_UM :=
                           L_ITEM_TAB (L_INDX).WIDTH_UM;
                        L_ERR_ITEM_EXCEPTION (I).TEXT_LASTSEQ :=
                           L_ITEM_TAB (L_INDX).TEXT_LASTSEQ;
                        L_ERR_ITEM_EXCEPTION (I).USER_ALPHA1 :=
                           L_ITEM_TAB (L_INDX).USER_ALPHA1;
                        L_ERR_ITEM_EXCEPTION (I).USER_ALPHA3 :=
                           L_ITEM_TAB (L_INDX).USER_ALPHA3;
                        L_ERR_ITEM_EXCEPTION (I).USER_DATE :=
                           L_ITEM_TAB (L_INDX).USER_DATE;
                        L_ERR_ITEM_EXCEPTION (I).RECORD_ID :=
                           L_ITEM_TAB (L_INDX).RECORD_ID;
                        L_ERR_ITEM_EXCEPTION (I).UNID :=
                           L_ITEM_TAB (L_INDX).UNID;
                        L_ERR_ITEM_EXCEPTION (I).SOURCE_ITEM_MOD_DATE :=
                           L_ITEM_TAB (L_INDX).SOURCE_ITEM_MOD_DATE;
                        L_ERR_ITEM_EXCEPTION (I).PART_STATUS :=
                           L_ITEM_TAB (L_INDX).PART_STATUS;
                        L_ERR_ITEM_EXCEPTION (I).PRODUCT_CODE :=
                           L_ITEM_TAB (L_INDX).PRODUCT_CODE;
                        L_ERR_ITEM_EXCEPTION (I).FLD_SRVC_SPARE_FLAG :=
                           L_ITEM_TAB (L_INDX).FLD_SRVC_SPARE_FLAG;
                        L_ERR_ITEM_EXCEPTION (I).FORECAST_FLAG :=
                           L_ITEM_TAB (L_INDX).FORECAST_FLAG;
                        L_ERR_ITEM_EXCEPTION (I).SHIP_TRACKING_CODE :=
                           L_ITEM_TAB (L_INDX).SHIP_TRACKING_CODE;
                        L_ERR_ITEM_EXCEPTION (I).ALTERNATE_PART_FLAG :=
                           L_ITEM_TAB (L_INDX).ALTERNATE_PART_FLAG;
                        L_ERR_ITEM_EXCEPTION (I).LOCAL_BILL_FLAG :=
                           L_ITEM_TAB (L_INDX).LOCAL_BILL_FLAG;
                        L_ERR_ITEM_EXCEPTION (I).PRINT_ON_TRAVELER_FLAG :=
                           L_ITEM_TAB (L_INDX).PRINT_ON_TRAVELER_FLAG;
                        L_ERR_ITEM_EXCEPTION (I).BOX_CODE :=
                           L_ITEM_TAB (L_INDX).BOX_CODE;
                        L_ERR_ITEM_EXCEPTION (I).RELIEF_EXCEPTION_FLAG :=
                           L_ITEM_TAB (L_INDX).RELIEF_EXCEPTION_FLAG;
                        L_ERR_ITEM_EXCEPTION (I).MONITOR_CODE :=
                           L_ITEM_TAB (L_INDX).MONITOR_CODE;
                        L_ERR_ITEM_EXCEPTION (I).ECN :=
                           L_ITEM_TAB (L_INDX).ECN;
                        L_ERR_ITEM_EXCEPTION (I).SOURCE_C_ITEM_MOD_DATE :=
                           L_ITEM_TAB (L_INDX).SOURCE_C_ITEM_MOD_DATE;
                        L_ERR_ITEM_EXCEPTION (I).SOURCE_C_ITEM_MOD_USER :=
                           L_ITEM_TAB (L_INDX).SOURCE_C_ITEM_MOD_USER;
                        L_ERR_ITEM_EXCEPTION (I).SYSTEM_FLAG :=
                           L_ITEM_TAB (L_INDX).SYSTEM_FLAG;
                        L_ERR_ITEM_EXCEPTION (I).UNSPCS :=
                           L_ITEM_TAB (L_INDX).UNSPCS;
                        L_ERR_ITEM_EXCEPTION (I).ITEM_TYPE :=
                           L_ITEM_TAB (L_INDX).ITEM_TYPE;
                        L_ERR_ITEM_EXCEPTION (I).UOM :=
                           L_ITEM_TAB (L_INDX).UOM;
                        L_ERR_ITEM_EXCEPTION (I).ACC_UOM :=
                           L_ITEM_TAB (L_INDX).ACC_UOM;
                        L_ERR_ITEM_EXCEPTION (I).CATEGORY :=
                           L_ITEM_TAB (L_INDX).CATEGORY;
                        L_ERR_ITEM_EXCEPTION (I).CURRENCY_ID :=
                           L_ITEM_TAB (L_INDX).CURRENCY_ID;
                        L_ERR_ITEM_EXCEPTION (I).EFF_END_DATE :=
                           L_ITEM_TAB (L_INDX).EFF_END_DATE;
                        L_ERR_ITEM_EXCEPTION (I).EFF_START_DATE :=
                           L_ITEM_TAB (L_INDX).EFF_START_DATE;
                        L_ERR_ITEM_EXCEPTION (I).IS_VIRTUAL :=
                           L_ITEM_TAB (L_INDX).IS_VIRTUAL;
                        L_ERR_ITEM_EXCEPTION (I).ITEM_LEVEL :=
                           L_ITEM_TAB (L_INDX).ITEM_LEVEL;
                        L_ERR_ITEM_EXCEPTION (I).LIFE_CYC_STG :=
                           L_ITEM_TAB (L_INDX).LIFE_CYC_STG;
                        L_ERR_ITEM_EXCEPTION (I).LIST_PRICE :=
                           L_ITEM_TAB (L_INDX).LIST_PRICE;
                        L_ERR_ITEM_EXCEPTION (I).LOT_SERIAL_MANAGED :=
                           L_ITEM_TAB (L_INDX).LOT_SERIAL_MANAGED;
                        L_ERR_ITEM_EXCEPTION (I).MFGR_ID :=
                           L_ITEM_TAB (L_INDX).MFGR_ID;
                        L_ERR_ITEM_EXCEPTION (I).MFR_ITEM_DESC :=
                           L_ITEM_TAB (L_INDX).MFR_ITEM_DESC;
                        L_ERR_ITEM_EXCEPTION (I).MFR_ITEM_ID :=
                           L_ITEM_TAB (L_INDX).MFR_ITEM_ID;
                        L_ERR_ITEM_EXCEPTION (I).MIN_QTY :=
                           L_ITEM_TAB (L_INDX).MIN_QTY;
                        L_ERR_ITEM_EXCEPTION (I).NAME :=
                           L_ITEM_TAB (L_INDX).NAME;
                        L_ERR_ITEM_EXCEPTION (I).ORG_ID :=
                           L_ITEM_TAB (L_INDX).ORG_ID;
                        L_ERR_ITEM_EXCEPTION (I).QUANTITY_MULTIPLE :=
                           L_ITEM_TAB (L_INDX).QUANTITY_MULTIPLE;
                        L_ERR_ITEM_EXCEPTION (I).STATUS :=
                           L_ITEM_TAB (L_INDX).STATUS;
                        L_ERR_ITEM_EXCEPTION (I).SUB_CATEGORY :=
                           L_ITEM_TAB (L_INDX).SUB_CATEGORY;
                        L_ERR_ITEM_EXCEPTION (I).UNIT_COST :=
                           L_ITEM_TAB (L_INDX).UNIT_COST;
                        L_ERR_ITEM_EXCEPTION (I).COMMODITY_ID :=
                           L_ITEM_TAB (L_INDX).COMMODITY_ID;
                        L_ERR_ITEM_EXCEPTION (I).SYS_ERR_CODE :=
                           SQL%BULK_EXCEPTIONS (I).ERROR_CODE;
                        L_ERR_ITEM_EXCEPTION (I).SYS_ERR_MESG :=
                           SQLERRM (SQL%BULK_EXCEPTIONS (I).ERROR_CODE * -1);
                        L_ERR_ITEM_EXCEPTION (I).SYS_NC_TYPE := 'INSERT';
                        L_ERR_ITEM_EXCEPTION (I).SYS_SOURCE := P_SYS_SOURCE;
                        L_ERR_ITEM_EXCEPTION (I).GTC :=
                           L_ITEM_TAB (L_INDX).GTC; /* Add as part of IUS Program */
                        L_ERR_ITEM_EXCEPTION (I).PC := L_ITEM_TAB (L_INDX).PC;
                        L_ERR_ITEM_EXCEPTION (I).FGC :=
                           L_ITEM_TAB (L_INDX).FGC;
                        L_ERR_ITEM_EXCEPTION (I).SYS_CREATION_DATE :=
                           SYSTIMESTAMP;
                        L_ERR_ITEM_EXCEPTION (I).SYS_LAST_MODIFIED_DATE :=
                           SYSTIMESTAMP;
                        L_ERR_ITEM_EXCEPTION (I).SYS_ENT_STATE := 'ACTIVE';
                        L_ERR_ITEM_EXCEPTION (I).IS_EMC := L_ITEM_TAB (L_INDX).IS_EMC;                 /*added column as a part of FactoryFlex Project*/
                        L_ERR_ITEM_EXCEPTION (I).EMC_PART_REF := L_ITEM_TAB (L_INDX).EMC_PART_REF; /*Story# 6249610 */
						 L_ERR_ITEM_EXCEPTION (I).DESIGN_TYPE := L_ITEM_TAB (L_INDX).DESIGN_TYPE; -- Added for the story# 9640764
				               L_ERR_ITEM_EXCEPTION (I).ZMOD := L_ITEM_TAB (L_INDX).ZMOD;-- Added for the story# 9640764

                     END IF;
                  END LOOP;


                  L_ERROR_LOCATION := '1.1.2.4.6';

                  /* Load the exceptions into the exceptions table... */
                  FORALL I IN INDICES OF L_ERR_ITEM_EXCEPTION
                     INSERT INTO SCDH_AUDIT.ERR_ITEM (ITEM_ID,
                                                      REVISION,
                                                      COMMODITY_CODE,
                                                      HAZARD,
                                                      HPL,
                                                      DELETED,
                                                      DESCRIPTION,
                                                      EOL_DATE,
                                                      HEIGHT,
                                                      HEIGHT_UM,
                                                      LENGTH,
                                                      LENGTH_UM,
                                                      MAT_SPEC,
                                                      MIL_SPEC,
                                                      SETUP_DATE,
                                                      TYPE_,
                                                      WEIGHT,
                                                      WEIGHT_UM,
                                                      WIDTH,
                                                      WIDTH_UM,
                                                      TEXT_LASTSEQ,
                                                      USER_ALPHA1,
                                                      USER_ALPHA3,
                                                      USER_DATE,
                                                      RECORD_ID,
                                                      UNID,
                                                      SOURCE_ITEM_MOD_DATE,
                                                      PART_STATUS,
                                                      PRODUCT_CODE,
                                                      FLD_SRVC_SPARE_FLAG,
                                                      FORECAST_FLAG,
                                                      SHIP_TRACKING_CODE,
                                                      ALTERNATE_PART_FLAG,
                                                      LOCAL_BILL_FLAG,
                                                      PRINT_ON_TRAVELER_FLAG,
                                                      BOX_CODE,
                                                      RELIEF_EXCEPTION_FLAG,
                                                      MONITOR_CODE,
                                                      ECN,
                                                      SOURCE_C_ITEM_MOD_DATE,
                                                      SOURCE_C_ITEM_MOD_USER,
                                                      SYSTEM_FLAG,
                                                      UNSPCS,
                                                      ITEM_TYPE,
                                                      UOM,
                                                      ACC_UOM,
                                                      CATEGORY,
                                                      CURRENCY_ID,
                                                      EFF_END_DATE,
                                                      EFF_START_DATE,
                                                      IS_VIRTUAL,
                                                      ITEM_LEVEL,
                                                      LIFE_CYC_STG,
                                                      LIST_PRICE,
                                                      LOT_SERIAL_MANAGED,
                                                      MFGR_ID,
                                                      MFR_ITEM_DESC,
                                                      MFR_ITEM_ID,
                                                      MIN_QTY,
                                                      NAME,
                                                      ORG_ID,
                                                      QUANTITY_MULTIPLE,
                                                      STATUS,
                                                      SUB_CATEGORY,
                                                      UNIT_COST,
                                                      ITEM_CLASS,
                                                      COMMODITY_ID,
                                                      SYS_ERR_CODE,
                                                      SYS_ERR_MESG,
                                                      SYS_NC_TYPE,
                                                      SYS_SOURCE,
                                                      GTC, /* Add as part of IUS Program */
                                                      PC,
                                                      FGC,
                                                      SYS_CREATION_DATE,
                                                      SYS_LAST_MODIFIED_DATE,
                                                      SYS_ENT_STATE,
                                                      IS_EMC,              /*added column as a part of FactoryFlex Project*/
                                                      EMC_PART_REF,        /*Story# 6249610 */
													  DESIGN_TYPE, -- Added for the story# 9640764
				                                     ZMOD-- Added for the story# 9640764
													 )
                          VALUES (
                                    L_ERR_ITEM_EXCEPTION (I).ITEM_ID,
                                    L_ERR_ITEM_EXCEPTION (I).REVISION,
                                    L_ERR_ITEM_EXCEPTION (I).COMMODITY_CODE,
                                    L_ERR_ITEM_EXCEPTION (I).HAZARD,
                                    L_ERR_ITEM_EXCEPTION (I).HPL,
                                    L_ERR_ITEM_EXCEPTION (I).DELETED,
                                    L_ERR_ITEM_EXCEPTION (I).DESCRIPTION,
                                    L_ERR_ITEM_EXCEPTION (I).EOL_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).HEIGHT,
                                    L_ERR_ITEM_EXCEPTION (I).HEIGHT_UM,
                                    L_ERR_ITEM_EXCEPTION (I).LENGTH,
                                    L_ERR_ITEM_EXCEPTION (I).LENGTH_UM,
                                    L_ERR_ITEM_EXCEPTION (I).MAT_SPEC,
                                    L_ERR_ITEM_EXCEPTION (I).MIL_SPEC,
                                    L_ERR_ITEM_EXCEPTION (I).SETUP_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).TYPE_,
                                    L_ERR_ITEM_EXCEPTION (I).WEIGHT,
                                    L_ERR_ITEM_EXCEPTION (I).WEIGHT_UM,
                                    L_ERR_ITEM_EXCEPTION (I).WIDTH,
                                    L_ERR_ITEM_EXCEPTION (I).WIDTH_UM,
                                    L_ERR_ITEM_EXCEPTION (I).TEXT_LASTSEQ,
                                    L_ERR_ITEM_EXCEPTION (I).USER_ALPHA1,
                                    L_ERR_ITEM_EXCEPTION (I).USER_ALPHA3,
                                    L_ERR_ITEM_EXCEPTION (I).USER_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).RECORD_ID,
                                    L_ERR_ITEM_EXCEPTION (I).UNID,
                                    L_ERR_ITEM_EXCEPTION (I).SOURCE_ITEM_MOD_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).PART_STATUS,
                                    L_ERR_ITEM_EXCEPTION (I).PRODUCT_CODE,
                                    L_ERR_ITEM_EXCEPTION (I).FLD_SRVC_SPARE_FLAG,
                                    L_ERR_ITEM_EXCEPTION (I).FORECAST_FLAG,
                                    L_ERR_ITEM_EXCEPTION (I).SHIP_TRACKING_CODE,
                                    L_ERR_ITEM_EXCEPTION (I).ALTERNATE_PART_FLAG,
                                    L_ERR_ITEM_EXCEPTION (I).LOCAL_BILL_FLAG,
                                    L_ERR_ITEM_EXCEPTION (I).PRINT_ON_TRAVELER_FLAG,
                                    L_ERR_ITEM_EXCEPTION (I).BOX_CODE,
                                    L_ERR_ITEM_EXCEPTION (I).RELIEF_EXCEPTION_FLAG,
                                    L_ERR_ITEM_EXCEPTION (I).MONITOR_CODE,
                                    L_ERR_ITEM_EXCEPTION (I).ECN,
                                    L_ERR_ITEM_EXCEPTION (I).SOURCE_C_ITEM_MOD_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).SOURCE_C_ITEM_MOD_USER,
                                    L_ERR_ITEM_EXCEPTION (I).SYSTEM_FLAG,
                                    L_ERR_ITEM_EXCEPTION (I).UNSPCS,
                                    L_ERR_ITEM_EXCEPTION (I).ITEM_TYPE,
                                    L_ERR_ITEM_EXCEPTION (I).UOM,
                                    L_ERR_ITEM_EXCEPTION (I).ACC_UOM,
                                    L_ERR_ITEM_EXCEPTION (I).CATEGORY,
                                    L_ERR_ITEM_EXCEPTION (I).CURRENCY_ID,
                                    L_ERR_ITEM_EXCEPTION (I).EFF_END_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).EFF_START_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).IS_VIRTUAL,
                                    L_ERR_ITEM_EXCEPTION (I).ITEM_LEVEL,
                                    L_ERR_ITEM_EXCEPTION (I).LIFE_CYC_STG,
                                    L_ERR_ITEM_EXCEPTION (I).LIST_PRICE,
                                    L_ERR_ITEM_EXCEPTION (I).LOT_SERIAL_MANAGED,
                                    L_ERR_ITEM_EXCEPTION (I).MFGR_ID,
                                    L_ERR_ITEM_EXCEPTION (I).MFR_ITEM_DESC,
                                    L_ERR_ITEM_EXCEPTION (I).MFR_ITEM_ID,
                                    L_ERR_ITEM_EXCEPTION (I).MIN_QTY,
                                    L_ERR_ITEM_EXCEPTION (I).NAME,
                                    L_ERR_ITEM_EXCEPTION (I).ORG_ID,
                                    L_ERR_ITEM_EXCEPTION (I).QUANTITY_MULTIPLE,
                                    L_ERR_ITEM_EXCEPTION (I).STATUS,
                                    L_ERR_ITEM_EXCEPTION (I).SUB_CATEGORY,
                                    L_ERR_ITEM_EXCEPTION (I).UNIT_COST,
                                    L_ERR_ITEM_EXCEPTION (I).ITEM_CLASS,
                                    L_ERR_ITEM_EXCEPTION (I).COMMODITY_ID,
                                    L_ERR_ITEM_EXCEPTION (I).SYS_ERR_CODE,
                                    L_ERR_ITEM_EXCEPTION (I).SYS_ERR_MESG,
                                    L_ERR_ITEM_EXCEPTION (I).SYS_NC_TYPE,
                                    L_ERR_ITEM_EXCEPTION (I).SYS_SOURCE,
                                    L_ERR_ITEM_EXCEPTION (I).GTC, /* Add as part of IUS Program */
                                    L_ERR_ITEM_EXCEPTION (I).PC,
                                    L_ERR_ITEM_EXCEPTION (I).FGC,
                                    L_ERR_ITEM_EXCEPTION (I).SYS_CREATION_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).SYS_LAST_MODIFIED_DATE,
                                    L_ERR_ITEM_EXCEPTION (I).SYS_ENT_STATE,
                                    L_ERR_ITEM_EXCEPTION (I).IS_EMC,             /*added column as a part of FactoryFlex Project*/
                                    L_ERR_ITEM_EXCEPTION (I).EMC_PART_REF,        /*Story# 6249610 */
									L_ERR_ITEM_EXCEPTION (I).DESIGN_TYPE, -- Added for the story# 9640764
				                    L_ERR_ITEM_EXCEPTION (I).ZMOD-- Added for the story# 9640764
													 );
            END;
         --COMMIT; -- added to commit for 1000 records

         END LOOP;

         CLOSE C_ITEM_CUR;

         /* Commented old code
          SELECT DISTINCT
                 i.ITEM_ID,
                 i.REVISION,
                 TRIM(i.COMMODITY_CODE) COMMODITY_CODE,   --0003
                 i.HAZARD,
                 i.HPL,
                 i.DELETED,
                 i.DESCRIPTION,
                 TO_TIMESTAMP_TZ(i.EOL_DATE,'YYYY-MM-DD HH24:MI:SS TZH:TZM') eol_date,
                 i.HEIGHT,
                 i.HEIGHT_UM,
                 i.LENGTH,
                 i.LENGTH_UM,
                 i.MAT_SPEC,
                 i.MIL_SPEC,
                 TO_TIMESTAMP_TZ(i.SETUP_DATE,'YYYY-MM-DD HH24:MI:SS TZH:TZM') SETUP_DATE,
                 i.TYPE_,
                 i.WEIGHT,
                 i.WEIGHT_UM,
                 i.WIDTH,
                 i.WIDTH_UM,
                 i.TEXT_LASTSEQ,
                 i.USER_ALPHA1,
                 i.USER_ALPHA3,
                 TO_TIMESTAMP_TZ(i.USER_DATE,'YYYY-MM-DD HH24:MI:SS TZH:TZM') USER_DATE,
                 i.RECORD_ID,
                 i.UNID,
                 TO_TIMESTAMP_TZ(i.SOURCE_ITEM_MOD_DATE,'YYYY-MM-DD HH24:MI:SS TZH:TZM') SOURCE_ITEM_MOD_DATE,
                 i.PART_STATUS,
                 i.PRODUCT_CODE,
                 i.FLD_SRVC_SPARE_FLAG,
                 i.FORECAST_FLAG,
                 i.SHIP_TRACKING_CODE,
                 i.ALTERNATE_PART_FLAG,
                 i.LOCAL_BILL_FLAG,
                 i.PRINT_ON_TRAVELER_FLAG,
                 i.BOX_CODE,
                 i.RELIEF_EXCEPTION_FLAG,
                 i.MONITOR_CODE,
                 i.ECN,
                 TO_TIMESTAMP_TZ(i.SOURCE_C_ITEM_MOD_DATE,'YYYY-MM-DD HH24:MI:SS TZH:TZM') SOURCE_C_ITEM_MOD_DATE,
                 i.SOURCE_C_ITEM_MOD_USER,
                 i.SYSTEM_FLAG,
                 i.UNSPCS,
                 i.ITEM_TYPE,
                 i.UOM,
                 i.ACC_UOM,
                 i.CATEGORY,
                 i.CURRENCY_ID,
                 TO_TIMESTAMP_TZ(i.EFF_END_DATE,'YYYY-MM-DD HH24:MI:SS TZH:TZM') EFF_END_DATE,
                 TO_TIMESTAMP_TZ(EFF_START_DATE,'YYYY-MM-DD HH24:MI:SS TZH:TZM') EFF_START_DATE,
                 i.IS_VIRTUAL,
                 i.ITEM_LEVEL,
                 i.LIFE_CYC_STG,
                 i.LIST_PRICE,
                 i.LOT_SERIAL_MANAGED,
                 i.MFGR_ID,
                 i.MFR_ITEM_DESC,
                 i.MFR_ITEM_ID,
                 i.MIN_QTY,
                 i.NAME,
                 i.ORG_ID,
                 i.QUANTITY_MULTIPLE,
                 i.STATUS,
                 i.SUB_CATEGORY,
                 i.UNIT_COST,
                 --i.ITEM_CLASS,  -- Commented for L10 mod GMP
                 i.COMMODITY_ID,
                 i.SYS_SOURCE,
                 i.SYS_CREATED_BY,
                  SYSTIMESTAMP,
                 i.SYS_ENT_STATE,
                 i.SYS_LAST_MODIFIED_BY,
                 SYSTIMESTAMP,
                 i.part_type,
                 i.part_class
            FROM SCDH_INBOUND.IN_ITEM i
           WHERE --i.sys_source LIKE 'GLOVIA%'
             i.sys_source = P_SYS_SOURCE
             AND NOT EXISTS (SELECT 1
                               FROM SCDH_MASTER.MST_ITEM m
                              WHERE m.item_id = i.item_id
                                AND m.revision = i.revision);
         l_row_merged := l_row_merged + SQL%ROWCOUNT;

         Commented old code */
         L_ERROR_LOCATION := '1.1.2.4.7';

         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_UPDATE_JOB_DETAIL (
            L_IN_ROWS,
            L_ROW_INSERTED,
            L_ROW_INSERTED,
            0,
            0,
            'INSERT SUCCEEDED',
            FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.GV_JOB_DETAIL_SEQNO,
            L_ERROR_CODE,
            L_ERROR_MSG);

         L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG;

            RAISE EXP_MERGE;
         END IF;
      END IF;

      -- End of Addition -- 0001
       L_ERROR_LOCATION := '1.2.1';
     --Begin <RK001> to update is_emc from Glovia_CCC if item exists in ccc as well as in other sys_source
       OPEN C_ITEM_GLOVIA_CCC;
       LOOP
         FETCH C_ITEM_GLOVIA_CCC
         BULK COLLECT INTO L_ITEM_CCC
         LIMIT LV_LIMIT;

           EXIT WHEN L_ITEM_CCC.COUNT = 0;
       BEGIN
        FORALL I IN 1 .. L_ITEM_CCC.COUNT SAVE EXCEPTIONS

           UPDATE SCDH_MASTER.MST_ITEM
            SET IS_EMC = L_ITEM_CCC(i).IS_EMC,
                SYS_SOURCE = L_ITEM_CCC(i).SYS_SOURCE,
                SYS_LAST_MODIFIED_DATE = SYSTIMESTAMP
        WHERE ITEM_ID = L_ITEM_CCC(i).ITEM_ID;

       EXCEPTION
        WHEN lv_exception
               THEN
                  FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                  LOOP
                     lv_indx := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;

                     INSERT
                       INTO SCDH_AUDIT.ERR_ITEM m (M.ITEM_ID,
                                                   M.IS_EMC,
                                                   SYS_CREATION_DATE,
                                                   SYS_LAST_MODIFIED_DATE
                                                   )
                                  VALUES(L_ITEM_CCC(lv_indx).ITEM_ID,
                                         L_ITEM_CCC(lv_indx).IS_EMC,
                                         SYSTIMESTAMP,
                                         SYSTIMESTAMP
                                         );
                    END LOOP;
          END;
       L_ROW_UPDATED := L_ROW_UPDATED + SQL%ROWCOUNT;
       COMMIT;
            L_ITEM_CCC.delete;
         END LOOP;

       CLOSE C_ITEM_GLOVIA_CCC;

       L_ERROR_LOCATION := '1.2.2';

      IF LV_CAN_UPDATE_ENT_STATE = 'Y'
      THEN
         FOR K IN (SELECT ITEM_ID, REVISION, SYS_ENT_STATE
                     FROM SCDH_INBOUND.IN_ITEM
                    WHERE SYS_ENT_STATE = 'DELETED')
         LOOP
            UPDATE SCDH_MASTER.MST_ITEM M
               SET M.SYS_ENT_STATE = K.SYS_ENT_STATE,
                   M.SYS_LAST_MODIFIED_DATE = SYSTIMESTAMP
             WHERE M.ITEM_ID = K.ITEM_ID AND M.REVISION = K.REVISION;
         END LOOP;

         L_ROW_UPDATED := SQL%ROWCOUNT;
      END IF;


      L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;
      FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_UPDATE_JOB_DETAIL (
         L_IN_ROWS,
         L_ROW_MERGED,
         L_ROW_MERGED,
         L_ROW_UPDATED,
         0,
         'UPDATE SUCCEEDED',
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.GV_JOB_DETAIL_SEQNO,
         L_ERROR_CODE,
         L_ERROR_MSG);

      L_ERROR_LOCATION := '1.1.4';
      L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;
      FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_INSERT_JOB_DETAIL (
         'UPDATE_SYNCUP',
         'UPDATING AIF_LAST_SYNC_UP ',
         0,
         0,
         0,
         0,
         'Y',
         0,
         NULL,
         USERENV ('SESSIONID'),
         P_JOB_INSTANCE_ID,
         P_SYNC_UP_ID,
         0,
         'UPDATE_SYNCUP',
         'UPDATE_SYNCUP',
         L_ERROR_CODE,
         L_ERROR_MSG);


      IF L_ERROR_CODE <> 0
      THEN
         P_ERROR_CODE := L_ERROR_CODE;
         P_ERROR_MSG := L_ERROR_MSG;
         RAISE EXP_MERGE;
      END IF;

      L_ERROR_LOCATION := '1.1.5';

      UPDATE FDL_SNOP_SCDHUB.AIF_LAST_SYNC_UP
         SET SYNC_UP_DATE = SYSDATE,
             OPERATION_CODE =
                (--SELECT MAX (TRANSACTION_SEQ)
                   SELECT NVL(DECODE(MAX (TRANSACTION_SEQ),999999999,0,MAX (TRANSACTION_SEQ)),0)-- PRB0069275
                   FROM SCDH_INBOUND.IN_ITEM
                  WHERE SYS_SOURCE = P_SYS_SOURCE),
             OPERATION_STATUS = 'SUCCESS',
             INSTANCE_ID = P_JOB_INSTANCE_ID                           -- 0001
       --START_TIME = NVL(END_TIME, L_END_TIME), -- 0001 --commented by utham
       --END_TIME = NVL(END_TIME, L_END_TIME) + (1/L_FREQUENCY) -- 0001--commented by utham
       WHERE     SYNC_UP_ID = P_SYNC_UP_ID
             AND 0 <= (SELECT COUNT (1)
                         FROM SCDH_INBOUND.IN_ITEM
                        WHERE SYS_SOURCE = P_SYS_SOURCE AND ROWNUM = 1);

      L_ERROR_MSG := L_ERROR_MSG || 'Error Loc: ' || L_ERROR_LOCATION;
      FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_UPDATE_JOB_DETAIL (
         L_IN_ROWS,
         L_ROW_MERGED,
         0,
         0,
         0,
            'UPDATE SUCCEEDED'
         || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS')
         || ':'
         || P_SYNC_UP_ID,
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.GV_JOB_DETAIL_SEQNO,
         L_ERROR_CODE,
         L_ERROR_MSG);

      IF L_ERROR_CODE <> 0
      THEN
         P_ERROR_CODE := L_ERROR_CODE;
         P_ERROR_MSG := L_ERROR_MSG;
         RAISE EXP_MERGE;
      END IF;

      L_ERROR_LOCATION := '1.1.7';
      COMMIT;
      P_ERROR_CODE := 0;
      P_ERROR_MSG := 'SUCCESS';
   EXCEPTION
      WHEN EXP_MERGE
      THEN
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_UPDATE_JOB_DETAIL (
            L_IN_ROWS,
            L_ROW_MERGED,
            L_ROW_MERGED,
            0,
            0,
            'ERROR',
            FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.GV_JOB_DETAIL_SEQNO,
            L_ERROR_CODE,
            L_ERROR_MSG);

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG || 'at location' || L_ERROR_LOCATION;
            RETURN;
         END IF;

         ROLLBACK;
         P_ERROR_CODE := 1;
         P_ERROR_MSG := 'POST_SQL_ITEM at: ' || L_ERROR_LOCATION;
      WHEN OTHERS
      THEN
         FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.P_UPDATE_JOB_DETAIL (
            L_IN_ROWS,
            L_ROW_MERGED,
            L_ROW_MERGED,
            0,
            1,
            'ERROR' || SQLERRM,
            FDL_SNOP_SCDHUB.PROCESS_AUDIT_PKG.GV_JOB_DETAIL_SEQNO,
            L_ERROR_CODE,
            L_ERROR_MSG);

         IF L_ERROR_CODE <> 0
         THEN
            P_ERROR_CODE := L_ERROR_CODE;
            P_ERROR_MSG := L_ERROR_MSG || 'at location' || L_ERROR_LOCATION;
            RETURN;
         END IF;

         P_ERROR_CODE := 1;
         P_ERROR_MSG :=
            'POST_SQL_ITEM: ' || L_ERROR_LOCATION || ':' || SQLERRM;
         ROLLBACK;

         IF C_ITEM_CUR%ISOPEN = TRUE
         THEN
            CLOSE C_ITEM_CUR;
         END IF;
   END POST_SQL_ITEM;
