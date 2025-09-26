from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from .db import get_db, Base, engine
from . import models, schemas
import requests
import json


# 初始化数据库表
Base.metadata.create_all(bind=engine)

router = APIRouter()


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
    """根据经纬度与朝向，在前方扇形内命中一个最可能的POI（工程化方案）。
    当前先用高德逆地理/周边检索的简化版模拟返回，便于前端打通。
    """
    # 这里返回一个固定命中，真实实现可接入高德：/place/around
    name = "疑似建筑"
    poi = models.PoiCache(name=name, lat=str(lat), lon=str(lon), address="", source="mock", raw_json={"heading": heading})
    db.add(poi)
    db.commit()
    db.refresh(poi)
    vo = schemas.POIVO(id=poi.id, name=poi.name, lat=poi.lat, lon=poi.lon, address=poi.address)
    return schemas.CommonResp(data=vo)
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

