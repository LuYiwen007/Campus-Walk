from pydantic import BaseModel, Field
from typing import Optional, List, Any
from datetime import datetime


class ConversationCreate(BaseModel):
    title: str = Field(..., description="会话标题")
    llmModel: str = Field("defaultModel", description="大模型标识")


class ConversationVO(BaseModel):
    id: int
    title: str
    llmModel: str
    ext: dict = {}
    chatList: list = []
    gmtCreate: Optional[datetime] = None
    gmtModified: Optional[datetime] = None

    class Config:
        from_attributes = True


class ChatCreate(BaseModel):
    content: str
    conversationId: int
    type: str = "TEXT"
    role: str = "user"


class ChatVO(BaseModel):
    id: int
    conversationId: int
    role: str
    type: str
    content: str
    ext: dict = {}
    gmtCreate: Optional[datetime] = None
    gmtModified: Optional[datetime] = None

    class Config:
        from_attributes = True


class RouteLocationsCreate(BaseModel):
    conversationId: int
    locations: str  # 地点名称，用"--"分隔
    routeType: str = "walking"


class RouteLocationsVO(BaseModel):
    id: int
    conversationId: int
    locations: str
    routeType: str
    ext: dict = {}
    gmtCreate: Optional[datetime] = None
    gmtModified: Optional[datetime] = None

    class Config:
        from_attributes = True


class RouteSegmentRequest(BaseModel):
    conversationId: int
    segmentIndex: int  # 当前要显示的路段索引


class RouteSegmentResponse(BaseModel):
    segmentIndex: int
    fromLocation: str
    toLocation: str
    routeData: dict  # 高德API返回的路线数据
    isLastSegment: bool


class CommonResp(BaseModel):
    success: bool = True
    resultCode: str = "SUCCESS"
    data: Optional[Any] = None
    values: Optional[List[Any]] = None


# ===== AR 相关 =====
class ARSessionStartReq(BaseModel):
    userId: str = ""
    mode: str = "gaode"  # gaode | ar
    conversationId: int = 0
    device: str = ""
    os: str = ""
    usedGeoAnchor: bool = False


class ARSessionEndReq(BaseModel):
    sessionId: int


class ARSessionVO(BaseModel):
    id: int
    userId: str
    mode: str
    conversationId: int
    usedGeoAnchor: bool
    device: str
    os: str
    startTime: datetime
    endTime: Optional[datetime] = None

    class Config:
        from_attributes = True


class NearbyPOIQuery(BaseModel):
    """POI附近查询参数模型（带验证）"""
    lat: float = Field(..., ge=-90, le=90, description="纬度（必填，范围：-90到90）")
    lon: float = Field(..., ge=-180, le=180, description="经度（必填，范围：-180到180）")
    heading: float = Field(0.0, ge=0, le=360, description="设备朝向（0-360度）")
    radius: int = Field(150, ge=1, le=500, description="搜索半径（米，默认150，最大500）")
    fov: float = Field(60.0, ge=1, le=180, description="视野角度（度，默认60）")


class POIVO(BaseModel):
    """POI返回数据模型"""
    id: int = None  # 数据库主键ID（可选，用于兼容）
    poi_id: str  # POI唯一标识（高德地图的uid）
    name: str  # 建筑/地点名称
    latitude: float  # 纬度
    longitude: float  # 经度
    address: str = ""  # 详细地址
    description: str = ""  # 描述信息
    poi_type: str = ""  # 类型：building, landmark, restaurant等
    distance: float = 0.0  # 距离（米）
    phone: str = ""  # 联系电话
    website: str = ""  # 网址
    business_area: str = ""  # 所属商圈
    province: str = ""  # 省份
    city: str = ""  # 城市
    district: str = ""  # 区县
    rating: float = None  # 评分（0-5）
    images: list = []  # 图片列表

    class Config:
        from_attributes = True


class ARRecognitionSaveRequest(BaseModel):
    """AR识别保存请求模型"""
    latitude: float = Field(..., ge=-90, le=90, description="纬度（必填，范围：-90到90）")
    longitude: float = Field(..., ge=-180, le=180, description="经度（必填，范围：-180到180）")
    heading: float = Field(None, ge=0, le=360, description="设备朝向（0-360度）")
    fov: float = Field(None, ge=1, le=180, description="视野角度（度）")
    radius: float = Field(None, ge=1, le=500, description="搜索半径（米）")
    detected_poi_id: int = Field(None, description="识别到的POI ID")
    confidence: float = Field(None, ge=0, le=1, description="识别置信度（0-1）")
    session_id: str = Field(None, description="会话ID（可选）")
    user_id: str = Field(None, description="用户ID（可选）")
    recognition_mode: str = Field("auto", description="识别模式：auto/manual")
    device_info: str = Field(None, description="设备信息（可选）")
    app_version: str = Field(None, description="应用版本（可选）")


class ARRecognitionRecordVO(BaseModel):
    """AR识别记录返回模型"""
    id: int
    user_id: str = None
    session_id: str = None
    latitude: float
    longitude: float
    heading: float = None
    fov: float = None
    radius: float = None
    detected_poi_id: int = None
    confidence: float = None
    recognition_mode: str = "auto"
    device_info: str = None
    app_version: str = None
    created_at: datetime
    
    # 关联的POI信息（可选）
    detected_poi: Optional[POIVO] = None

    class Config:
        from_attributes = True


class ARRecognitionHistoryQuery(BaseModel):
    """AR识别历史查询参数模型"""
    session_id: str = Field(None, description="会话ID（可选）")
    user_id: str = Field(None, description="用户ID（可选）")
    limit: int = Field(20, ge=1, le=100, description="返回记录数（默认20，最大100）")
    offset: int = Field(0, ge=0, description="偏移量（分页）")
