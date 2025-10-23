from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from .db import get_db
from . import models, schemas
import base64
import json
import time
from datetime import datetime
from typing import List, Optional
import requests
import os

router = APIRouter(prefix="/api/ar", tags=["AR功能"])

# ===== 建筑识别相关接口 =====

@router.post("/building/recognize", response_model=schemas.CommonResp)
async def recognize_building(
    image: UploadFile = File(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    heading: float = Form(0.0),
    user_id: str = Form("default_user"),
    session_id: int = Form(0),
    db: Session = Depends(get_db)
):
    """上传图片进行建筑识别"""
    try:
        # 读取图片数据
        image_data = await image.read()
        
        # 模拟识别过程（实际应该调用AI模型）
        start_time = time.time()
        
        # 这里应该调用真实的图像识别模型
        # 目前返回模拟结果
        recognition_result = {
            "building_id": 1,
            "building_name": "图书馆",
            "confidence": 0.85,
            "description": "校园主图书馆，建于1995年，藏书丰富",
            "building_type": "library",
            "features": ["现代建筑", "玻璃幕墙", "多层结构"]
        }
        
        processing_time = int((time.time() - start_time) * 1000)
        
        # 保存识别记录
        recognition_log = models.ARRecognitionLog(
            session_id=session_id,
            user_id=user_id,
            image_data=image_data,
            recognized_building_id=recognition_result["building_id"],
            confidence_score=recognition_result["confidence"],
            processing_time_ms=processing_time,
            recognition_result=recognition_result,
            gmt_create=datetime.utcnow()
        )
        db.add(recognition_log)
        db.commit()
        
        # 获取建筑详细信息
        building = db.query(models.Building).filter(
            models.Building.id == recognition_result["building_id"]
        ).first()
        
        if building:
            building_info = {
                "id": building.id,
                "name": building.name,
                "description": building.description,
                "latitude": float(building.latitude),
                "longitude": float(building.longitude),
                "address": building.address,
                "building_type": building.building_type,
                "features": building.features,
                "images": building.images,
                "is_landmark": bool(building.is_landmark)
            }
        else:
            building_info = recognition_result
            
        return schemas.CommonResp(
            success=True,
            data=building_info,
            message="建筑识别成功"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"识别失败: {str(e)}")


@router.get("/buildings/nearby", response_model=schemas.CommonResp)
def get_nearby_buildings(
    latitude: float,
    longitude: float,
    radius: int = 500,
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """获取附近建筑列表"""
    try:
        # 这里应该实现基于地理位置的查询
        # 目前返回模拟数据
        buildings = db.query(models.Building).limit(limit).all()
        
        building_list = []
        for building in buildings:
            building_info = {
                "id": building.id,
                "name": building.name,
                "description": building.description,
                "latitude": float(building.latitude),
                "longitude": float(building.longitude),
                "address": building.address,
                "building_type": building.building_type,
                "distance": 100.0,  # 模拟距离
                "is_landmark": bool(building.is_landmark)
            }
            building_list.append(building_info)
            
        return schemas.CommonResp(
            success=True,
            data=building_list,
            message="获取附近建筑成功"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取建筑列表失败: {str(e)}")


@router.get("/building/{building_id}/info", response_model=schemas.CommonResp)
def get_building_info(building_id: int, db: Session = Depends(get_db)):
    """获取建筑详细信息"""
    try:
        building = db.query(models.Building).filter(
            models.Building.id == building_id
        ).first()
        
        if not building:
            raise HTTPException(status_code=404, detail="建筑不存在")
            
        building_info = {
            "id": building.id,
            "name": building.name,
            "description": building.description,
            "latitude": float(building.latitude),
            "longitude": float(building.longitude),
            "address": building.address,
            "building_type": building.building_type,
            "floor_count": building.floor_count,
            "year_built": building.year_built,
            "architect": building.architect,
            "style": building.style,
            "features": building.features,
            "images": building.images,
            "is_landmark": bool(building.is_landmark),
            "popularity_score": float(building.popularity_score)
        }
        
        return schemas.CommonResp(
            success=True,
            data=building_info,
            message="获取建筑信息成功"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取建筑信息失败: {str(e)}")


# ===== AR导航相关接口 =====

@router.post("/navigation/start", response_model=schemas.CommonResp)
def start_ar_navigation(
    start_latitude: float,
    start_longitude: float,
    end_latitude: float,
    end_longitude: float,
    user_id: str = "default_user",
    route_type: str = "walking",
    db: Session = Depends(get_db)
):
    """开始AR导航"""
    try:
        # 创建AR会话
        ar_session = models.UserARSession(
            user_id=user_id,
            session_type="navigation",
            start_latitude=str(start_latitude),
            start_longitude=str(start_longitude),
            current_latitude=str(start_latitude),
            current_longitude=str(start_longitude),
            device_info={"platform": "iOS", "version": "17.0"},
            session_data={"route_type": route_type},
            gmt_create=datetime.utcnow()
        )
        db.add(ar_session)
        db.commit()
        db.refresh(ar_session)
        
        # 计算路线（这里应该调用地图API）
        route_data = {
            "session_id": ar_session.id,
            "start_point": {"latitude": start_latitude, "longitude": start_longitude},
            "end_point": {"latitude": end_latitude, "longitude": end_longitude},
            "route_type": route_type,
            "total_distance": 1000,  # 模拟距离
            "estimated_time": 600,   # 模拟时间
            "waypoints": [
                {"latitude": start_latitude, "longitude": start_longitude},
                {"latitude": (start_latitude + end_latitude) / 2, "longitude": (start_longitude + end_longitude) / 2},
                {"latitude": end_latitude, "longitude": end_longitude}
            ]
        }
        
        return schemas.CommonResp(
            success=True,
            data=route_data,
            message="AR导航已开始"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"开始导航失败: {str(e)}")


@router.get("/navigation/route/{session_id}", response_model=schemas.CommonResp)
def get_navigation_route(session_id: int, db: Session = Depends(get_db)):
    """获取导航路线"""
    try:
        session = db.query(models.UserARSession).filter(
            models.UserARSession.id == session_id
        ).first()
        
        if not session:
            raise HTTPException(status_code=404, detail="会话不存在")
            
        # 这里应该返回详细的导航路线数据
        route_data = {
            "session_id": session_id,
            "current_position": {
                "latitude": float(session.current_latitude),
                "longitude": float(session.current_longitude)
            },
            "heading": float(session.heading_degrees) if session.heading_degrees else 0.0,
            "next_instruction": "直行200米后右转",
            "distance_to_destination": 800,
            "estimated_time": 480
        }
        
        return schemas.CommonResp(
            success=True,
            data=route_data,
            message="获取导航路线成功"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取导航路线失败: {str(e)}")


@router.post("/navigation/update", response_model=schemas.CommonResp)
def update_navigation_status(
    session_id: int,
    current_latitude: float,
    current_longitude: float,
    heading: float = 0.0,
    pitch: float = 0.0,
    roll: float = 0.0,
    db: Session = Depends(get_db)
):
    """更新导航状态"""
    try:
        session = db.query(models.UserARSession).filter(
            models.UserARSession.id == session_id
        ).first()
        
        if not session:
            raise HTTPException(status_code=404, detail="会话不存在")
            
        # 更新位置信息
        session.current_latitude = str(current_latitude)
        session.current_longitude = str(current_longitude)
        session.heading_degrees = str(heading)
        session.pitch_degrees = str(pitch)
        session.roll_degrees = str(roll)
        session.gmt_modified = datetime.utcnow()
        
        db.commit()
        
        # 计算导航指令
        navigation_instruction = {
            "session_id": session_id,
            "current_position": {
                "latitude": current_latitude,
                "longitude": current_longitude
            },
            "heading": heading,
            "next_instruction": "继续直行",
            "distance_to_next": 150,
            "arrow_direction": "forward"
        }
        
        return schemas.CommonResp(
            success=True,
            data=navigation_instruction,
            message="导航状态更新成功"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"更新导航状态失败: {str(e)}")


@router.post("/navigation/end", response_model=schemas.CommonResp)
def end_ar_navigation(
    session_id: int,
    user_rating: int = None,
    user_feedback: str = None,
    db: Session = Depends(get_db)
):
    """结束AR导航"""
    try:
        session = db.query(models.UserARSession).filter(
            models.UserARSession.id == session_id
        ).first()
        
        if not session:
            raise HTTPException(status_code=404, detail="会话不存在")
            
        # 结束会话
        session.is_active = 0
        session.ended_at = datetime.utcnow()
        session.gmt_modified = datetime.utcnow()
        
        # 保存导航历史
        navigation_history = models.NavigationHistory(
            session_id=session_id,
            user_id=session.user_id,
            end_time=datetime.utcnow(),
            user_rating=user_rating,
            user_feedback=user_feedback,
            completion_status="completed",
            gmt_create=datetime.utcnow()
        )
        db.add(navigation_history)
        db.commit()
        
        return schemas.CommonResp(
            success=True,
            data={"session_id": session_id},
            message="AR导航已结束"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"结束导航失败: {str(e)}")


# ===== 用户偏好设置 =====

@router.get("/preferences/{user_id}", response_model=schemas.CommonResp)
def get_user_preferences(user_id: str, db: Session = Depends(get_db)):
    """获取用户偏好设置"""
    try:
        preferences = db.query(models.UserPreference).filter(
            models.UserPreference.user_id == user_id
        ).first()
        
        if not preferences:
            # 创建默认偏好设置
            preferences = models.UserPreference(
                user_id=user_id,
                preferred_building_types={"library": True, "classroom": True},
                preferred_route_types={"walking": True},
                language_preference="zh-CN",
                ar_settings={"recognition_sensitivity": "medium"},
                gmt_create=datetime.utcnow()
            )
            db.add(preferences)
            db.commit()
            db.refresh(preferences)
            
        preferences_data = {
            "user_id": preferences.user_id,
            "preferred_building_types": preferences.preferred_building_types,
            "preferred_route_types": preferences.preferred_route_types,
            "accessibility_needs": preferences.accessibility_needs,
            "language_preference": preferences.language_preference,
            "ar_settings": preferences.ar_settings,
            "notification_settings": preferences.notification_settings
        }
        
        return schemas.CommonResp(
            success=True,
            data=preferences_data,
            message="获取用户偏好成功"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取用户偏好失败: {str(e)}")


@router.post("/preferences/{user_id}", response_model=schemas.CommonResp)
def update_user_preferences(
    user_id: str,
    preferences: dict,
    db: Session = Depends(get_db)
):
    """更新用户偏好设置"""
    try:
        user_prefs = db.query(models.UserPreference).filter(
            models.UserPreference.user_id == user_id
        ).first()
        
        if not user_prefs:
            user_prefs = models.UserPreference(user_id=user_id)
            db.add(user_prefs)
            
        # 更新偏好设置
        for key, value in preferences.items():
            if hasattr(user_prefs, key):
                setattr(user_prefs, key, value)
                
        user_prefs.gmt_modified = datetime.utcnow()
        db.commit()
        
        return schemas.CommonResp(
            success=True,
            data={"user_id": user_id},
            message="用户偏好更新成功"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"更新用户偏好失败: {str(e)}")
