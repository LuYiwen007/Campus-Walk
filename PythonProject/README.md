# AI Chat Backend (FastAPI + MySQL)

## Setup
1. Python 3.10+
2. Install dependencies:
```bash
pip install -r requirements.txt
```
3. Create `.env` (in project root) based on:
```
DATABASE_URL=mysql+mysqldb://root:password@127.0.0.1:3306/ai_chat?charset=utf8mb4
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000,http://localhost:8081,http://127.0.0.1:8081
```
4. Create database in MySQL:
```sql
CREATE DATABASE ai_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```
5. Run server:
```bash
uvicorn main:app --reload
```

## API
- POST `/conversations/add.json` body: `{ "title": "xxx", "llmModel": "defaultModel" }` -> data: ConversationVO
- POST `/conversations/addChat.json` body: `{ "content": "hi", "conversationId": 1, "type": "TEXT", "role": "user" }` -> values: [ChatVO]
- GET  `/conversations/list.json` -> values: [ConversationVO]
- GET  `/conversations/chatList.json?conversationId=1` -> values: [ChatVO]

Response envelope:
```json
{ "success": true, "resultCode": "SUCCESS", "data": null, "values": [] }
```

