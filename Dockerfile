
FROM python:3.9-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt


FROM python:3.9-slim
WORKDIR /app

COPY --from=builder /root/.local /root/.local

COPY app.py .
COPY index.html .

ENV PATH=/root/.local/bin:$PATH

EXPOSE 5000

CMD ["python", "app.py"]
