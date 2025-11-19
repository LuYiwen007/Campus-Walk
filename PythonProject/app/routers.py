from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import and_
from .db import get_db, Base, engine
from . import models, schemas
from .ar_routers import router as ar_router
from .utils import haversine_distance, filter_pois_in_fov, sort_pois_by_distance, generate_cache_key
import requests
import json
import math
from datetime import datetime, timedelta


# 初始化数据库表
Base.metadata.create_all(bind=engine)

router = APIRouter()

# 包含AR路由
router.include_router(ar_router)


@router.post("/conversations/add.json", response_model=schemas.CommonResp)
def create_conversation(payload: schemas.ConversationCreate, db: Session = Depends(get_db)):
    conv = models.Conversation(title=payload.title, llm_model=payload.llmModel)
    db.add(conv)
    db.commit()
    db.refresh(conv)
    vo = schemas.ConversationVO(
        id=conv.id, title=conv.title, llmModel=conv.llm_model, gmtCreate=conv.gmt_create, gmtModified=conv.gmt_modified
    )
    return schemas.CommonResp(data=vo)


# ===== AR 会话接口 =====
@router.post("/ar/session/start", response_model=schemas.CommonResp)
def ar_session_start(payload: schemas.ARSessionStartReq, db: Session = Depends(get_db)):
    session = models.ARSession(
        user_id=payload.userId,
        mode=payload.mode,
        conversation_id=payload.conversationId,
        used_geo_anchor=1 if payload.usedGeoAnchor else 0,
        device=payload.device,
        os=payload.os,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    vo = schemas.ARSessionVO(
        id=session.id,
        userId=session.user_id,
        mode=session.mode,
        conversationId=session.conversation_id,
        usedGeoAnchor=bool(session.used_geo_anchor),
        device=session.device,
        os=session.os,
        startTime=session.start_time,
        endTime=session.end_time,
    )
    return schemas.CommonResp(data=vo)


@router.post("/ar/session/end", response_model=schemas.CommonResp)
def ar_session_end(payload: schemas.ARSessionEndReq, db: Session = Depends(get_db)):
    session = db.get(models.ARSession, payload.sessionId)
    if not session:
        raise HTTPException(status_code=404, detail="session not found")
    session.end_time = datetime.utcnow()
    db.commit()
    vo = schemas.ARSessionVO(
        id=session.id,
        userId=session.user_id,
        mode=session.mode,
        conversationId=session.conversation_id,
        usedGeoAnchor=bool(session.used_geo_anchor),
        device=session.device,
        os=session.os,
        startTime=session.start_time,
        endTime=session.end_time,
    )
    return schemas.CommonResp(data=vo)


# ===== 基于朝向的周边POI命中 =====
@router.get("/poi/nearby", response_model=schemas.CommonResp)
def get_nearby_poi(lat: float, lon: float, heading: float = 0.0, radius: int = 150, fov: float = 60.0, db: Session = Depends(get_db)):
    """
    根据经纬度与朝向，在前方扇形内命中一个最可能的POI（工程化方案）。
    
    参数验证由Pydantic自动完成（通过schemas.NearbyPOIQuery）
    
    实现逻辑：
    1. 参数验证（已通过Pydantic完成）
    2. 检查缓存表（如果缓存命中，直接返回）
    3. 查询数据库POI表（空间查询，基于经纬度范围）
    4. 筛选在视野范围内的POI
    5. 按距离排序
    6. 返回最相关的POI（前1-3个）
    7. 写入缓存（如果缓存未命中）
    """
    try:
        # 生成缓存键
        cache_key = generate_cache_key(lat, lon, radius, heading, fov)
        
        # 检查缓存表（步骤2.7：添加缓存机制）
        cache = db.query(models.POICache).filter(
            models.POICache.cache_key == cache_key
        ).first()
        
        # 如果缓存存在且未过期，直接返回（步骤2.8：缓存命中直接返回）
        if cache and datetime.utcnow() < cache.expires_at:
            # 增加命中次数
            cache.hit_count += 1
            db.commit()
            
            # 从缓存中获取POI数据
            cached_pois = cache.cache_data if isinstance(cache.cache_data, list) else []
            
            if cached_pois:
                # 转换为返回格式
                if len(cached_pois) == 1:
                    poi_data = cached_pois[0]
                    vo = schemas.POIVO(
                        id=poi_data.get('id'),
                        poi_id=poi_data.get('poi_id', ''),
                        name=poi_data.get('name', ''),
                        latitude=poi_data.get('latitude', 0.0),
                        longitude=poi_data.get('longitude', 0.0),
                        address=poi_data.get('address', ''),
                        description=poi_data.get('description', ''),
                        poi_type=poi_data.get('poi_type', ''),
                        distance=poi_data.get('distance', 0.0),
                        phone=poi_data.get('phone', ''),
                        website=poi_data.get('website', ''),
                        business_area=poi_data.get('business_area', ''),
                        province=poi_data.get('province', ''),
                        city=poi_data.get('city', ''),
                        district=poi_data.get('district', ''),
                        rating=poi_data.get('rating'),
                        images=poi_data.get('images', [])
                    )
                    return schemas.CommonResp(
                        success=True,
                        data=vo,
                        message="找到POI（缓存）"
                    )
                else:
                    # 返回POI列表
                    poi_list = []
                    for poi_data in cached_pois:
                        vo = schemas.POIVO(
                            id=poi_data.get('id'),
                            poi_id=poi_data.get('poi_id', ''),
                            name=poi_data.get('name', ''),
                            latitude=poi_data.get('latitude', 0.0),
                            longitude=poi_data.get('longitude', 0.0),
                            address=poi_data.get('address', ''),
                            description=poi_data.get('description', ''),
                            poi_type=poi_data.get('poi_type', ''),
                            distance=poi_data.get('distance', 0.0),
                            phone=poi_data.get('phone', ''),
                            website=poi_data.get('website', ''),
                            business_area=poi_data.get('business_area', ''),
                            province=poi_data.get('province', ''),
                            city=poi_data.get('city', ''),
                            district=poi_data.get('district', ''),
                            rating=poi_data.get('rating'),
                            images=poi_data.get('images', [])
                        )
                        poi_list.append(vo)
                    
                    return schemas.CommonResp(
                        success=True,
                        data=poi_list,
                        message=f"找到{len(poi_list)}个POI（缓存）"
                    )
        
        # 缓存未命中，继续查询数据库（步骤2.9：缓存未命中查询并写入缓存）
        # 计算经纬度范围（粗略估算，用于数据库查询优化）
        # 1度纬度约等于111公里，1度经度在不同纬度下不同，这里使用粗略估算
        lat_delta = radius / 111000.0  # 转换为度数
        lon_delta = radius / (111000.0 * abs(math.cos(math.radians(lat))))  # 考虑纬度影响
        
        # 构建空间查询条件（查询半径范围内的POI）
        min_lat = lat - lat_delta
        max_lat = lat + lat_delta
        min_lon = lon - lon_delta
        max_lon = lon + lon_delta
        
        # 查询数据库POI表（空间查询）
        pois_query = db.query(models.POI).filter(
            and_(
                models.POI.latitude >= min_lat,
                models.POI.latitude <= max_lat,
                models.POI.longitude >= min_lon,
                models.POI.longitude <= max_lon
            )
        )
        
        # 转换为字典列表，便于后续处理
        pois_list = []
        for poi in pois_query.all():
            poi_dict = {
                'id': poi.id,
                'poi_id': poi.poi_id,
                'name': poi.name,
                'latitude': float(poi.latitude),
                'longitude': float(poi.longitude),
                'address': poi.address or '',
                'description': poi.description or '',
                'poi_type': poi.poi_type or '',
                'type_code': poi.type_code or '',
                'phone': poi.phone or '',
                'website': poi.website or '',
                'business_area': poi.business_area or '',
                'province': poi.province or '',
                'city': poi.city or '',
                'district': poi.district or '',
                'rating': float(poi.rating) if poi.rating else None,
                'images': poi.images if poi.images else []
            }
            pois_list.append(poi_dict)
        
        # 筛选在视野范围内的POI（使用工具函数）
        filtered_pois = filter_pois_in_fov(
            center_lat=lat,
            center_lon=lon,
            center_heading=heading,
            fov=fov,
            radius=radius,
            pois=pois_list
        )
        
        # 按距离排序
        sorted_pois = sort_pois_by_distance(filtered_pois)
        
        # 返回最相关的POI（前1-3个）
        if not sorted_pois:
            return schemas.CommonResp(
                success=False,
                data=None,
                message="未找到视野范围内的POI"
            )
        
        # 取前3个POI
        top_pois = sorted_pois[:3]
        
        # 转换为返回格式
        if len(top_pois) == 1:
            # 返回单个POI对象
            poi_data = top_pois[0]
            vo = schemas.POIVO(
                id=poi_data.get('id'),
                poi_id=poi_data.get('poi_id', ''),
                name=poi_data.get('name', ''),
                latitude=poi_data.get('latitude', 0.0),
                longitude=poi_data.get('longitude', 0.0),
                address=poi_data.get('address', ''),
                description=poi_data.get('description', ''),
                poi_type=poi_data.get('poi_type', ''),
                distance=poi_data.get('distance', 0.0),
                phone=poi_data.get('phone', ''),
                website=poi_data.get('website', ''),
                business_area=poi_data.get('business_area', ''),
                province=poi_data.get('province', ''),
                city=poi_data.get('city', ''),
                district=poi_data.get('district', ''),
                rating=poi_data.get('rating'),
                images=poi_data.get('images', [])
            )
            return schemas.CommonResp(
                success=True,
                data=vo,
                message="找到POI"
            )
        else:
            # 返回POI列表
            poi_list = []
            for poi_data in top_pois:
                vo = schemas.POIVO(
                    id=poi_data.get('id'),
                    poi_id=poi_data.get('poi_id', ''),
                    name=poi_data.get('name', ''),
                    latitude=poi_data.get('latitude', 0.0),
                    longitude=poi_data.get('longitude', 0.0),
                    address=poi_data.get('address', ''),
                    description=poi_data.get('description', ''),
                    poi_type=poi_data.get('poi_type', ''),
                    distance=poi_data.get('distance', 0.0),
                    phone=poi_data.get('phone', ''),
                    website=poi_data.get('website', ''),
                    business_area=poi_data.get('business_area', ''),
                    province=poi_data.get('province', ''),
                    city=poi_data.get('city', ''),
                    district=poi_data.get('district', ''),
                    rating=poi_data.get('rating'),
                    images=poi_data.get('images', [])
                )
                poi_list.append(vo)
            
            return schemas.CommonResp(
                success=True,
                data=poi_list,
                message=f"找到{len(poi_list)}个POI"
            )
        
        # 写入缓存（步骤2.9：缓存未命中查询并写入缓存）
        # 准备缓存数据（转换为字典列表）
        cache_data_list = []
        for poi_data in top_pois:
            cache_data_list.append({
                'id': poi_data.get('id'),
                'poi_id': poi_data.get('poi_id', ''),
                'name': poi_data.get('name', ''),
                'latitude': poi_data.get('latitude', 0.0),
                'longitude': poi_data.get('longitude', 0.0),
                'address': poi_data.get('address', ''),
                'description': poi_data.get('description', ''),
                'poi_type': poi_data.get('poi_type', ''),
                'distance': poi_data.get('distance', 0.0),
                'phone': poi_data.get('phone', ''),
                'website': poi_data.get('website', ''),
                'business_area': poi_data.get('business_area', ''),
                'province': poi_data.get('province', ''),
                'city': poi_data.get('city', ''),
                'district': poi_data.get('district', ''),
                'rating': poi_data.get('rating'),
                'images': poi_data.get('images', [])
            })
        
        # 创建或更新缓存
        expires_at = datetime.utcnow().replace(microsecond=0) + timedelta(minutes=30)  # 30分钟后过期
        
        if cache:
            # 更新现有缓存
            cache.cache_data = cache_data_list
            cache.expires_at = expires_at
            cache.hit_count = 0  # 重置命中次数
        else:
            # 创建新缓存
            new_cache = models.POICache(
                latitude=lat,
                longitude=lon,
                radius=radius,
                heading=heading if heading else None,
                fov=fov if fov else None,
                cache_key=cache_key,
                cache_data=cache_data_list,
                hit_count=0,
                expires_at=expires_at
            )
            db.add(new_cache)
        
        db.commit()
            
    except ValueError as e:
        # 参数错误
        raise HTTPException(status_code=400, detail=f"参数错误: {str(e)}")
    except Exception as e:
        # 数据库查询失败或其他错误
        import traceback
        error_detail = f"查询POI失败: {str(e)}"
        print(f"❌ [POI查询错误] {error_detail}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=error_detail)


# ===== AR识别记录保存接口 =====
@router.post("/ar-recognition/save", response_model=schemas.CommonResp)
def save_ar_recognition(
    payload: schemas.ARRecognitionSaveRequest,
    db: Session = Depends(get_db)
):
    """
    保存AR识别记录
    
    实现逻辑：
    1. 验证参数（已通过Pydantic完成）
    2. 检查POI是否存在（如果提供了detected_poi_id）
    3. 保存到ARRecognitionRecord表
    4. 返回保存结果
    """
    try:
        # 如果提供了detected_poi_id，检查POI是否存在
        if payload.detected_poi_id is not None:
            poi = db.query(models.POI).filter(models.POI.id == payload.detected_poi_id).first()
            if not poi:
                raise HTTPException(
                    status_code=404,
                    detail=f"POI不存在：detected_poi_id={payload.detected_poi_id}"
                )
        
        # 创建AR识别记录
        recognition_record = models.ARRecognitionRecord(
            user_id=payload.user_id,
            session_id=payload.session_id,
            latitude=payload.latitude,
            longitude=payload.longitude,
            heading=float(payload.heading) if payload.heading is not None else None,
            fov=float(payload.fov) if payload.fov is not None else None,
            radius=float(payload.radius) if payload.radius is not None else None,
            detected_poi_id=payload.detected_poi_id,
            confidence=float(payload.confidence) if payload.confidence is not None else None,
            recognition_mode=payload.recognition_mode,
            device_info=payload.device_info,
            app_version=payload.app_version
        )
        
        # 保存到数据库
        db.add(recognition_record)
    db.commit()
        db.refresh(recognition_record)
        
        # 转换为返回格式
        vo = schemas.ARRecognitionRecordVO(
            id=recognition_record.id,
            user_id=recognition_record.user_id,
            session_id=recognition_record.session_id,
            latitude=float(recognition_record.latitude),
            longitude=float(recognition_record.longitude),
            heading=float(recognition_record.heading) if recognition_record.heading else None,
            fov=float(recognition_record.fov) if recognition_record.fov else None,
            radius=float(recognition_record.radius) if recognition_record.radius else None,
            detected_poi_id=recognition_record.detected_poi_id,
            confidence=float(recognition_record.confidence) if recognition_record.confidence else None,
            recognition_mode=recognition_record.recognition_mode,
            device_info=recognition_record.device_info,
            app_version=recognition_record.app_version,
            created_at=recognition_record.created_at,
            detected_poi=None  # 如果需要POI详情，可以在这里加载
        )
        
        # 如果需要返回POI详情
        if recognition_record.detected_poi_id and recognition_record.detected_poi:
            poi = recognition_record.detected_poi
            vo.detected_poi = schemas.POIVO(
                id=poi.id,
                poi_id=poi.poi_id,
                name=poi.name,
                latitude=float(poi.latitude),
                longitude=float(poi.longitude),
                address=poi.address or '',
                description=poi.description or '',
                poi_type=poi.poi_type or '',
                distance=0.0,
                phone=poi.phone or '',
                website=poi.website or '',
                business_area=poi.business_area or '',
                province=poi.province or '',
                city=poi.city or '',
                district=poi.district or '',
                rating=float(poi.rating) if poi.rating else None,
                images=poi.images if poi.images else []
            )
        
        return schemas.CommonResp(
            success=True,
            data=vo,
            message="AR识别记录保存成功"
        )
        
    except HTTPException:
        raise
    except ValueError as e:
        # 参数验证失败
        raise HTTPException(status_code=400, detail=f"参数验证失败: {str(e)}")
    except Exception as e:
        # 数据库保存失败
        import traceback
        error_detail = f"保存AR识别记录失败: {str(e)}"
        print(f"❌ [AR识别保存错误] {error_detail}")
        print(traceback.format_exc())
        db.rollback()
        raise HTTPException(status_code=500, detail=error_detail)


# ===== AR识别历史查询接口 =====
@router.get("/ar-recognition/history", response_model=schemas.CommonResp)
def get_ar_recognition_history(
    session_id: str = None,
    user_id: str = None,
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    """
    查询AR识别历史记录
    
    实现逻辑：
    1. 根据session_id和user_id筛选（可选）
    2. 查询识别历史记录，并关联POI信息
    3. 分页返回结果
    """
    try:
        # 构建查询
        query = db.query(models.ARRecognitionRecord)
        
        # 添加筛选条件
        if session_id:
            query = query.filter(models.ARRecognitionRecord.session_id == session_id)
        if user_id:
            query = query.filter(models.ARRecognitionRecord.user_id == user_id)
        
        # 按创建时间倒序排列
        query = query.order_by(models.ARRecognitionRecord.created_at.desc())
        
        # 获取总数
        total_count = query.count()
        
        # 分页查询
        records = query.offset(offset).limit(limit).all()
        
        # 转换为返回格式
        record_list = []
        for record in records:
            # 构建基础VO
            vo = schemas.ARRecognitionRecordVO(
                id=record.id,
                user_id=record.user_id,
                session_id=record.session_id,
                latitude=float(record.latitude),
                longitude=float(record.longitude),
                heading=float(record.heading) if record.heading else None,
                fov=float(record.fov) if record.fov else None,
                radius=float(record.radius) if record.radius else None,
                detected_poi_id=record.detected_poi_id,
                confidence=float(record.confidence) if record.confidence else None,
                recognition_mode=record.recognition_mode,
                device_info=record.device_info,
                app_version=record.app_version,
                created_at=record.created_at,
                detected_poi=None
            )
            
            # 如果有关联的POI，加载POI信息
            if record.detected_poi_id and record.detected_poi:
                poi = record.detected_poi
                vo.detected_poi = schemas.POIVO(
                    id=poi.id,
                    poi_id=poi.poi_id,
                    name=poi.name,
                    latitude=float(poi.latitude),
                    longitude=float(poi.longitude),
                    address=poi.address or '',
                    description=poi.description or '',
                    poi_type=poi.poi_type or '',
                    distance=0.0,
                    phone=poi.phone or '',
                    website=poi.website or '',
                    business_area=poi.business_area or '',
                    province=poi.province or '',
                    city=poi.city or '',
                    district=poi.district or '',
                    rating=float(poi.rating) if poi.rating else None,
                    images=poi.images if poi.images else []
                )
            
            record_list.append(vo)
        
        return schemas.CommonResp(
            success=True,
            data={
                "records": record_list,
                "total": total_count,
                "limit": limit,
                "offset": offset
            },
            message=f"查询成功，共找到{total_count}条记录"
        )
        
    except Exception as e:
        import traceback
        error_detail = f"查询AR识别历史失败: {str(e)}"
        print(f"❌ [AR识别历史查询错误] {error_detail}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=error_detail)


@router.post("/conversations/addChat.json", response_model=schemas.CommonResp)
def add_chat(payload: schemas.ChatCreate, db: Session = Depends(get_db)):
    # 校验会话存在
    conv = db.get(models.Conversation, payload.conversationId)
    if not conv:
        raise HTTPException(status_code=404, detail="conversation not found")
    chat = models.ChatMessage(
        conversation_id=payload.conversationId,
        role=payload.role,
        type=payload.type,
        content=payload.content,
    )
    db.add(chat)
    db.commit()
    db.refresh(chat)
    vo = schemas.ChatVO(
        id=chat.id,
        conversationId=chat.conversation_id,
        role=chat.role,
        type=chat.type,
        content=chat.content,
        gmtCreate=chat.gmt_create,
        gmtModified=chat.gmt_modified,
    )
    return schemas.CommonResp(values=[vo])


@router.get("/conversations/list.json", response_model=schemas.CommonResp)
def list_conversations(db: Session = Depends(get_db)):
    items = db.query(models.Conversation).order_by(models.Conversation.id.desc()).all()
    values = [
        schemas.ConversationVO(
            id=i.id, title=i.title, llmModel=i.llm_model, gmtCreate=i.gmt_create, gmtModified=i.gmt_modified
        )
        for i in items
    ]
    return schemas.CommonResp(values=values)


@router.get("/conversations/chatList.json", response_model=schemas.CommonResp)
def list_chats(conversationId: int, db: Session = Depends(get_db)):
    chats = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.conversation_id == conversationId)
        .order_by(models.ChatMessage.id.asc())
        .all()
    )
    values = [
        schemas.ChatVO(
            id=c.id,
            conversationId=c.conversation_id,
            role=c.role,
            type=c.type,
            content=c.content,
            gmtCreate=c.gmt_create,
            gmtModified=c.gmt_modified,
        )
        for c in chats
    ]
    return schemas.CommonResp(values=values)


@router.post("/route-locations/save.json", response_model=schemas.CommonResp)
def save_route_locations(payload: schemas.RouteLocationsCreate, db: Session = Depends(get_db)):
    """保存AI返回的地点信息"""
    # 校验会话存在
    conv = db.get(models.Conversation, payload.conversationId)
    if not conv:
        raise HTTPException(status_code=404, detail="conversation not found")
    
    route_location = models.RouteLocations(
        conversation_id=payload.conversationId,
        locations=payload.locations,
        route_type=payload.routeType
    )
    db.add(route_location)
    db.commit()
    db.refresh(route_location)
    
    vo = schemas.RouteLocationsVO(
        id=route_location.id,
        conversationId=route_location.conversation_id,
        locations=route_location.locations,
        routeType=route_location.route_type,
        gmtCreate=route_location.gmt_create,
        gmtModified=route_location.gmt_modified,
    )
    return schemas.CommonResp(data=vo)


@router.get("/route-locations/get.json", response_model=schemas.CommonResp)
def get_route_locations(conversationId: int, db: Session = Depends(get_db)):
    """获取指定会话的地点信息"""
    route_location = (
        db.query(models.RouteLocations)
        .filter(models.RouteLocations.conversation_id == conversationId)
        .order_by(models.RouteLocations.id.desc())
        .first()
    )
    
    if not route_location:
        raise HTTPException(status_code=404, detail="route locations not found")
    
    vo = schemas.RouteLocationsVO(
        id=route_location.id,
        conversationId=route_location.conversation_id,
        locations=route_location.locations,
        routeType=route_location.route_type,
        gmtCreate=route_location.gmt_create,
        gmtModified=route_location.gmt_modified,
    )
    return schemas.CommonResp(data=vo)


@router.post("/route-segments/get.json", response_model=schemas.CommonResp)
def get_route_segment(payload: schemas.RouteSegmentRequest, db: Session = Depends(get_db)):
    """获取指定路段的路线数据"""
    # 获取地点信息
    route_location = (
        db.query(models.RouteLocations)
        .filter(models.RouteLocations.conversation_id == payload.conversationId)
        .order_by(models.RouteLocations.id.desc())
        .first()
    )
    
    if not route_location:
        raise HTTPException(status_code=404, detail="route locations not found")
    
    # 解析地点列表
    locations = route_location.locations.split("--")
    if payload.segmentIndex >= len(locations) - 1:
        raise HTTPException(status_code=400, detail="segment index out of range")
    
    from_location = locations[payload.segmentIndex]
    to_location = locations[payload.segmentIndex + 1]
    
    # 调用高德地图API获取路线
    try:
        route_data = call_amap_route_api(from_location, to_location, route_location.route_type)
        
        response = schemas.RouteSegmentResponse(
            segmentIndex=payload.segmentIndex,
            fromLocation=from_location,
            toLocation=to_location,
            routeData=route_data,
            isLastSegment=(payload.segmentIndex == len(locations) - 2)
        )
        return schemas.CommonResp(data=response)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get route data: {str(e)}")


def call_amap_route_api(from_location: str, to_location: str, route_type: str = "walking"):
    """调用高德地图API获取路线数据"""
    # 临时返回模拟数据，等网络问题解决后再启用真实API调用
    return {
        "status": "1",
        "info": "OK",
        "route": {
            "paths": [{
                "distance": "1000",
                "duration": "600",
                "steps": [{
                    "instruction": f"从{from_location}到{to_location}",
                    "polyline": "113.264,23.132;113.265,23.133"
                }]
            }]
        }
    }
    
    # 真实API调用代码（等网络问题解决后启用）
    # amap_key = "your_amap_api_key"  # 请替换为你的高德地图API Key
    # if route_type == "walking":
    #     url = "https://restapi.amap.com/v3/direction/walking"
    # elif route_type == "driving":
    #     url = "https://restapi.amap.com/v3/direction/driving"
    # else:
    #     url = "https://restapi.amap.com/v3/direction/walking"
    # 
    # params = {
    #     "key": amap_key,
    #     "origin": from_location,
    #     "destination": to_location,
    #     "output": "json"
    # }
    # 
    # response = requests.get(url, params=params)
    # response.raise_for_status()
    # 
    # return response.json()

