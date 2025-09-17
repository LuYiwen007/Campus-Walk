from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from .db import get_db, Base, engine
from . import models, schemas


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

