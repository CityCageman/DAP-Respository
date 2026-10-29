"""Mock OpenAI-compatible chat server for E2E testing AiChatClient."""
import json
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        user = next(m['content'] for m in body['messages'] if m['role'] == 'user')

        if '表清单' in user:  # AI 血缘推断请求
            content = json.dumps({"edges": [{
                "source": "hospital_demo.biz_patient_master",
                "target": "hospital_demo.biz_encounter",
                "columnMapping": "patient_uuid -> patient_uuid; empi -> encounter_no",
                "reason": "mock: 患者主表驱动就诊表",
                "confidence": 0.9
            }]}, ensure_ascii=False)
        else:  # AI 注释补全请求：把 prompt 里出现的 tableId/columnId 原样回显
            tables = [{"tableId": int(i), "comment": "mock表描述-" + i} for i in re.findall(r"tableId=(\d+)", user)]
            columns = [{"columnId": int(i), "comment": "mock字段注释-" + i} for i in re.findall(r"columnId=(\d+)", user)]
            content = json.dumps({"tables": tables, "columns": columns}, ensure_ascii=False)

        resp = {"choices": [{"message": {"role": "assistant", "content": f"```json\n{content}\n```"}}]}
        data = json.dumps(resp).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

HTTPServer(('127.0.0.1', 18099), Handler).serve_forever()
