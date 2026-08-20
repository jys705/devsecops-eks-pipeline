# 호스트 이름을 받아 해석해주는 엔드포인트 하나짜리 테스트용 Flask 앱
# 의도적 결함(shell=True)을 유도한다.

import subprocess

from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


@app.get("/resolve")
def resolve():
    host = request.args.get("host", "localhost")
    output = subprocess.check_output(["getent", "hosts", host], text=True)
    return jsonify(host=host, result=output.strip())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)