import logging
import sys

import fastapi
import fastapi.middleware.cors
import fastapi.middleware.gzip
import pydantic
import uvicorn

import environment

_logger = logging.getLogger(__name__)


class HealthResponse(pydantic.BaseModel):
    status: str


class CountRequest(pydantic.BaseModel):
    text: str


class CountResponse(pydantic.BaseModel):
    count: int


def create_app(env: environment.Environment) -> fastapi.FastAPI:
    app = fastapi.FastAPI(docs_url=None, openapi_url=None, redoc_url=None)

    app.add_middleware(fastapi.middleware.gzip.GZipMiddleware, minimum_size=512)
    app.add_middleware(
        fastapi.middleware.cors.CORSMiddleware,
        allow_origins=[env.cors_origin],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/health")
    def health() -> HealthResponse:
        return HealthResponse(status="ok")

    @app.post("/count")
    def count(request: CountRequest) -> CountResponse:
        return CountResponse(count=len(request.text))

    return app


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        handlers=[logging.StreamHandler(sys.stderr)],
    )
    env = environment.Environment()
    _logger.info(env)
    app = create_app(env)
    uvicorn.run(app, host="0.0.0.0", port=env.port, server_header=False)
