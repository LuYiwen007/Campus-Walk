package com.campuswalk.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.Arrays;
import java.util.List;

@Getter
@Setter
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private String jwtSecret = "dev-change-on-server";
    private String jwtAlgorithm = "HS256";
    private long jwtExpireMinutes = 10080;
    /** 逗号分隔，与 Python CORS_ORIGINS 一致 */
    private String corsOrigins = "http://localhost:3000,http://127.0.0.1:3000";
    private boolean seedOnStartup = true;
    private int messageRetentionDays = 10;
    /** DashScope API Key（sk- 开头），切勿提交到仓库，使用环境变量 DASHSCOPE_API_KEY */
    private String dashscopeApiKey = "";
    /** 文本生成模型名，参见 https://help.aliyun.com/zh/model-studio/developer-reference/api-details-9 */
    private String dashscopeModel = "qwen-turbo";
    /**
     * 业务空间 ID（控制台「应用/工作空间」）；使用 RAM 子账号 API Key 时常需通过请求头 X-DashScope-WorkSpace 传递。
     * 环境变量：DASHSCOPE_WORKSPACE
     */
    private String dashscopeWorkspace = "";
    /**
     * 兼容模式文本生成接口完整 URL（北京地域默认）。
     * 新加坡等参见官方文档替换域名。
     */
    private String dashscopeBaseUrl = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation";
    /**
     * OpenAI 兼容模式 Chat Completions（含图多模态），用于用户上传图片时的路线规划。
     * 环境变量：DASHSCOPE_COMPATIBLE_CHAT_URL
     */
    private String dashscopeCompatibleChatUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
    /** 含图路线规划所用视觉模型。环境变量：DASHSCOPE_VISION_MODEL */
    private String dashscopeVisionModel = "qwen-vl-plus";
    /**
     * 百炼「对话」类应用 ID，用于将结构化路线转写为自然语言；通过 DashScope 应用 completion 接口调用。
     * 环境变量：DASHSCOPE_DIALOGUE_APP_ID
     */
    private String dashscopeDialogueAppId = "";
    /**
     * 通义「路线规划」文本接口的 system 角色全文；请在模型平台维护后通过环境变量注入，勿写入仓库。
     * 环境变量：ROUTE_PLANNER_SYSTEM_PROMPT（或 application-local.yml 本地覆盖，且勿提交该文件）
     */
    private String routePlannerSystemPrompt = "";
    /**
     * AR 建筑识别：视觉模型 system 提示（可选；未配置则使用代码内默认）。
     * 环境变量：AR_BUILDING_VISION_SYSTEM_PROMPT
     */
    private String arBuildingVisionSystemPrompt = "";
    /**
     * 高德 Web 服务 Key（用于服务端地理编码，勿提交仓库；环境变量 AMAP_REST_KEY）。
     * 未配置时途经点仅保存地名，客户端可回退为 SDK POI 检索。
     */
    private String amapRestKey = "";
    /**
     * 地理编码时附加城市，提高命中率（如：成都、北京市）。
     */
    private String amapGeocodeCity = "成都";

    public List<String> corsOriginList() {
        return Arrays.stream(corsOrigins.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();
    }
}
