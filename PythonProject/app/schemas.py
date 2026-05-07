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
    lat: float
    lon: float
    heading: float = 0.0
    radius: int = 150
    fov: float = 60.0


class POIVO(BaseModel):
    id: int
    name: str
    lat: str
    lon: str
    address: str = ""

    class Config:
        from_attributes = True
