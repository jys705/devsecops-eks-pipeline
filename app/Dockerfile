FROM python:3.14-slim-bookworm

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y setuptools \
 && pip uninstall -y pip

COPY main.py ./

RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
USER 10001

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')" || exit 1

# gunicorn 25.1.0이 control socket을 켜면서 $HOME/.gunicorn/ 을 만들려 한다.
# readOnlyRootFilesystem 아래에서 실패하고 기동 로그에 ERROR를 남긴다.
# HOME을 /tmp로 돌려 쓸 자리를 주는 대신, 이 구성이 쓰지 않는 관리 인터페이스를 끈다.
CMD ["gunicorn", "--no-control-socket", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]