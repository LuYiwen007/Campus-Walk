from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship, Mapped, mapped_column
from datetime import datetime
from .db import Base


class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    llm_model: Mapped[str] = mapped_column(String(64), default="defaultModel")
    ext: Mapped[dict] = mapped_column(JSON, default=dict)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    chats: Mapped[list["ChatMessage"]] = relationship("ChatMessage", back_populates="conversation", cascade="all, delete-orphan")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("conversations.id", ondelete="CASCADE"), index=True, nullable=False)
    role: Mapped[str] = mapped_column(String(16), default="user")
    type: Mapped[str] = mapped_column(String(16), default="TEXT")
    content: Mapped[str] = mapped_column(Text, nullable=False)
    ext: Mapped[dict] = mapped_column(JSON, default=dict)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    conversation: Mapped[Conversation] = relationship("Conversation", back_populates="chats")


class RouteLocations(Base):
    __tablename__ = "route_locations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("conversations.id", ondelete="CASCADE"), index=True, nullable=False)
    locations: Mapped[str] = mapped_column(Text, nullable=False)  # 地点名称，用"--"分隔
    route_type: Mapped[str] = mapped_column(String(32), default="walking")  # 路线类型：walking, driving等
    ext: Mapped[dict] = mapped_column(JSON, default=dict)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    conversation: Mapped[Conversation] = relationship("Conversation")


# 新增：POI 缓存表
class PoiCache(Base):
    __tablename__ = "poi_cache"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    lat: Mapped[str] = mapped_column(String(32), nullable=False)
    lon: Mapped[str] = mapped_column(String(32), nullable=False)
    address: Mapped[str] = mapped_column(String(512), default="")
    source: Mapped[str] = mapped_column(String(16), default="amap")
    raw_json: Mapped[dict] = mapped_column(JSON, default=dict)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# 新增：AR 会话表
class ARSession(Base):
    __tablename__ = "ar_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(64), default="")
    mode: Mapped[str] = mapped_column(String(16), default="gaode")  # gaode | ar
    conversation_id: Mapped[int] = mapped_column(Integer, index=True, default=0)
    used_geo_anchor: Mapped[bool] = mapped_column(Integer, default=0)  # 0/1 存储
    device: Mapped[str] = mapped_column(String(64), default="")
    os: Mapped[str] = mapped_column(String(64), default="")
    start_time: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    end_time: Mapped[datetime] = mapped_column(DateTime, nullable=True)


# 新增：AR 识别扫描记录
class ARPoiScan(Base):
    __tablename__ = "ar_poi_scans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(Integer, index=True)
    lat: Mapped[str] = mapped_column(String(32), nullable=False)
    lon: Mapped[str] = mapped_column(String(32), nullable=False)
    heading: Mapped[float] = mapped_column(String(32), default="0")
    pitch: Mapped[float] = mapped_column(String(32), default="0")
    roll: Mapped[float] = mapped_column(String(32), default="0")
    fov: Mapped[float] = mapped_column(String(32), default="60")
    matched_poi_id: Mapped[int] = mapped_column(Integer, index=True, nullable=True)
    method: Mapped[str] = mapped_column(String(16), default="geo-ray")
    distance_m: Mapped[float] = mapped_column(String(32), default="0")
    angle_deg: Mapped[float] = mapped_column(String(32), default="0")
    confidence: Mapped[float] = mapped_column(String(32), default="0.0")
    photo_url: Mapped[str] = mapped_column(String(512), default="")
    model_version: Mapped[str] = mapped_column(String(32), default="")
    predicted_poi_id: Mapped[int] = mapped_column(Integer, nullable=True)
    user_corrected_poi_id: Mapped[int] = mapped_column(Integer, nullable=True)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


# 新增：模型版本管理
class MLModelVersion(Base):
    __tablename__ = "ml_model_versions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
    version: Mapped[str] = mapped_column(String(32), nullable=False)
    task: Mapped[str] = mapped_column(String(32), nullable=False)  # landmark_cls | text_ocr
    metrics: Mapped[dict] = mapped_column(JSON, default=dict)
    file_url: Mapped[str] = mapped_column(String(512), default="")
    is_active: Mapped[int] = mapped_column(Integer, default=0)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
