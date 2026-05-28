.PHONY: help dev up prod logs test lint clean install build push migrate health

help:
	@echo "Music Downloader - Available Commands:"
	@echo "  make dev          - Start development environment"
	@echo "  make prod         - Start production environment"
	@echo "  make up           - Start with docker-compose (alias for dev)"
	@echo "  make down         - Stop all containers"
	@echo "  make logs         - Tail backend logs"
	@echo "  make test         - Run tests"
	@echo "  make lint         - Run linters"
	@echo "  make clean        - Clean up containers and volumes"
	@echo "  make install      - Install dependencies locally"
	@echo "  make backend      - Run backend server (local)"
	@echo "  make worker       - Run worker process (local)"
	@echo "  make frontend     - Run frontend dev server (local)"
	@echo "  make migrate      - Run database migrations"
	@echo "  make health       - Check service health"
	@echo "  make build        - Build production images"
	@echo "  make push         - Push to registry"

dev:
	docker-compose up --build

prod:
	docker-compose -f docker-compose.prod.yml up -d

up: dev

down:
	docker-compose down
	docker-compose -f docker-compose.prod.yml down

logs:
	docker-compose logs -f backend

backend:
	python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

worker:
	python -m backend.worker

frontend:
	cd frontend && npm run dev

install:
	python -m pip install -r backend/requirements.txt
	cd frontend && npm install

test:
	pytest backend/tests -v

lint:
	python -m black backend --check
	python -m flake8 backend
	cd frontend && npm run lint

clean:
	docker-compose down -v
	docker-compose -f docker-compose.prod.yml down -v
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name '*.pyc' -delete
	rm -rf backend/downloads/*
	rm -rf backend/logs/*

migrate:
	python -m backend.models

health:
	@echo "Checking service health..."
	@curl -s http://localhost:8000/api/health && echo "✓ Backend OK" || echo "✗ Backend DOWN"
	@curl -s http://localhost:3000/health && echo "✓ Frontend OK" || echo "✗ Frontend DOWN"
	@curl -s http://localhost:6379/ping > /dev/null 2>&1 && echo "✓ Redis OK" || echo "✗ Redis DOWN"

build:
	docker build -t music-downloader:backend -f Dockerfile.backend .
	docker build -t music-downloader:frontend -f Dockerfile.frontend ./frontend

push: build
	docker tag music-downloader:backend ${REGISTRY}/music-downloader:backend
	docker tag music-downloader:frontend ${REGISTRY}/music-downloader:frontend
	docker push ${REGISTRY}/music-downloader:backend
	docker push ${REGISTRY}/music-downloader:frontend

