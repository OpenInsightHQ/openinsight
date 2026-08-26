ALTER TABLE dm_dataset_table MODIFY COLUMN table_comment varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL COMMENT '表注释';

alter table dm_datasource add column signature varchar(128);
alter table dm_dataset add column signature varchar(128);
alter table infra_license add column machine_id varchar(64);


CREATE TABLE `sl_system` (
                             `id` bigint NOT NULL AUTO_INCREMENT COMMENT '系统ID',
                             `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '系统名称',
                             `code` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '系统编码',
                             `description` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '系统描述',
                             `api_base_url` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'API基础路径',
                             `auth_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PASSWORD' COMMENT '认证方式：PASSWORD/TOKEN',
                             `custom_headers` text COLLATE utf8mb4_unicode_ci COMMENT '自定义请求头JSON(如tenant-id)',
                             `access_token` text COLLATE utf8mb4_unicode_ci COMMENT 'Access Token(直接提供,跳过登录)',
                             `username` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '用户名(仅学习用)',
                             `password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '密码(仅学习用)',
                             `model_provider` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '学习用LLM模型供应商',
                             `learn_model` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '学习用LLM模型',
                             `learn_status` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NONE' COMMENT '学习状态',
                             `learn_msg` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT '学习状态消息',
                             `api_count` int NOT NULL DEFAULT '0' COMMENT 'API数量',
                             `creator` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '',
                             `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
                             `updater` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '',
                             `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                             `deleted` bit(1) NOT NULL DEFAULT b'0',
                             `tenant_id` bigint NOT NULL DEFAULT '0',
                             PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='信息系统表';


CREATE TABLE `sl_business_flow` (
                                    `id` bigint NOT NULL AUTO_INCREMENT,
                                    `system_id` bigint NOT NULL,
                                    `name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                                    `description` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                                    `api_seq` text COLLATE utf8mb4_unicode_ci,
                                    `creator` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '',
                                    `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    `updater` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '',
                                    `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    `deleted` bit(1) NOT NULL DEFAULT b'0',
                                    `tenant_id` bigint NOT NULL DEFAULT '0',
                                    PRIMARY KEY (`id`),
                                    KEY `idx_system_id` (`system_id`)
) ENGINE=InnoDB AUTO_INCREMENT=63 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='信息系统业务流表';

CREATE TABLE `sl_api` (
                          `id` bigint NOT NULL AUTO_INCREMENT,
                          `system_id` bigint NOT NULL,
                          `name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                          `path` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                          `method` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                          `summary` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                          `description` text COLLATE utf8mb4_unicode_ci,
                          `tags` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                          `parameters` text COLLATE utf8mb4_unicode_ci,
                          `request_body` text COLLATE utf8mb4_unicode_ci,
                          `responses` text COLLATE utf8mb4_unicode_ci,
                          `risk_level` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
                          `request_example` text COLLATE utf8mb4_unicode_ci,
                          `response_example` text COLLATE utf8mb4_unicode_ci,
                          `sort_order` int NOT NULL DEFAULT '0',
                          `creator` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '',
                          `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          `updater` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '',
                          `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                          `deleted` bit(1) NOT NULL DEFAULT b'0',
                          `tenant_id` bigint NOT NULL DEFAULT '0',
                          PRIMARY KEY (`id`),
                          KEY `idx_system_id` (`system_id`)
) ENGINE=InnoDB AUTO_INCREMENT=348 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='信息系统API表';


INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5285,'提示词授权','store:system-prompt:authorize',3,5,5219,'','','','',0,b'1',b'1',b'1','1','2026-08-21 10:15:30','1','2026-08-21 10:15:30',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5284,'分类删除','store:app-category:delete',3,4,5280,'','','','',0,b'1',b'1',b'1','1','2026-08-20 21:40:36','1','2026-08-20 21:40:36',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5283,'分类更新','store:app-category:update',3,3,5280,'','','','',0,b'1',b'1',b'1','1','2026-08-20 21:40:36','1','2026-08-20 21:40:36',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5282,'分类创建','store:app-category:create',3,2,5280,'','','','',0,b'1',b'1',b'1','1','2026-08-20 21:40:36','1','2026-08-20 21:40:36',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5281,'分类查询','store:app-category:query',3,1,5280,'','','','',0,b'1',b'1',b'1','1','2026-08-20 21:40:36','1','2026-08-20 21:40:36',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5280,'应用分类管理','',2,2,5085,'app-category','','store/appCategory/index','StoreAppCategory',0,b'0',b'1',b'1','1','2026-08-20 21:40:16','1','2026-08-20 21:40:16',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5273,'业务流删除','dm:info-business-flow:delete',3,12,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5272,'业务流更新','dm:info-business-flow:update',3,11,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5271,'业务流创建','dm:info-business-flow:create',3,10,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5270,'业务流查询','dm:info-business-flow:query',3,9,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5269,'API删除','dm:info-api:delete',3,8,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5268,'API更新','dm:info-api:update',3,7,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5267,'API创建','dm:info-api:create',3,6,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5266,'API查询','dm:info-api:query',3,5,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5265,'系统删除','dm:info-system:delete',3,4,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5264,'系统更新','dm:info-system:update',3,3,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5263,'系统创建','dm:info-system:create',3,2,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5262,'系统查询','dm:info-system:query',3,1,5261,'','','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5261,'系统列表','',2,1,5260,'list','','dm/informationsystem/index','InformationSystem',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');
INSERT INTO `system_menu`(`id`,`name`,`permission`,`type`,`sort`,`parent_id`,`path`,`icon`,`component`,`component_name`,`status`,`visible`,`keep_alive`,`always_show`,`creator`,`create_time`,`updater`,`update_time`,`deleted`) VALUES (5260,'信息系统','',1,31,0,'/info-system','ep:monitor','','',0,b'1',b'1',b'1','1','2026-08-06 10:49:28','1','2026-08-06 10:49:28',b'0');

UPDATE `system_tenant_package` SET `name`='所有功能',`status`=0,`remark`='',`menu_ids`='[1024,1025,1,1036,1037,1038,1039,1063,1064,1065,5200,5201,5202,5203,5204,5205,5206,5207,5208,5209,5210,5211,5212,5213,5214,5215,5216,5217,5218,5219,100,5220,101,5221,5222,103,5223,104,5224,5225,5226,107,5227,5228,5229,5230,5231,5232,5233,5234,5042,2739,5043,5044,5045,5046,5047,5048,5049,5050,5051,5052,5053,5054,5055,5056,5057,5058,5059,5060,5061,5062,5063,5064,5065,5066,5067,5068,5069,5070,5071,5072,5073,5074,5075,5076,5077,5078,5079,5080,5081,5082,5083,5084,5085,5086,5087,5088,5089,5090,5091,5092,5093,5094,5095,5096,5097,1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012,5110,5111,5112,5113,1017,5114,1018,5115,1019,1020,5116,1021,5117,1022,5118,1023,5119,5260,5261,5262,5263,5264,5265,5266,5267,5268,5269,5270,5271,5272,5273,5280,5281,5282,5283,5284,5285]',`creator`='1',`create_time`='2025-12-24 10:20:33',`updater`='admin',`update_time`='2026-08-21 10:15:30',`deleted`=b'0' WHERE `id`=113;
