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


class CommonResp(BaseModel):
    success: bool = True
    resultCode: str = "SUCCESS"
    data: Optional[Any] = None
    values: Optional[List[Any]] = None

