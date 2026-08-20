# 베이스 태그가 결함.
# python:3.12.0-slim-bookworm은 2023년 10월에 나온 패치 태그. Debian 12 기반이라 pip가 정상 동작하면서 OS 패키지에는 그동안 공개된 CVE가 쌓여 있다.
FROM python:3.12.0-slim-bookworm

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py ./

RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
USER 10001

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]