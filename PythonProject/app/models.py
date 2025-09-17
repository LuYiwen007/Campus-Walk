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

