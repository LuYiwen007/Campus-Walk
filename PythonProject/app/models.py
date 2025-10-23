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


# 新增：建筑信息表
class Building(Base):
    __tablename__ = "buildings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    latitude: Mapped[float] = mapped_column(String(32), nullable=False)
    longitude: Mapped[float] = mapped_column(String(32), nullable=False)
    address: Mapped[str] = mapped_column(String(512), default="")
    building_type: Mapped[str] = mapped_column(String(64), default="unknown")
    floor_count: Mapped[int] = mapped_column(Integer, default=0)
    year_built: Mapped[int] = mapped_column(Integer, nullable=True)
    architect: Mapped[str] = mapped_column(String(255), nullable=True)
    style: Mapped[str] = mapped_column(String(128), nullable=True)
    features: Mapped[dict] = mapped_column(JSON, default=dict)
    images: Mapped[dict] = mapped_column(JSON, default=dict)
    is_landmark: Mapped[bool] = mapped_column(Integer, default=0)
    popularity_score: Mapped[float] = mapped_column(String(32), default="0.0")
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# 新增：AR地标表
class ARLandmark(Base):
    __tablename__ = "ar_landmarks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    building_id: Mapped[int] = mapped_column(Integer, nullable=False)
    landmark_name: Mapped[str] = mapped_column(String(255), nullable=False)
    landmark_type: Mapped[str] = mapped_column(String(64), default="building")
    ar_anchor_id: Mapped[str] = mapped_column(String(128), nullable=True)
    position_x: Mapped[float] = mapped_column(String(32), nullable=True)
    position_y: Mapped[float] = mapped_column(String(32), nullable=True)
    position_z: Mapped[float] = mapped_column(String(32), nullable=True)
    rotation_x: Mapped[float] = mapped_column(String(32), default="0")
    rotation_y: Mapped[float] = mapped_column(String(32), default="0")
    rotation_z: Mapped[float] = mapped_column(String(32), default="0")
    scale_x: Mapped[float] = mapped_column(String(32), default="1.0")
    scale_y: Mapped[float] = mapped_column(String(32), default="1.0")
    scale_z: Mapped[float] = mapped_column(String(32), default="1.0")
    is_active: Mapped[bool] = mapped_column(Integer, default=1)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# 新增：导航路线表
class NavigationRoute(Base):
    __tablename__ = "navigation_routes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    route_name: Mapped[str] = mapped_column(String(255), nullable=False)
    start_building_id: Mapped[int] = mapped_column(Integer, nullable=True)
    end_building_id: Mapped[int] = mapped_column(Integer, nullable=True)
    start_latitude: Mapped[float] = mapped_column(String(32), nullable=False)
    start_longitude: Mapped[float] = mapped_column(String(32), nullable=False)
    end_latitude: Mapped[float] = mapped_column(String(32), nullable=False)
    end_longitude: Mapped[float] = mapped_column(String(32), nullable=False)
    route_type: Mapped[str] = mapped_column(String(32), default="walking")
    distance_meters: Mapped[int] = mapped_column(Integer, nullable=True)
    estimated_time_seconds: Mapped[int] = mapped_column(Integer, nullable=True)
    route_data: Mapped[dict] = mapped_column(JSON, default=dict)
    waypoints: Mapped[dict] = mapped_column(JSON, default=dict)
    difficulty_level: Mapped[int] = mapped_column(Integer, default=1)
    is_accessible: Mapped[bool] = mapped_column(Integer, default=1)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# 新增：用户AR会话表
class UserARSession(Base):
    __tablename__ = "user_ar_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(64), nullable=False)
    session_type: Mapped[str] = mapped_column(String(32), nullable=False)
    start_latitude: Mapped[float] = mapped_column(String(32), nullable=True)
    start_longitude: Mapped[float] = mapped_column(String(32), nullable=True)
    current_latitude: Mapped[float] = mapped_column(String(32), nullable=True)
    current_longitude: Mapped[float] = mapped_column(String(32), nullable=True)
    heading_degrees: Mapped[float] = mapped_column(String(32), nullable=True)
    pitch_degrees: Mapped[float] = mapped_column(String(32), nullable=True)
    roll_degrees: Mapped[float] = mapped_column(String(32), nullable=True)
    device_info: Mapped[dict] = mapped_column(JSON, default=dict)
    session_data: Mapped[dict] = mapped_column(JSON, default=dict)
    is_active: Mapped[bool] = mapped_column(Integer, default=1)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    ended_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# 新增：AR识别记录表
class ARRecognitionLog(Base):
    __tablename__ = "ar_recognition_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(Integer, nullable=False)
    user_id: Mapped[str] = mapped_column(String(64), nullable=False)
    image_data: Mapped[bytes] = mapped_column(Text, nullable=True)
    image_url: Mapped[str] = mapped_column(String(512), nullable=True)
    recognized_building_id: Mapped[int] = mapped_column(Integer, nullable=True)
    confidence_score: Mapped[float] = mapped_column(String(32), nullable=True)
    recognition_method: Mapped[str] = mapped_column(String(32), default="vision")
    processing_time_ms: Mapped[int] = mapped_column(Integer, nullable=True)
    device_orientation: Mapped[str] = mapped_column(String(32), nullable=True)
    lighting_conditions: Mapped[str] = mapped_column(String(32), nullable=True)
    weather_conditions: Mapped[str] = mapped_column(String(32), nullable=True)
    recognition_result: Mapped[dict] = mapped_column(JSON, default=dict)
    is_correct: Mapped[bool] = mapped_column(Integer, nullable=True)
    user_feedback: Mapped[str] = mapped_column(String(512), nullable=True)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


# 新增：导航历史表
class NavigationHistory(Base):
    __tablename__ = "navigation_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(Integer, nullable=False)
    user_id: Mapped[str] = mapped_column(String(64), nullable=False)
    route_id: Mapped[int] = mapped_column(Integer, nullable=True)
    start_time: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    end_time: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    total_distance_meters: Mapped[int] = mapped_column(Integer, nullable=True)
    actual_duration_seconds: Mapped[int] = mapped_column(Integer, nullable=True)
    navigation_points: Mapped[dict] = mapped_column(JSON, default=dict)
    user_rating: Mapped[int] = mapped_column(Integer, nullable=True)
    user_feedback: Mapped[str] = mapped_column(Text, nullable=True)
    completion_status: Mapped[str] = mapped_column(String(32), default="in_progress")
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


# 新增：建筑特征表
class BuildingFeature(Base):
    __tablename__ = "building_features"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    building_id: Mapped[int] = mapped_column(Integer, nullable=False)
    feature_type: Mapped[str] = mapped_column(String(64), nullable=False)
    feature_data: Mapped[dict] = mapped_column(JSON, nullable=False)
    model_version: Mapped[str] = mapped_column(String(32), nullable=True)
    confidence_score: Mapped[float] = mapped_column(String(32), nullable=True)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


# 新增：用户偏好表
class UserPreference(Base):
    __tablename__ = "user_preferences"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    preferred_building_types: Mapped[dict] = mapped_column(JSON, default=dict)
    preferred_route_types: Mapped[dict] = mapped_column(JSON, default=dict)
    accessibility_needs: Mapped[dict] = mapped_column(JSON, default=dict)
    language_preference: Mapped[str] = mapped_column(String(8), default="zh-CN")
    ar_settings: Mapped[dict] = mapped_column(JSON, default=dict)
    notification_settings: Mapped[dict] = mapped_column(JSON, default=dict)
    gmt_create: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmt_modified: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


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
