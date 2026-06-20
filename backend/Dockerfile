FROM python:3.13-slim-bookworm

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

ENV PORT=8080
ENV CORS_ORIGIN=http://localhost:5173

COPY pyproject.toml .
RUN uv pip install --system --compile-bytecode .

COPY src/ src/

ENTRYPOINT ["python", "src/main.py"]
